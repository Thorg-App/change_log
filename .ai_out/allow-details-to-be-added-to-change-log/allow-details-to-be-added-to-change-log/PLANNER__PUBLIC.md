# Implementation Plan: Strip Partial ID Matching + Add `--details_in_md` Flag

## 1. Problem Understanding

**Goal**: Two changes to the `change_log` bash script:
1. **Simplify ID resolution** -- Remove partial (substring) ID matching from `entry_path()`. Only exact matches should work. This removes complexity that is unnecessary for a tool where IDs are programmatically passed (by AI agents, not typed by humans).
2. **Add `--details_in_md TEXT` flag** -- Allow `cmd_create()` to accept a markdown body that goes AFTER the frontmatter `---` closing delimiter. This content is for human/agent reading via `show`, NOT for programmatic querying.

**Key Constraints**:
- `_file_to_jsonl()` already only parses frontmatter (between `---` markers), so details placed after frontmatter are automatically excluded from JSONL query output. No changes needed to `_file_to_jsonl()`.
- Help text must clarify the distinction between `title` (concise, in query output), `desc` (short, in query output), and `details` (markdown body, NOT in query output).

**Assumptions**:
- The "ambiguous ID" error path is removed entirely (it only existed for partial matches).
- Exact match still correctly handles the case where an ID is not found.

---

## 2. High-Level Architecture

No architectural changes. Both modifications are localized:

```
entry_path()  -->  simplified awk (exact match only)
cmd_create()  -->  new --details_in_md flag, writes body after closing ---
cmd_help()    -->  updated help text
```

Data flow for details: `--details_in_md TEXT` -> written as markdown body after `---` -> visible via `show` (cat) -> invisible to `query` (_file_to_jsonl reads only frontmatter).

---

## 3. Implementation Phases

### Phase 1: Strip Partial ID Matching

**Goal**: Simplify `entry_path()` to exact-match-only. Remove all partial ID test scenarios.

**Components Affected**:
- `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/change_log` -- `entry_path()` function (lines 86-130)
- `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/id_resolution.feature` -- remove partial ID scenarios
- `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_show.feature` -- remove "Show with partial ID" scenario (lines 30-34)
- `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_edit.feature` -- remove "Edit with partial ID" scenario (lines 21-24)
- `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_notes.feature` -- remove "Add note with partial ID" scenario (lines 50-53)

**Key Steps**:

1. **Simplify `entry_path()` awk script** (lines 100-123 in `change_log`):
   - Remove all `partial_count`, `partial_file` variables and logic.
   - Remove the `index(id, search) > 0` substring match branches.
   - Keep only exact match: `id == search`.
   - The END block simplifies to: if exactly 1 exact match -> print it; if >1 exact match -> ambiguous error (defensive, shouldn't happen with unique IDs); if 0 -> not found error.
   - Update the function comment on line 86 to remove "(supports partial ID matching)".

2. **Update `id_resolution.feature`**:
   - **KEEP**: "Exact ID match" scenario (line 9-13) and "Non-existent ID error" scenario (lines 41-43).
   - **REMOVE**: "Partial ID match by suffix" (lines 15-19), "Partial ID match by prefix" (lines 21-25), "Partial ID match by substring" (lines 27-31), "Ambiguous ID error" (lines 33-38), "Exact match takes precedence" (lines 45-51), "ID resolution works with add-note command" (lines 53-56 -- this used partial ID `9999` against `test-9999`).
   - Update the feature description at top: change "I want to use partial entry IDs" to "I want to look up entries by their ID".
   - **ADD**: A new scenario that verifies a substring of an ID does NOT match (i.e., passing `1234` when ID is `abc-1234` should fail with "not found").

3. **Remove partial-ID scenarios from other feature files**:
   - `changelog_show.feature`: Remove "Show with partial ID" scenario (lines 30-34).
   - `changelog_edit.feature`: Remove "Edit with partial ID" scenario (lines 21-24).
   - `changelog_notes.feature`: Remove "Add note with partial ID" scenario (lines 50-53).

4. **Update help text in `cmd_help()`** (line 519):
   - Change `show <id>                 Display entry (supports partial ID)` to `show <id>                 Display entry`.
   - Remove "IDs stored in frontmatter; supports partial ID matching" line (near bottom of help, currently not present in exact form but check).

5. **Update README.md**:
   - Remove "(supports partial ID)" from the show command line.
   - Remove "IDs stored in frontmatter; supports partial ID matching" line.

6. **Update CLAUDE.md source** (if the CLAUDE.md is auto-generated, update the source files; if directly edited, update CLAUDE.md):
   - Change `entry_path()` description from "Resolves partial IDs by searching frontmatter `id:` fields (single awk pass)" to "Resolves entry ID to file path by searching frontmatter `id:` fields (single awk pass)".

**Dependencies**: None.

**Verification**:
- Run `make test` -- all remaining tests pass.
- Manually verify: `change_log show <exact-id>` works, `change_log show <partial-id>` fails with "not found".

---

### Phase 2: Add `--details_in_md` Flag

**Goal**: Add a `--details_in_md TEXT` flag to `cmd_create()` that writes markdown body content after the frontmatter.

**Components Affected**:
- `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/change_log` -- `cmd_create()` function
- `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_creation.feature` -- new test scenarios
- `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_query.feature` -- new scenario verifying details NOT in query
- `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/change_log` -- `cmd_help()` for updated help text

**Key Steps**:

1. **Add `--details_in_md` argument parsing** in `cmd_create()` (around line 263):
   - Add `local details=""` to the variable declarations.
   - Add case in the `while` loop: `--details_in_md) details="$2"; shift 2 ;;`

2. **Write details as markdown body** after frontmatter (around lines 371-373):
   - Currently the file write block ends with:
     ```
     echo "---"
     echo ""
     ```
   - Change to: if `details` is non-empty, write the details text after the closing `---` and blank line. The details should be written verbatim (it is markdown content).
   - Structure:
     ```
     echo "---"
     echo ""
     if [[ -n "$details" ]]; then
         printf '%s\n' "$details"
     fi
     ```

3. **Update `cmd_help()` help text**:
   - Add `--details_in_md TEXT` flag under the create command section.
   - Clarify `title` and `desc` descriptions:
     - `title`: Change to something like: `[title]                   Concise entry title (in query output)`
     - `--desc TEXT`: Change to: `Short description (in query output)`
     - `--details_in_md TEXT`: `Markdown body content (visible in show, NOT in query output)`
   - Update the AFTER_COMPLETION guidance at the bottom to mention using details for longer explanations.

4. **Update README.md** help section to match the new help text.

5. **Add test scenarios to `changelog_creation.feature`**:
   - See Acceptance Criteria below.

6. **Add test scenario to `changelog_query.feature`**:
   - See Acceptance Criteria below.

7. **Update step definitions if needed** (`features/steps/changelog_steps.py`):
   - The existing step `the created entry should contain "TEXT"` reads the full file content, so it will match body content. No new steps needed for checking body presence.
   - The existing step `the created entry should not contain "TEXT"` also works for negative checks.
   - May need a new step: `the created entry body should contain "TEXT"` that reads content AFTER the second `---`. However, the simpler approach is to just use the existing `should contain` steps since the details text will be unique enough to not collide with frontmatter. Use the simpler approach (KISS).

**Dependencies**: None (can be done in parallel with Phase 1, but sequential is fine for a small change).

**Verification**:
- Run `make test` -- all tests pass.
- Manually verify: `change_log create "test" --impact 3 --details_in_md "## Context\nSome details"` then `change_log show <id>` shows the details. `change_log query` does NOT show the details.

---

### Phase 3: Documentation Updates

**Goal**: Update CHANGELOG.md and CLAUDE.md (or its sources).

**Components Affected**:
- `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/CHANGELOG.md`
- `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/CLAUDE.md`

**Key Steps**:

1. **CHANGELOG.md** -- Add under `[Unreleased]`:
   - Under `### Removed`: "Partial ID matching -- `show`, `edit`, `add-note` now require exact IDs"
   - Under `### Added`: "`--details_in_md` flag for `create` command -- adds markdown body content visible via `show` but excluded from `query` JSONL output"
   - Under `### Changed`: "Clarified help text: `title` is concise (in query output), `desc` is short description (in query output), `details_in_md` is markdown body (not in query output)"

2. **CLAUDE.md** -- Update the `entry_path()` description:
   - From: `entry_path()` - Resolves partial IDs by searching frontmatter `id:` fields (single awk pass)
   - To: `entry_path()` - Resolves exact entry ID to file path by searching frontmatter `id:` fields (single awk pass)

**Dependencies**: Phases 1 and 2 complete.

**Verification**: Review documentation reads correctly and matches implementation.

---

## 4. Technical Considerations

### Simplified `entry_path()` awk

The simplified awk script should look conceptually like this (exact-match only):

```
awk -v search="$search" '
FNR==1 {
    if (prev_file && id != "") {
        if (id == search) { count++; match_file = prev_file }
    }
    id = ""; in_front = 0; prev_file = FILENAME
}
/^---$/ { in_front = !in_front; next }
in_front && /^id:/ { id = substr($0, 5); gsub(/^ +| +$/, "", id) }
END {
    if (prev_file && id != "") {
        if (id == search) { count++; match_file = prev_file }
    }
    if (count == 1) { print match_file; exit 0 }
    if (count > 1) { printf "Error: ambiguous ID ..." > "/dev/stderr"; exit 1 }
    printf "Error: entry not found ..." > "/dev/stderr"; exit 1
}
' "${md_files[@]}"
```

Note: The `count > 1` case is defensive (IDs are randomly generated 25-char strings, so collisions are effectively impossible), but keeping it costs nothing and prevents undefined behavior.

### Details body: no escaping needed

The `--details_in_md TEXT` value is written verbatim after the frontmatter. Since it goes AFTER the closing `---`, there is no risk of interfering with YAML parsing. The only edge case would be if the details text itself contains a line that is exactly `---` on its own line, but since `_file_to_jsonl()` uses a toggle (`in_front = !in_front`) and only processes fields while `in_front` is true, additional `---` lines in the body would toggle the flag but no field patterns would match in non-frontmatter content, so JSONL output remains correct. The `show` command uses `cat` which displays everything as-is. No issue.

### `printf '%s\n'` vs `echo` for details

Use `printf '%s\n' "$details"` instead of `echo "$details"` because `echo` interprets backslash sequences on some systems. `printf '%s\n'` is the portable way to write arbitrary text. However, note that the user might WANT `\n` to be interpreted as a newline (when passing multiline content via a single argument). This is worth considering.

**Decision**: Use `printf '%s\n' "$details"` for safety. If users need literal newlines, they can pass them as actual newlines in the argument (e.g., via `$'...\n...'` bash syntax or heredocs). This is the principle-of-least-surprise approach -- the text is written exactly as passed.

---

## 5. Acceptance Criteria (Test Scenarios)

### Phase 1: ID Resolution Tests

**`id_resolution.feature`** -- After modification, should contain these scenarios:

| # | Scenario | Description |
|---|----------|-------------|
| 1 | Exact ID match | Create entry with ID "abc-1234", `show abc-1234` succeeds, output contains `id: abc-1234` |
| 2 | Non-existent ID error | `show nonexistent` fails, output contains "Error: entry 'nonexistent' not found" |
| 3 | Substring of ID does not match | Create entry with ID "abc-1234", `show 1234` fails with "not found" |

**Removed from other features**:
- `changelog_show.feature`: "Show with partial ID" removed
- `changelog_edit.feature`: "Edit with partial ID" removed
- `changelog_notes.feature`: "Add note with partial ID" removed

### Phase 2: Details Flag Tests

**New scenarios in `changelog_creation.feature`**:

| # | Scenario | Given/When/Then |
|---|----------|-----------------|
| 1 | Create with --details_in_md | WHEN create with `--details_in_md "## Context\nDetailed explanation"` THEN succeed AND the created entry should contain "## Context" |
| 2 | Create without --details_in_md has no body | WHEN create without details THEN the created entry should NOT contain any content after the frontmatter (just frontmatter + blank line). Verify by checking entry file has expected line count or structure. |
| 3 | Details visible via show | WHEN create with details THEN `show <id>` output should contain the details text |

**New scenario in `changelog_query.feature`**:

| # | Scenario | Given/When/Then |
|---|----------|-----------------|
| 1 | Query excludes details_in_md content | WHEN create with `--details_in_md "SECRET_DETAILS_TEXT"` AND `query` THEN output should NOT contain "SECRET_DETAILS_TEXT" |

### Phase 2: Step Definitions

- No new step definitions should be needed. The existing `the created entry should contain "TEXT"` and `the output should contain "TEXT"` / `the output should not contain "TEXT"` steps cover all the assertions above.
- For the "create entry with details" test setup, the `When I run "change_log create ..."` step already handles arbitrary flags.

---

## 6. Open Questions / Decisions Needed

None. The requirements are clear and the implementation is straightforward.

---

## 7. Files Changed Summary

| File | Change Type | Description |
|------|------------|-------------|
| `change_log` | Modified | Simplify `entry_path()`, add `--details_in_md` to `cmd_create()`, update `cmd_help()` |
| `features/id_resolution.feature` | Modified | Remove partial ID scenarios, add exact-only-no-substring scenario |
| `features/changelog_show.feature` | Modified | Remove "Show with partial ID" scenario |
| `features/changelog_edit.feature` | Modified | Remove "Edit with partial ID" scenario |
| `features/changelog_notes.feature` | Modified | Remove "Add note with partial ID" scenario |
| `features/changelog_creation.feature` | Modified | Add `--details_in_md` test scenarios |
| `features/changelog_query.feature` | Modified | Add scenario verifying details excluded from query |
| `README.md` | Modified | Update help text (remove partial ID refs, add `--details_in_md`) |
| `CHANGELOG.md` | Modified | Add entries for both changes |
| `CLAUDE.md` | Modified | Update `entry_path()` description |
