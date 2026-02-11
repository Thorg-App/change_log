# Phase 03: Repo Cleanup and Documentation

## Objective
Remove all dead files from the repository (old ticket script, plugin infrastructure, packaging, CI) and update all documentation to reflect the changelog system.

## Prerequisites
- Phase 01 complete (change_log script works)
- Phase 02 complete (tests pass)

## Scope
### In Scope
- Delete old files:
  - `ticket` (old script)
  - `.tickets/` directory and contents
  - `plugins/` directory and contents
  - `pkg/` directory and contents (extras.txt, aur/)
  - `scripts/` directory and contents (publish-*.sh)
  - `.github/` directory and contents (workflows)
  - `features/steps/ticket_steps.py` (if not already removed in Phase 02)
  - Any remaining old feature files
  - `ask.dnc.md`, `formatted_request.dnc.md` (stale AI interaction files)
  - `test.sh` (if superseded by Makefile)
- Update `README.md`:
  - New name, description, install instructions
  - Updated command reference matching `change_log help` output
  - Remove plugin section (or simplify dramatically)
  - Remove packaging references (Homebrew, AUR)
  - Update agent setup section
- Update `CLAUDE.md`:
  - Reflect new architecture: `change_log` script, `./change_log/` directory
  - Update key functions list
  - Update data model description
  - Remove plugin, packaging, release sections
  - Update testing section if needed
- Update `CHANGELOG.md`:
  - Add entry under `[Unreleased]` documenting the transformation
- Update `Makefile` if needed (test target should still work)

### Out of Scope
- Further feature development
- Re-adding CI/CD (can be done later if needed)

## Implementation Guidance
- Delete files first, then update docs
- For README.md: rewrite the usage section to match `change_log help` output exactly
- For CLAUDE.md: focus on what an AI agent needs to know to work with this codebase
- Keep CHANGELOG.md entry concise but comprehensive (this is a major breaking change)
- Run `make test` after cleanup to ensure nothing broke

## Acceptance Criteria
- [ ] No `ticket`-named files remain (except in git history)
- [ ] No `plugins/`, `pkg/`, `scripts/`, `.github/` directories exist
- [ ] README.md accurately describes the `change_log` CLI
- [ ] CLAUDE.md reflects the current architecture
- [ ] CHANGELOG.md documents the transformation
- [ ] `make test` still passes after cleanup
- [ ] No stale references to "ticket" in documentation

## Notes
- Be careful not to delete `doc/ralph/` - that's the spec, not dead code
- The `.idea/` directory is IDE config, leave it alone
- `LICENSE` file stays as-is
