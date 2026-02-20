# Implementation: Change Default Directory `.change_log` to `_change_log`

## Status: COMPLETE

## Summary

Renamed the default storage directory from `.change_log` (hidden) to `_change_log` (visible) so that tools like `fd`, `rg`, and other modern CLI tools can discover changelog entries without `--hidden` flags.

This is a **clean break** with no backward compatibility shims.

## Changes Made

| # | File | What Changed |
|---|------|-------------|
| 1 | `change_log` | 9 occurrences of `.change_log` -> `_change_log` (directory name in find logic, error messages, help text) |
| 2 | `features/steps/changelog_steps.py` | 14 occurrences of `.change_log` -> `_change_log` (path construction, comments, docstrings, assertions) |
| 3 | `features/changelog_directory.feature` | 2 occurrences: error message assertions updated |
| 4 | `features/changelog_edit.feature` | 1 occurrence: output assertion updated |
| 5 | `README.md` | 2 occurrences: intro text and help block updated |
| 6 | `_README.template.md` | 1 occurrence: intro text updated |
| 7 | `CLAUDE.md` | 1 occurrence: `find_change_log_dir()` description updated |
| 8 | `CHANGELOG.md` | Historical reference updated + new `[Unreleased] Changed` entry added |
| 9 | `.change_log/` -> `_change_log/` | Directory renamed via `git mv` |

## What Was NOT Changed

- Function names (e.g., `find_change_log_dir`) -- these describe the concept, not the literal directory
- Environment variable name `CHANGE_LOG_DIR` -- this is the override mechanism
- `doc/ralph/` historical design documents -- archival content
- `.ai_out/` files -- AI artifacts

## Deviations From Plan

None. Plan was executed exactly as specified.

## Verification

- All 74 BDD scenarios pass (388 steps, 0 failures)
- Zero stale `.change_log` references found in functional code (grep verified with exclusions for `.ai_out/`, `.tmp/`, `doc/`, `.git/`)
- `_change_log/` directory exists at repo root

## Note for Parent Repo

The parent monorepo's CLAUDE.md contains `change_log help` output with the old `.change_log/` reference. After this submodule is bumped, the parent repo's CLAUDE.md should be regenerated.
