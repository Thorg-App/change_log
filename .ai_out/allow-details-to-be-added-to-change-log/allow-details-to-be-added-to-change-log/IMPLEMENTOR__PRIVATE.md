# IMPLEMENTOR Private State

## Phase 1: COMPLETE
All partial ID matching stripped. Tests pass.

## Phase 2: NOT STARTED
Next phase: add `--details_in_md TEXT` flag to `cmd_create()`.

### Key locations for Phase 2:
- `cmd_create()` starts at line 260 in `change_log`
- Argument parsing `while` loop is around line 263
- File writing block ends around line 372 with `echo "---"` and `echo ""`
- `_file_to_jsonl()` (lines 142-258) already only reads frontmatter, so details body is automatically excluded from JSONL
- `cmd_help()` starts at line 499
- Use `printf '%s\n' "$details"` (not echo) for safety per plan

### Phase 2 test plan:
- Add scenarios to `features/changelog_creation.feature`
- Add scenario to `features/changelog_query.feature` verifying details excluded
- Use simpler single-line test text per reviewer correction (avoid misleading `\n`)
- Existing step definitions should suffice

### Phase 3: Documentation
- Update CHANGELOG.md after Phase 2
- CLAUDE.md already updated for Phase 1 changes
