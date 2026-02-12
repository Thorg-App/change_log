# Exploration: Fix Frontmatter Awk Toggle

## Bug
The `in_front = !in_front` toggle in awk frontmatter parsers re-enters frontmatter mode when markdown body contains `---` (horizontal rule). This causes body content with `key: value` patterns to leak into JSONL output.

## Affected Locations in `change_log`
| Function | Line | Purpose |
|----------|------|---------|
| `_file_to_jsonl()` | ~151 | JSONL output (PRIMARY - body leaks into query) |
| `entry_path()` | ~109 | ID lookup (could match false IDs from body) |
| `cmd_ls()` | ~470 | Listing (could show wrong field values) |

## Affected Locations in `ticket` script
Path: `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/note-ticket/ticket`
10 locations with same toggle pattern. Same bug exists there.

## Fix Approach
Replace `in_front = !in_front` with counter: `fm_delim++; if (fm_delim == 1) in_front = 1; else if (fm_delim == 2) in_front = 0; next`
After 2nd `---`, `in_front` stays 0 permanently for that file. Reset `fm_delim=0` on `FNR==1`.

## Existing Tests
- `features/changelog_query.feature` has 11 scenarios
- Scenario "Query excludes details_in_md content" exists but does NOT test `---` in body
- Need new test: body with `---` and `key: value` after it

## Files
- Script: `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/change_log`
- Tests: `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_query.feature`
- Steps: `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/steps/changelog_steps.py`
- Ticket script: `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/note-ticket/ticket`
