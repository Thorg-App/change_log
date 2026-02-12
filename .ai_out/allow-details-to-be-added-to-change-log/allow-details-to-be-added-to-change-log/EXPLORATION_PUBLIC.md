# Exploration: change_log modifications

## Task Summary
1. Strip partial ID matching (simplify to exact-only)
2. Add `--details_in_md TEXT` flag for markdown body content in entries
3. Clarify title/desc in help as being part of query output (concise/short)

## Key Code Locations

### Partial ID Matching (TO REMOVE)
- **`entry_path()`**: `change_log` lines 87-130 - awk-based partial ID resolution
- **Callers**: `cmd_show()` L385, `cmd_edit()` L402, `cmd_add_note()` L418
- **Tests**: `features/id_resolution.feature` (8 scenarios, 57 lines)
- **Help references**: L519 "supports partial ID", L524 "supports partial ID matching"
- **README references**: mentions partial ID matching

### Entry Creation (TO MODIFY)
- **`cmd_create()`**: `change_log` lines 260-376
- **Frontmatter writing**: lines 335-372
- **Currently NO markdown body** - entries are frontmatter-only (line 372 just closes with `---` and blank line)
- **Tests**: `features/changelog_creation.feature` (145 lines)

### JSONL/Query Output (title/desc already included)
- **`_file_to_jsonl()`**: lines 142-258 - awk-based JSONL generator
- title and desc are already in JSONL output
- Body/details should NOT be in JSONL output (too verbose)

### Help Text
- **`cmd_help()`**: lines 499-527
- Also duplicated in README.md lines 33-60

### Files to Update
- `change_log` (main script)
- `features/id_resolution.feature` (remove/simplify)
- `features/changelog_creation.feature` (add details tests)
- `features/steps/changelog_steps.py` (update step defs if needed)
- `README.md` (update usage section)
- `CHANGELOG.md` (add entries)
- `CLAUDE.md` sources (if help text referenced there)
