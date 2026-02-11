# Implementation Review: Script Changes (Phases 1-7)

## Summary

The implementation correctly addresses all 6 requirements: title-based filenames, frontmatter title field, 25-char random IDs, JSON create output, query always includes full_path, and query includes title. The architecture is sound, DRY is respected (shared `_file_to_jsonl()`), and all 7 awk title readers + 11 basename calls have been mechanically updated. Two correctness bugs need fixing before proceeding.

## BLOCKING Issues

### 1. `json_escape()` backslash escaping is broken (produces invalid JSON)

**File:** `/home/nickolaykondratyev/git_repos/note-ticket/ticket`, line 213
**Code:**
```awk
function json_escape(s) {
    gsub(/\\/, "\\\\", s)
    gsub(/"/, "\\\"", s)
    return s
}
```

**Problem:** In awk, `gsub(/\\/, "\\\\", s)` replaces a backslash with... a backslash. The replacement string `"\\\\"` is interpreted as escaped-backslash + escaped-backslash = two characters `\\`, which awk then interprets as a single literal backslash. The operation is effectively a no-op.

**Reproduction:**
```bash
echo 'a\b' | awk '{gsub(/\\/, "\\\\"); print}' | od -c
# Output: a \ b  (single backslash -- no change)
```

**Impact:** Any ticket with a backslash in a frontmatter field (title, description, assignee, etc.) produces invalid JSON. Verified: `create 'Title with \ backslash'` outputs `"title":"Title with \ backslash"` which is invalid JSON.

**Fix:** Use 8 backslashes in the source to produce a literal `\\` in the output:
```awk
function json_escape(s) {
    gsub(/\\/, "\\\\\\\\", s)
    gsub(/"/, "\\\"", s)
    return s
}
```

Or alternatively, avoid the awk string-escaping nightmare by using a character-by-character approach.

### 2. Double quotes in title create malformed YAML frontmatter

**File:** `/home/nickolaykondratyev/git_repos/note-ticket/ticket`, line 292
**Code:**
```bash
echo "title: \"$title\""
```

**Problem:** If the title contains double quotes (e.g., `She said "hello"`), the frontmatter becomes:
```yaml
title: "She said "hello""
```
This is malformed YAML. While the awk-based readers happen to tolerate this (they use `substr($0, 8)` and strip outer quotes), any standard YAML parser will choke on it. More importantly, this creates a data integrity issue -- the file on disk is not valid YAML.

**Impact:** Medium-high. While the current tooling works around it, interoperability with any other YAML-aware tool is broken.

**Fix:** Escape inner double quotes before writing:
```bash
local escaped_title="${title//\"/\\\"}"
echo "title: \"$escaped_title\""
```

This produces `title: "She said \"hello\""` which is valid YAML.

## IMPORTANT Issues

### 3. No filename length truncation -- filesystem error on long titles

**File:** `/home/nickolaykondratyev/git_repos/note-ticket/ticket`, `title_to_filename()` function, line 89

**Problem:** A title with 300+ characters produces a filename that exceeds the typical 255-byte filesystem limit (ext4, APFS, etc.), causing a hard error:
```
/ticket: line 249: .tickets/aaaa...aaa.md: File name too long
```

**Fix:** Truncate the slug to a safe maximum length (e.g., 200 characters) before collision checking:
```bash
# Truncate to reasonable filename length (leave room for -N.md suffix)
[[ ${#slug} -gt 200 ]] && slug="${slug:0:200}"
# Remove trailing hyphen after truncation
slug="${slug%-}"
```

## MINOR Issues

### 4. `cmd_migrate_beads()` still writes old-format files

**File:** `/home/nickolaykondratyev/git_repos/note-ticket/ticket`, lines 1457-1479

The migration command still writes `id: {beads_id}` as filename, title as `# heading` in body, and no `title:` in frontmatter. The implementor correctly marked this as out of scope per plan reviewer guidance. However, users running `tk migrate-beads` after this change will get files incompatible with the new format.

**Recommendation:** Add a warning comment in the code and/or a note in CHANGELOG that `migrate-beads` needs a future update. Not blocking.

### 5. Help text dropped `[default: git user.name]` for assignee

**File:** `/home/nickolaykondratyev/git_repos/note-ticket/ticket`, line 1539

The original also didn't show this default, so not a regression. But since we're touching the help text anyway, it would be nice to restore it. Very minor.

## POSITIVE

1. **`_file_to_jsonl()` shared correctly between create and query** -- This is the right DRY approach. Both code paths produce identical JSON structure.

2. **`ticket_path()` single awk pass is clean** -- The exact-match-first, partial-match-second logic with proper error handling for ambiguous/missing IDs is correct and efficient.

3. **`title_to_filename()` collision handling is sound** -- The `-1`, `-2` suffix approach with a while loop is simple and correct.

4. **`generate_id()` SIGPIPE fix** -- The `|| true` after the `tr | head` pipe correctly handles exit code 141 under `set -euo pipefail`.

5. **All 7 awk title readers and 11 basename calls updated consistently** -- Verified all occurrences match.

6. **Implementor's awk backreference fix** -- Correctly identified that `gsub(/^"(.*)"$/, "\\1", title)` doesn't work in awk and replaced with `if (title ~ /^".*"$/) title = substr(title, 2, length(title) - 2)`.

7. **CHANGELOG properly updated** under `[Unreleased]` with all changes documented.

## Verdict

**IMPLEMENTATION_ITERATION: REQUIRED** -- The two BLOCKING issues (json_escape backslash bug, double-quote YAML escaping) must be fixed. The filename length truncation (IMPORTANT) should also be fixed. All three are small, localized fixes.

After these fixes, proceed to Phases 8-9 (test infrastructure).
