# Exploration: Submodule Changelog Directory Discovery

## Current Behavior
`find_change_log_dir()` in `change_log` (lines 8-39):
1. Env var `CHANGE_LOG_DIR` override
2. Walk parents from `$PWD` looking for `.change_log/`
3. Check root `/`
4. Auto-create at `git rev-parse --show-toplevel` (git root)
5. Error if not in git repo

**Problem:** Step 4 uses `git rev-parse --show-toplevel` which returns the **parent repo root** for submodules, not the submodule root. This causes changelog entries to be placed in the parent repo instead of the submodule.

## Desired Behavior
During the parent walk (step 2), also check for `.git` (directory or file):
- If `.change_log/` found first → use it (unchanged)
- If `.git` found first (no `.change_log/` yet) → create `.change_log/` next to `.git`
- Submodules have a `.git` **file** (not directory), regular repos have a `.git` **directory**

## Key Files
- **Main script:** `change_log` (~550 lines bash)
- **Function to modify:** `find_change_log_dir()` (lines 8-39)
- **Tests:** `features/changelog_directory.feature`
- **Steps:** `features/steps/changelog_steps.py`
- **Test infra:** `features/environment.py`

## Test Infrastructure
- BDD tests using Behave (Python)
- Each scenario gets fresh temp dir
- `git init` used to create test repos
- Run with `make test` (uses `uv run --with behave behave`)

## Important Notes
- Git submodules have `.git` as a **file** containing `gitdir: ../path`
- Regular repos have `.git` as a **directory**
- The walk should stop at EITHER `.git` file or `.git` directory
