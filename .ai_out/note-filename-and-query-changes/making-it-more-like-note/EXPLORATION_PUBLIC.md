# Exploration Summary

## Current Behavior

### File Creation (`cmd_create()` at ticket:157-234)
- `generate_id()` creates IDs from directory name prefix + 4-char random (e.g., `nt-a3x7`)
- File written as `$TICKETS_DIR/${id}.md`
- `id` field in frontmatter = filename stem
- Title placed as `# heading` in body (NOT in frontmatter)

### Title Handling
- Title is ONLY in markdown body as `# heading` (line 213: `echo "# $title"`)
- All awk readers extract title via: `!in_front && /^# / && title == "" { title = substr($0, 3) }`
- This pattern appears at lines: 321, 505, 682, 729, 819, 866, 1146

### Query (`cmd_query()` at ticket:1321-1384)
- `--include-full-path` flag controls whether `full_path` key is added to JSON
- Only frontmatter fields go to JSON output (title is NOT included since it's in body)
- JSONL format, optional jq filter

### Key Functions
- `generate_id()`: lines 81-97
- `ticket_path()`: resolves partial IDs via filename matching
- `cmd_create()`: lines 157-234
- `cmd_query()`: lines 1321-1384

## Required Changes

1. **Filename = title-based**: `my-note-title.md` instead of `nt-a3x7.md`
   - The `id` field in frontmatter becomes the title-based name (filename stem)
   - Duplicate handling: append `-1`, `-2`, etc.

2. **Title in frontmatter**: Add `title: "Original Title"` to YAML frontmatter
   - Remove `# Title` heading from body

3. **Query always includes file path**: Remove `--include-full-path` flag, always include

4. **Query includes title**: Since title moves to frontmatter, awk will pick it up automatically

## Test Files
- 13 feature files under `features/`
- Step defs: `features/steps/ticket_steps.py` (742 lines)
- `create_ticket()` helper writes files directly — needs updating
- Key test files to modify: `ticket_creation.feature`, `ticket_query.feature`
