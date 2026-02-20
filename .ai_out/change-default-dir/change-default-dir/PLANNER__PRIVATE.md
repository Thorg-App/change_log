# Planner Private Notes

## Key observations

### `replace_all` is safe for both main files
Every occurrence of `.change_log` in `change_log` (the script) and `changelog_steps.py` refers to the directory name. No false positives. A single `replace_all` per file handles everything cleanly.

### The Grep tool could not find `.change_log` references
The built-in Grep tool failed to find matches (possibly a path or escaping issue). Had to fall back to `rg` via Bash. The implementor should be aware and use Bash-based `rg` for verification rather than the Grep tool if needed.

### Files to skip intentionally
- `.ai_out/` -- AI workflow artifacts, not functional code
- `.tmp/` -- temporary test outputs
- `doc/ralph/` -- historical design documents about the original changelog transformation
- `ask.dnc.md`, `formatted_request.dnc.md` -- request files for this task itself
- These should be excluded from the "stale reference grep" verification

### README.md is generated
`README.md` is generated from `_README.template.md` via `README.generate.sh`. The intro text comes from the template, the Usage block comes from `change_log help`. Both need updating, but the Usage block will auto-update when README is regenerated after the script is updated.

### CHANGELOG.md historical reference
Line 14 says `Storage directory changed from `.tickets/` to `./.change_log/``. This is a historical statement. Updating it to `_change_log` is correct because we are doing a clean break -- the directory was never publicly released as `.change_log` to external users; this is an evolving project.

### Test coverage
The existing tests in `changelog_directory.feature` comprehensively cover:
- Finding `_change_log` in current, parent, grandparent directories
- `CHANGE_LOG_DIR` env var override
- Auto-creation at git root (both `.git` directory and `.git` file)
- Error when no directory found
- Error message text (which we update)

No new test scenarios needed. The existing scenarios will validate the rename.
