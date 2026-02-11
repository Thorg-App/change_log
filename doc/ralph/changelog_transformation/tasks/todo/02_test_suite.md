# Phase 02: Test Suite

## Objective
Rewrite the BDD test suite (behave) to cover all changelog commands, replacing the old ticket-centric tests.

## Prerequisites
- Phase 01 complete (the `change_log` script exists and works)

## Scope
### In Scope
- Remove all old feature files (`ticket_*.feature`, `id_resolution.feature`, `ticket_directory.feature`, `ticket_plugins.feature`)
- Create new feature files for changelog commands:
  - `changelog_creation.feature` - create with required/optional fields, validation, frontmatter correctness
  - `changelog_show.feature` - show entries, partial ID resolution
  - `changelog_edit.feature` - edit in $EDITOR
  - `changelog_listing.feature` - ls with most-recent-first, --limit
  - `changelog_query.feature` - JSONL output, jq filters, desc inclusion, ordering
  - `changelog_notes.feature` - add-note with timestamps
  - `changelog_directory.feature` - directory discovery, auto-create at git root, CHANGE_LOG_DIR env var
  - `id_resolution.feature` - partial ID matching (rewritten for changelog context)
- Rewrite `features/steps/ticket_steps.py` → `features/steps/changelog_steps.py`
  - Update helper functions for new directory (`./change_log/`), new script name, new frontmatter
  - Update `create_ticket()` → `create_entry()` helper
  - Update all Given/When/Then steps for changelog semantics
- Update `features/environment.py` if needed (temp directory setup)
- Ensure `make test` passes

### Out of Scope
- Repo file cleanup (Phase 03)
- Documentation updates (Phase 03)

## Implementation Guidance
- Follow existing BDD patterns: GIVEN/WHEN/THEN style with clear scenario names
- One assert per scenario where practical
- Key scenarios to cover per feature file:
  - **creation**: required fields (title + impact), all optional fields, field validation (impact range, type values), ap/note_id map handling, omission of empty optional maps, JSON output format, filename format verification
  - **show**: basic show, partial ID, ambiguous ID error
  - **edit**: opens editor (mock $EDITOR with a script that verifies the file)
  - **listing**: empty list, multiple entries ordering, --limit flag
  - **query**: JSONL format, all fields present, desc included, jq filter, ordering
  - **notes**: add note text, piped stdin, timestamp format
  - **directory**: parent walking, auto-create at git root, CHANGE_LOG_DIR override
  - **id_resolution**: exact match, prefix match, ambiguous match error
- Reuse the existing test infrastructure pattern (temp dirs per scenario, subprocess calls)

## Acceptance Criteria
- [ ] All old `ticket_*.feature` files are removed
- [ ] New feature files cover all changelog commands
- [ ] Step definitions updated for changelog semantics
- [ ] `make test` passes with all scenarios green
- [ ] Coverage includes: creation (happy + error paths), show, edit, ls (ordering + limit), query (JSONL + filter + ordering), add-note, directory discovery, ID resolution
- [ ] No references to "ticket" remain in test code (except potentially in file cleanup if old files still exist)

## Notes
- The step definitions file is ~850 lines; expect similar size for the rewrite
- Focus on behavioral coverage, not implementation details
- The `environment.py` setup/teardown likely needs minimal changes (just directory name)
