# Fix Frontmatter Awk Toggle Bug

## Summary
Fixed the `in_front = !in_front` toggle bug in 3 awk frontmatter parsers within the `change_log` script. The toggle re-entered frontmatter mode when markdown body content contained `---` (horizontal rule), causing body `key: value` lines to leak into JSONL output.

## Changes

### `change_log` script (3 locations)
Replaced boolean toggle with counter-based approach (`fm_delim++`) that permanently exits frontmatter mode after the 2nd `---` delimiter:
- `_file_to_jsonl()` - JSONL output generation
- `entry_path()` - ID lookup
- `cmd_ls()` - Entry listing

### BDD test
Added scenario "Query does not leak body content when details contain markdown horizontal rule" to `features/changelog_query.feature`.

## Test Results
72 scenarios passed, 0 failed, 375 steps passed.

## Not in scope
- The `ticket` script has the same bug in 10 locations (separate repo concern per task instructions).
