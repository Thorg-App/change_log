# IMPLEMENTOR__PRIVATE: Fix Frontmatter Awk Toggle

## Status: COMPLETE

## What was done
Fixed `in_front = !in_front` toggle bug in 3 awk parsers within the `change_log` script.
The toggle would re-enter frontmatter mode when markdown body content contained `---` (horizontal rule),
causing `key: value` lines after that separator to leak into JSONL output.

## Fix applied (identical pattern at all 3 locations)
- Added `fm_delim=0` to state resets (BEGIN and FNR==1 blocks)
- Replaced `in_front = !in_front; next` with counter-based logic:
  ```
  fm_delim++
  if (fm_delim == 1) in_front = 1
  else if (fm_delim == 2) in_front = 0
  next
  ```
- After the 2nd `---`, `in_front` stays 0 permanently for that file

## Locations fixed
1. `_file_to_jsonl()` (~line 147) - JSONL output generation
2. `entry_path()` (~line 107) - ID lookup across files
3. `cmd_ls()` (~line 471) - Listing entries

## Test added
- New scenario in `features/changelog_query.feature`:
  "Query does not leak body content when details contain markdown horizontal rule"
- Uses `$'...'` shell syntax for newlines in --details_in_md
- Verifies fake_field/leaked_value do NOT appear in query output

## Test results
72 scenarios passed, 0 failed, 375 steps passed
