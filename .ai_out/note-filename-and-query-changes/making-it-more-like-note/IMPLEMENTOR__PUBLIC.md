# IMPLEMENTOR Public Summary

## Status: Phases 1-7 COMPLETE

All script and documentation changes are implemented and smoke-tested. Test files (Phases 8-9) are NOT modified per task scope.

## Changes Made

### Files Modified
1. `/home/nickolaykondratyev/git_repos/note-ticket/ticket` -- core script
2. `/home/nickolaykondratyev/git_repos/note-ticket/README.md` -- documentation

### Script Changes Summary

#### New/Modified Functions
| Function | Change | Location |
|---|---|---|
| `generate_id()` | Produces 25-char random `[a-z0-9]` (was: dir-prefix + 4-char) | Line ~81 |
| `title_to_filename()` | NEW: slug conversion with collision handling | Line ~87 |
| `id_from_file()` | NEW: extracts `id:` from frontmatter via `yaml_field` | Line ~113 |
| `ticket_path()` | Rewritten: single awk pass through frontmatter `id:` fields | Line ~123 |
| `_file_to_jsonl()` | NEW: shared JSONL generator used by create and query | Line ~192 |
| `cmd_create()` | Title-based filename, title in frontmatter, JSON output | Line ~247 |
| `cmd_query()` | Uses `_file_to_jsonl()`, removed `--include-full-path` | Line ~1411 |
| `cmd_help()` | Updated descriptions and removed `--include-full-path` | Line ~1522 |

#### Mechanical Replacements
- 7x awk title extraction: `!in_front && /^# /` replaced with `in_front && /^title:/`
- 11x `basename "$file" .md` replaced with `id_from_file "$file"`

### Data Model Change

**Before:**
```
File: .tickets/nt-a3x7.md
---
id: nt-a3x7
status: open
---
# My Title
```

**After:**
```
File: .tickets/my-title.md
---
id: abc123def456ghi789jkl0mn1
title: "My Title"
status: open
---

```

### Deviations from Plan

1. **awk backreference fix**: Plan specified `gsub(/^"(.*)"$/, "\\1", title)` for stripping quotes. This does NOT work in awk (no backreference support in gsub). Replaced with `if (title ~ /^".*"$/) title = substr(title, 2, length(title) - 2)`.

2. **SIGPIPE fix in generate_id()**: The `tr | head` pipe causes SIGPIPE exit code 141 under `set -euo pipefail`. Added `|| true` and wrapped in local variable assignment.

3. **ticket_path() glob handling**: Instead of `"$TICKETS_DIR"/*.md 2>/dev/null` (which suppresses awk stderr), used bash array expansion with a guard clause checking `[[ ! -f "${md_files[0]}" ]]`.

4. **json_escape() in _file_to_jsonl()**: Added proper JSON escaping for backslashes and double quotes, which the original `cmd_query()` awk lacked.

5. **cmd_migrate_beads() untouched**: Per plan reviewer's guidance, this is explicitly out of scope.

### Smoke Test Results

All commands tested successfully:
- `create` -- outputs JSON, title-based filename, collision handling
- `show` -- partial ID resolution via frontmatter search
- `ls`, `ready`, `blocked`, `closed` -- correct title display from frontmatter
- `dep`, `undep` -- ID resolution and output messages use frontmatter ID
- `link`, `unlink` -- same
- `add-note` -- same
- `dep tree` -- correct title and tree display
- `dep cycle` -- works
- `query` -- always includes `full_path` and `title`
- `help` -- updated output

### What's Next (Phases 8-9)

Test infrastructure and feature files need updating to match the new data model. Key areas:
- `create_ticket()` helper in step defs: write title-based filename + frontmatter title
- Step defs that construct paths as `f'{ticket_id}.md'`: use `context.tickets[ticket_id]`
- `step_output_matches_id_pattern()`: validate JSON output instead of bare ID
- Feature files: update assertions for JSON output and frontmatter title
