# Implementation Review - Private Notes

## Testing performed

### Smoke tests (all passed)
- `create` with normal title -> correct JSON, correct filename, correct frontmatter
- `create` with duplicate title -> correct `-1` suffix collision handling
- `create` with empty title -> `untitled.md`
- `create` with special chars (hash, colon, quotes) -> correct slug, correct JSON
- `show` with partial ID -> correct resolution
- `ls` -> correct title display from frontmatter
- `dep` with partial IDs -> correct resolution and output
- `dep tree` -> correct tree display
- `ready` / `blocked` -> correct filtering
- `link` -> correct linking
- `add-note` -> correct note addition
- `query` -> correct JSONL with full_path and title

### Issues found

1. **BLOCKING: json_escape backslash bug** - `gsub(/\\/, "\\\\", s)` in awk doesn't actually double backslashes. In awk, `\\\\` in gsub replacement = `\\` which is a single backslash. Need `gsub(/\\/, "\\\\\\\\", s)` (8 backslashes in source) to produce `\\` in output. Confirmed with `printf 'a\\b\n' | awk '{gsub(/\\/, "\\\\"); print}' | od -c` -> single backslash.

2. **IMPORTANT: title with double quotes creates malformed YAML** - `title: "She said "hello""` is written as-is. Awk-based readers handle it OK by accident, but any YAML parser would fail. Need to escape inner double quotes.

3. **IMPORTANT: no filename length truncation** - 300-char title produces 300-char filename which exceeds 255-byte filesystem limit. Error: `File name too long`.

4. **MINOR: migrate-beads still writes old format** - Acknowledged as out of scope by implementor.

5. **NOT AN ISSUE: `---` as title** - This fails because `---` is parsed as a flag. But this was also true in the original code (`create "---"` would have been treated as unknown option). Pre-existing.

6. **NOT AN ISSUE: full_path can be relative or absolute** - Depends on how TICKETS_DIR is resolved. Same as before.

## DRY analysis
- 7x identical awk title extraction -> acceptable, can't share across separate awk invocations
- `_file_to_jsonl()` properly shared between create and query -> good
- `id_from_file()` is thin wrapper around yaml_field -> acceptable for readability

## Architecture compliance
- All requirements implemented correctly
- All basename calls replaced
- All awk title readers updated
- Help and README updated
- CHANGELOG updated
