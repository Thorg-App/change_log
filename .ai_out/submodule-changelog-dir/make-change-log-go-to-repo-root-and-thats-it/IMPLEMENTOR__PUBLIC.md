# Implementation: Fix `find_change_log_dir()` to Respect Submodule Boundaries

## Summary

Replaced the `git rev-parse --show-toplevel` fallback in `find_change_log_dir()` with `.git` boundary detection integrated into the existing parent walk loop. This correctly handles both regular repos (`.git` directory) and submodules (`.git` file).

## Changes Made

### 1. `change_log` script (lines 7-37)

**Removed:** The `git rev-parse --show-toplevel` fallback block (old lines 28-34). This subprocess call resolved to the parent repo root for submodules, which was the root cause.

**Added:** A `.git` existence check (`-e`, not `-d`) inside the parent walk `while` loop. When `.git` is found (file or directory), the function creates `.change_log/` at that location and returns it. This is checked after `.change_log/` so existing changelog directories take priority.

**Added:** WHY comment explaining that `-e` is used instead of `-d` because submodules have a `.git` file, not directory.

### 2. `features/changelog_directory.feature`

Added 2 new scenarios:
- **Auto-creates changelog in submodule with .git file** -- validates that a `.git` file (submodule) triggers `.change_log/` creation
- **Finds changelog at submodule root from subdirectory** -- validates that running from a subdirectory walks up and finds the `.git` file boundary

### 3. `features/steps/changelog_steps.py`

Added 1 new step definition:
- `Given the test directory has a .git file (simulating a submodule)` -- creates a `.git` file with `gitdir:` content, removing any existing `.git` directory first (defensive)

### 4. `CLAUDE.md`

Updated `find_change_log_dir()` description to mention `.git` boundary detection instead of the removed `git rev-parse --show-toplevel`.

## Decisions

1. **Omitted root `/` check for `.git`:** Per reviewer suggestion, no sane system has `/.git`. Kept the existing `/.change_log` root check but did not add a `/.git` check. KISS.

2. **Did not add explicit "priority" scenario:** The existing "Find changelog in parent directory" scenarios already cover that `.change_log/` is found before `.git` since the Background creates `.change_log/` and the test directory has `.git` from git init. Adding a redundant scenario would not test a new code path.

3. **Kept the defensive `shutil.rmtree` guard in step definition:** Though not strictly needed for current scenarios, it prevents confusion if someone later combines `the test directory is a git repository` with `the test directory has a .git file`.

## Test Results

All 74 scenarios pass, 0 failures, 388 steps passed. Both new scenarios execute correctly.
