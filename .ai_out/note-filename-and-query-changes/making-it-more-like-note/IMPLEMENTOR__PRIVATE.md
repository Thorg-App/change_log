# IMPLEMENTOR Private State

## Status: Phases 1-7 COMPLETE (script + docs only)

## Completed

### Phase 1: Helper Functions
- `generate_id()` rewritten: 25-char random [a-z0-9], SIGPIPE fix with `|| true`
- `title_to_filename()` added: slug conversion, collision handling with -1, -2, etc.
- `id_from_file()` added: thin wrapper around `yaml_field "$1" "id"`

### Phase 2: ticket_path() Rewrite
- Single awk pass through all `$TICKETS_DIR/*.md` files
- Extracts `id:` from frontmatter using `substr($0, 5)` (safe from FS splitting)
- Exact match first, then partial match
- Guard clause for no .md files (avoids glob expansion error)
- Uses `\x27` for single quotes in awk printf (avoids bash quoting issues)

### Phase 3: cmd_create() Update
- Title-based filename via `title_to_filename()`
- `title: "..."` in frontmatter (always double-quoted)
- No `# heading` in body
- Outputs JSONL via `_file_to_jsonl()`
- `parent` resolved via `id_from_file()` instead of basename

### Phase 4: basename Replacements
- All 11 remaining `basename "$file" .md` replaced with `id_from_file()`
- Locations: cmd_status, cmd_dep (2), cmd_undep (2), cmd_link, cmd_unlink (3), cmd_show, cmd_add_note

### Phase 5: Awk Title Extraction
- All 7 occurrences replaced
- Original: `!in_front && /^# / && title == "" { title = substr($0, 3) }`
- New: `in_front && /^title:/ { title = substr($0, 8); gsub(...); if (...) substr(...) }`
- CRITICAL FIX: awk does NOT support backreferences in gsub. Changed from `gsub(/^"(.*)"$/, "\\1", title)` to `if (title ~ /^".*"$/) title = substr(title, 2, length(title) - 2)`

### Phase 6: cmd_query() Update
- Removed `--include-full-path` flag parsing
- Now uses shared `_file_to_jsonl()` function
- Always includes `full_path` in output

### Phase 7: Help + README
- Updated create description: "prints JSON with id and full_path"
- Removed `--include-full-path` from query help
- Updated partial ID matching description
- Updated README usage section to match

## Key Decisions
1. `_file_to_jsonl()` includes `json_escape()` function for proper JSON escaping (backslashes and double quotes)
2. `_file_to_jsonl()` strips surrounding double quotes from frontmatter values before JSON output
3. `ticket_path()` uses bash array for md_files to avoid glob expansion issues with `2>/dev/null`
4. `cmd_migrate_beads()` left UNTOUCHED per plan scope decision

## Bugs Found and Fixed
1. awk `gsub` backreference issue: `gsub(/^"(.*)"$/, "\\1", title)` outputs literal `\1` in awk. Fixed with `if/substr` approach.
2. SIGPIPE in `generate_id()`: `tr | head` causes SIGPIPE under `set -euo pipefail`. Fixed with `|| true`.

## Remaining Work
- Phases 8-9: Test infrastructure and feature file updates (separate task)
