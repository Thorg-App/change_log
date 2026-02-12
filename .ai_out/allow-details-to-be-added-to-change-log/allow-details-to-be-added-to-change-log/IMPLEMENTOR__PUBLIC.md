# Phase 1 Implementation: Strip Partial ID Matching

## Status: COMPLETE

All changes implemented and all 68 test scenarios pass (0 failures).

## Changes Made

### 1. Simplified `entry_path()` in `change_log` (line 86-130)
- Removed all partial/substring matching logic (`partial_count`, `partial_file`, `index(id, search)` branches)
- Kept exact match only: `id == search`
- Kept defensive `count > 1` case for ambiguous exact matches
- Updated function comment from "supports partial ID matching" to "exact match only"
- Updated awk comment from "collect all id-to-filename mappings, then resolve" to "find exact id match across all entry files"

### 2. Updated `features/id_resolution.feature`
- Updated feature description: "I want to look up entries by their ID" / "So that I can reference specific changelog entries"
- KEPT: "Exact ID match" scenario
- KEPT: "Non-existent ID error" scenario
- REMOVED: 5 partial-ID scenarios (suffix, prefix, substring, ambiguous, exact-takes-precedence)
- REMOVED: "ID resolution works with add-note command" (used partial ID)
- ADDED: "Substring of ID does not match" scenario (verifies `1234` does NOT match `abc-1234`)

### 3. Removed partial-ID scenarios from other feature files
- `features/changelog_show.feature`: Removed "Show with partial ID" scenario (lines 30-34)
- `features/changelog_edit.feature`: Removed "Edit with partial ID" scenario (lines 21-24)
- `features/changelog_notes.feature`: Removed "Add note with partial ID" scenario (lines 50-53)

### 4. Updated help text in `cmd_help()` (line 516)
- Changed `show <id>                 Display entry (supports partial ID)` to `show <id>                 Display entry`

### 5. Updated `README.md`
- Removed "(supports partial ID)" from show command line (line 51)
- Removed "IDs stored in frontmatter; supports partial ID matching" line (line 59)

### 6. Updated `CLAUDE.md`
- Changed `entry_path()` description from "Resolves partial IDs by searching frontmatter `id:` fields" to "Resolves exact entry ID to file path by searching frontmatter `id:` fields"

## Decisions
- No deviations from the plan. All reviewer corrections were incorporated.
- The simplified awk retains the defensive `count > 1` exact match case as the plan specified.

## Files Modified
| File | Change |
|------|--------|
| `change_log` | Simplified `entry_path()`, updated help text |
| `features/id_resolution.feature` | Rewrote to exact-match-only scenarios |
| `features/changelog_show.feature` | Removed partial ID scenario |
| `features/changelog_edit.feature` | Removed partial ID scenario |
| `features/changelog_notes.feature` | Removed partial ID scenario |
| `README.md` | Removed partial ID references |
| `CLAUDE.md` | Updated entry_path() description |

## Test Results
- 8 features passed, 0 failed
- 68 scenarios passed, 0 failed
- 352 steps passed, 0 failed

## Next: Phase 2
Phase 2 (add `--details_in_md` flag) is ready to be implemented. No blockers.
