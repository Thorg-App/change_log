# IMPLEMENTOR__PUBLIC: Phase 01 -- Core Script Transformation

## Summary

The `change_log` script has been created at `/home/nickolaykondratyev/git_repos/Thorg-App_change_log/change_log` (578 lines, executable). It is a complete transformation of the `ticket` script (1593 lines) into a changelog system for AI agents. The original `ticket` script remains untouched.

## What Was Implemented

### New Script: `change_log`
- **578 lines** (down from 1593 -- 63% reduction)
- All ticketing concepts removed: status workflows, dependency tracking, linking, plugin system
- New changelog data model with `impact` (required), `type`, `desc`, `tags`, `dirs`, `ap`, `note_id` fields

### Commands Available
| Command | Description |
|---------|-------------|
| `create <title> --impact N [opts]` | Creates changelog entry with timestamp filename |
| `ls [--limit=N]` | Lists entries most-recent-first |
| `show <id>` | Displays entry (partial ID supported) |
| `edit <id>` | Opens in $EDITOR |
| `add-note <id> [text]` | Appends timestamped note |
| `query [jq-filter]` | Outputs JSONL (requires jq for filter) |
| `help` | Shows usage |

### Key Technical Details
- **Filenames**: `YYYY-MM-DD_HH-MM-SSZ.md` (ISO8601 UTC timestamps)
- **Directory**: `./change_log/` auto-created at git repo root
- **`CHANGE_LOG_DIR`**: env var override works
- **ID system**: 25-char random IDs in frontmatter, partial matching via awk
- **JSONL**: `impact` emitted as JSON number, `ap`/`note_id` as JSON objects, `tags`/`dirs` as JSON arrays
- **Sorting**: `ls` and `query` both output most-recent-first (reverse filename sort)
- **`_file_to_jsonl()` awk**: Extended with map support (state machine for `ap:` / `note_id:` YAML maps)
- **Collision handling**: `sleep 1` retry for same-second creates

## Deviations from Plan

### 1. Line Count: 578 vs Estimated 350-400
The script is larger than estimated primarily because:
- The `_file_to_jsonl()` awk is more lines than anticipated due to map parsing
- Full validation code in `cmd_create()` takes more space
- This is acceptable -- the code is clean and has no dead weight.

### 2. Fixed Map Key Colon Bug (Not in Plan)
During testing, discovered that when awk `FS=": "` processes a line like `ap:` (map key with no value after colon), `$1` includes the trailing colon (`ap:` instead of `ap`). Added `sub(/:$/, "", key)` to strip it. This was not anticipated in the plan's awk pseudocode.

### 3. `cmd_ls()` Uses `substr(id, 1, 8)` in Awk
Added explicit `substr(id, 1, 8)` truncation in the awk `emit()` function for cleaner output, rather than relying on `%-8s` printf truncation behavior.

### 4. Used `mapfile` Approach Per Reviewer Recommendation
Both `cmd_ls()` and `cmd_query()` use `mapfile -t` for collecting sorted files, as recommended by the plan reviewer. No `xargs` with bash functions.

### 5. Used `_grep` in `cmd_add_note()` Per Reviewer Recommendation
Fixed the `grep -q '^## Notes'` to use `_grep -q '^## Notes'` for portability.

## Test Results (All 18 Acceptance Criteria Pass)

| # | Test | Result |
|---|------|--------|
| 1 | `help` shows changelog text, no mention of tickets/plugins | PASS |
| 2 | `create "Test"` (no impact) fails with clear error | PASS |
| 3 | `create "Test" --impact 6` fails with range error | PASS |
| 4 | `create "Test" --impact 3 -t invalid` fails with type error | PASS |
| 5 | `create "First change" --impact 2` creates file, prints JSONL | PASS |
| 6 | Full create with all options writes correct frontmatter | PASS |
| 7 | `ap` and `note_id` omitted when not provided | PASS |
| 8 | `ls` shows entries most-recent-first | PASS |
| 9 | `ls --limit=1` limits output | PASS |
| 10 | `show <partial-id>` displays full file content | PASS |
| 11 | `edit <partial-id>` via EDITOR=cat works | PASS |
| 12 | `add-note <id> "text"` appends timestamped note | PASS |
| 13 | `query` outputs valid JSONL, most-recent-first | PASS |
| 14 | `query \| jq .desc` returns desc or null | PASS |
| 15 | `query '.impact > 3'` filters correctly | PASS |
| 16 | Unknown command `start abc` fails with error | PASS |
| 17 | `CHANGE_LOG_DIR=/tmp/x` override works | PASS |
| 18 | Auto-creates `change_log/` at git root from subdirectory | PASS |

## Files Changed
- **NEW**: `/home/nickolaykondratyev/git_repos/Thorg-App_change_log/change_log` (578 lines, executable)
- **UNCHANGED**: `/home/nickolaykondratyev/git_repos/Thorg-App_change_log/ticket` (original script preserved)
