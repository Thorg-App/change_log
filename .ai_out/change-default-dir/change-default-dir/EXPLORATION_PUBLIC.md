# Exploration: Change Default Directory `.change_log` → `_change_log`

## Task
Change default directory from `.change_log` to `_change_log` so tools like `fd` find files by default (dot-prefixed dirs are hidden from such tools).

## Findings Summary

### 31 total references to update across 8 files + 1 directory rename

| File | Occurrences | Type |
|------|------------|------|
| `change_log` (main script) | 9 | Script logic, help text |
| `features/steps/changelog_steps.py` | 13 | Test fixtures, assertions |
| `features/changelog_directory.feature` | 2 | Error message assertions |
| `features/changelog_edit.feature` | 1 | Output assertion |
| `README.md` | 2 | Documentation |
| `CLAUDE.md` | 1 | Documentation |
| `_README.template.md` | 1 | Template |
| `CHANGELOG.md` | 1 | Historical reference |
| `.change_log/` directory | 1 | Actual directory rename |

### Key function: `find_change_log_dir()` (lines 8-38)
- Walks parent dirs for `.change_log/` or `.git` boundary
- Auto-creates at nearest `.git` root
- 8 direct references to `.change_log`

### NOT changing
- `CHANGE_LOG_DIR` env var name (it's the override mechanism, separate from default)
- Function/variable names like `find_change_log_dir` (these refer to the tool concept, not the directory)
