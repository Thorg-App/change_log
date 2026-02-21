# Review: refactor-manually-change-log-dir-name

**Verdict: NOT READY**

**Branch:** `refactor-manually-change-log-dir-name`
**Diff range:** `981a0cc..HEAD`
**Reviewer focus:** Logical issues only (no nitpicks)

## What the change does

Renames the default changelog directory from `.change_log` to `_change_log` across the entire codebase: the main bash script (`find_change_log_dir()` + help text), all documentation (README, CLAUDE.md, CHANGELOG.md, design doc, README template), BDD feature files, and Python test step definitions.

The mechanical replacement is **complete** — no stale `.change_log` references remain in tracked files.

Tests pass (when `CHANGE_LOG_DIR` is not set in the environment).

## Issues

### 1. [IMPORTANT] No backward compatibility for existing `.change_log/` directories

**File:** `change_log`, `find_change_log_dir()` (lines ~8-38)

After this change, any user (or repo) that already has a `.change_log/` directory will see the tool silently ignore it. The tool will either:
- Hit a `.git` boundary first and create a **new** `_change_log/` directory (existing entries become invisible)
- Fail with `"no _change_log directory found"`

**Evidence:** The old `.change_log/` directory still exists in this very repo with 3 orphaned entries.

**Suggested fix:** Add detection of the old directory name in `find_change_log_dir()`. When about to auto-create `_change_log/` at a `.git` boundary, check if `.change_log/` exists there. If so, print a warning:
```
Warning: found old .change_log/ directory at $dir — rename it to _change_log/ to migrate
```
This is low-effort and prevents silent data loss.

### 2. [MINOR] CHANGELOG.md missing entry for this rename

The existing CHANGELOG entry was updated in-place (`Storage directory changed from .tickets/ to ./_change_log/`), but there is no **new** entry documenting the `.change_log` -> `_change_log` rename. This is a breaking change for existing users and should be logged under `[Unreleased]`.

## Observations (not blocking, separate follow-ups)

### Orphaned `.change_log/` directory in this repo
The old `/usr/local/workplace/thorg-root/submodules/change_log/.change_log/` with 3 entries should be cleaned up (migrated or removed) as part of this PR.

### Test isolation: `CHANGE_LOG_DIR` leaks into test subprocesses (pre-existing)
In `features/steps/changelog_steps.py`, `_run_command()` copies `os.environ` without stripping `CHANGE_LOG_DIR`. When this env var is set (as it is in the thorg dev environment), all tests target the real repo directory instead of the test temp directory. Fix: `env.pop('CHANGE_LOG_DIR', None)` in `_run_command()`. This is pre-existing and should be a separate ticket.

## Summary

The rename itself is mechanically clean and complete. The blocker is the lack of backward-compatibility detection for existing `.change_log/` directories — this will silently orphan entries for any user who upgrades. A simple warning in `find_change_log_dir()` resolves this.
