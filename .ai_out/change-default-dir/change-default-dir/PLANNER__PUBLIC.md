# Plan: Change Default Directory `.change_log` to `_change_log`

## Problem Understanding

The default directory `.change_log` uses a dot-prefix, which causes tools like `fd`, `rg`, and other modern CLI tools to skip it by default (dot-prefixed directories are treated as hidden). Changing to `_change_log` makes changelog entries discoverable by these tools without requiring `--hidden` flags.

**This is a CLEAN BREAK.** No backward compatibility shims. No migration code.

### What changes
- The string literal `.change_log` used as a **directory name** becomes `_change_log`

### What does NOT change
- `CHANGE_LOG_DIR` env var name (it is the override mechanism, not the default)
- Function/variable names like `find_change_log_dir` (they describe the concept, not the literal directory)
- The overall architecture, data model, or command interface

## Implementation Phases

### Phase 1: Main Script (`change_log`)

**File:** `/usr/local/workplace/mirror/thorg-root-mirror-5/submodules/change_log/change_log`

9 occurrences of `.change_log` to change to `_change_log`. All are string literals used as directory names.

**Line-by-line changes:**

| Line | Current | New |
|------|---------|-----|
| 5 | `# Stores markdown files with YAML frontmatter in ./.change_log/` | `# Stores markdown files with YAML frontmatter in ./_change_log/` |
| 15 | `# 2. Walk parents looking for .change_log/ or .git boundary` | `# 2. Walk parents looking for _change_log/ or .git boundary` |
| 18 | `if [[ -d "$dir/.change_log" ]]; then` | `if [[ -d "$dir/_change_log" ]]; then` |
| 19 | `echo "$dir/.change_log"` | `echo "$dir/_change_log"` |
| 25 | `mkdir -p "$dir/.change_log"` | `mkdir -p "$dir/_change_log"` |
| 26 | `echo "$dir/.change_log"` | `echo "$dir/_change_log"` |
| 33 | `[[ -d "/.change_log" ]] && { echo "/.change_log"; return 0; }` | `[[ -d "/_change_log" ]] && { echo "/_change_log"; return 0; }` |
| 36 | `echo "Error: no .change_log directory found and not in a git repository" >&2` | `echo "Error: no _change_log directory found and not in a git repository" >&2` |
| 535 | `Entries stored as markdown in ./.change_log/ (auto-created at nearest .git root)` | `Entries stored as markdown in ./_change_log/ (auto-created at nearest .git root)` |

**Approach:** Use `replace_all` with `.change_log` -> `_change_log` on the script file. This is safe because every occurrence of `.change_log` in the file refers to the directory name. There are no occurrences where `.change_log` means something else.

**Verification:** After replacement, confirm 0 occurrences of `.change_log` remain and 9 occurrences of `_change_log` exist.

### Phase 2: Test Step Definitions (`features/steps/changelog_steps.py`)

**File:** `/usr/local/workplace/mirror/thorg-root-mirror-5/submodules/change_log/features/steps/changelog_steps.py`

13 occurrences across several functions. All are string literals `'.change_log'` used to construct `Path(context.test_dir) / '.change_log'`.

**Functions affected:**
- `create_entry()` (line 38) -- default `changelog_dir` path
- `find_entry_file()` (lines 71-72) -- fallback scan directory
- `step_clean_changelog_directory()` (line 166) -- clean setup
- `step_changelog_dir_not_exist()` (line 176) -- ensure non-existence
- `step_changelog_dir_exists()` (line 410) -- assertion
- `step_file_named_exists_in_changelog()` (lines 495, 498) -- filename assertion

Also 4 occurrences in **docstrings/comments** (lines 36, 165, 175, 409, 494).

**Approach:** Use `replace_all` with `'.change_log'` -> `'_change_log'` for the Python string literals. Then separately update the docstrings/comments that reference `.change_log/` as prose.

**Important detail:** Some occurrences are in single-quoted Python strings (`'.change_log'`), others are in comments/docstrings. The `replace_all` for the path string `'.change_log'` will catch the functional code. The comment/docstring references need separate updates:
- Line 36: `Defaults to <test_dir>/.change_log/.` -> `Defaults to <test_dir>/_change_log/.`
- Line 71: `# Fallback: scan .change_log/ directory` -> `# Fallback: scan _change_log/ directory`
- Line 165: `"""Ensure we start with a clean .change_log directory."""` -> `"""Ensure we start with a clean _change_log directory."""`
- Line 175: `"""Ensure .change_log directory does not exist."""` -> `"""Ensure _change_log directory does not exist."""`
- Line 409: `"""Assert .change_log directory exists."""` -> `"""Assert _change_log directory exists."""`
- Line 411: `f".change_log directory does not exist at {changelog_dir}"` -> `f"_change_log directory does not exist at {changelog_dir}"`
- Line 494: `"""Assert a specific filename exists in .change_log/ directory."""` -> `"""Assert a specific filename exists in _change_log/ directory."""`
- Line 498: `f"File {filename} does not exist in .change_log/..."` -> `f"File {filename} does not exist in _change_log/..."`

**Simplification:** Since EVERY occurrence of `.change_log` in this file refers to the directory name, a single `replace_all` of `.change_log` -> `_change_log` will handle all 13 occurrences (both code and comments) cleanly.

### Phase 3: Feature Files

**3a.** `features/changelog_directory.feature` -- 2 occurrences (lines 55, 62)

Both are in `And the output should contain "no .change_log directory found"`. Change to:
- `And the output should contain "no _change_log directory found"`

**3b.** `features/changelog_edit.feature` -- 1 occurrence (line 14)

`And the output should contain ".change_log/"` -> `And the output should contain "_change_log/"`

### Phase 4: Documentation

**4a.** `README.md` -- 2 occurrences (lines 4, 58)

- Line 4: `frontmatter in `./.change_log/`.` -> `frontmatter in `./_change_log/`.`
- Line 58: `Entries stored as markdown in ./.change_log/` -> `Entries stored as markdown in ./_change_log/`

NOTE: `README.md` is generated from `_README.template.md` via `README.generate.sh`, so we update BOTH. The README.md help text block (line 58) is generated from `change_log help` output, so updating the script (Phase 1) already fixes it. The intro text (line 4) comes from the template.

**4b.** `_README.template.md` -- 1 occurrence (line 6)

`frontmatter in `./.change_log/`.` -> `frontmatter in `./_change_log/`.`

**4c.** `CLAUDE.md` -- 1 occurrence (line 12)

`walks parents for `.change_log/` or `.git` boundary` -> `walks parents for `_change_log/` or `.git` boundary`

**4d.** `CHANGELOG.md` -- 1 occurrence (line 14)

`Storage directory changed from `.tickets/` to `./.change_log/`` -> `Storage directory changed from `.tickets/` to `./_change_log/``

Also add a new entry under `[Unreleased]` section:

```markdown
### Changed
- **BREAKING**: Default storage directory changed from `.change_log/` to `_change_log/` (no longer hidden from `fd`, `rg`, etc.)
```

### Phase 5: Rename the Actual Directory

Rename the existing `.change_log/` directory at the repo root to `_change_log/`.

```bash
git mv .change_log _change_log
```

This preserves git history for the files inside.

### Phase 6: Regenerate README.md

Run `./README.generate.sh` to regenerate `README.md` from `_README.template.md` with the updated `change_log help` output. Verify the generated README has `_change_log` everywhere.

## Verification Strategy

### Step 1: Run tests
```bash
make test
```
All tests must pass. The tests exercise the full lifecycle including directory auto-creation, directory walking, error messages, and file assertions.

### Step 2: Grep for stale references
```bash
rg '\.change_log' --no-ignore --hidden -g '!.ai_out' -g '!.tmp' -g '!doc/' -g '!.git' -g '!ask.dnc.md' -g '!formatted_request.dnc.md'
```
This should return 0 results. The excluded paths are non-functional files (AI artifacts, docs about the old transformation, request files).

### Step 3: Verify directory exists
```bash
ls -d _change_log/
```

## Files Changed (Complete List)

| # | File | Change Type |
|---|------|-------------|
| 1 | `change_log` | Replace `.change_log` -> `_change_log` (9 occurrences) |
| 2 | `features/steps/changelog_steps.py` | Replace `.change_log` -> `_change_log` (13 occurrences) |
| 3 | `features/changelog_directory.feature` | Update error message assertions (2 occurrences) |
| 4 | `features/changelog_edit.feature` | Update output assertion (1 occurrence) |
| 5 | `README.md` | Update directory references (2 occurrences) |
| 6 | `_README.template.md` | Update directory reference (1 occurrence) |
| 7 | `CLAUDE.md` | Update directory reference (1 occurrence) |
| 8 | `CHANGELOG.md` | Update historical reference + add new entry (1 occurrence + new section) |
| 9 | `.change_log/` -> `_change_log/` | Directory rename via `git mv` |

## Risk Assessment

**Low risk.** This is a mechanical string substitution. Every occurrence of `.change_log` in the codebase refers to the same thing -- the directory name. There are no ambiguous usages. The tests provide comprehensive coverage of the directory discovery and auto-creation logic.

## Execution Order

1. Phase 1 (script) -- so `change_log help` output is updated before README regeneration
2. Phase 2 (test steps) -- so test infrastructure matches
3. Phase 3 (feature files) -- so test assertions match
4. Phase 5 (directory rename) -- before running tests, so the actual directory exists
5. Phase 4 (documentation) -- docs match the new reality
6. Phase 6 (regenerate README) -- uses the updated script
7. Verification -- run tests, grep for stale references
