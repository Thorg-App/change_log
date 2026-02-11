# IMPLEMENTOR_TESTS Public Summary

## Status: Phases 8-9 COMPLETE

All test infrastructure and feature files updated. 120 passing scenarios, 9 pre-existing plugin failures (environment `noexec` issue).

## Changes Summary

### `ticket_steps.py` (step definitions)

| Change | Detail |
|---|---|
| `title_to_slug()` helper | NEW: Mirrors bash `title_to_filename()` for test file creation |
| `create_ticket()` helper | Writes title-based filename (`slug.md`), `title: "..."` in frontmatter, no `# heading` in body, handles filename collisions |
| `find_ticket_file()` helper | NEW: Resolves ticket_id to file path via `context.tickets` dict, falls back to scanning frontmatter |
| `extract_created_id()` helper | NEW: Parses JSON output from create command to get `id` field |
| `step_run_command()` | Extracts `last_created_id` from JSON output; stores `full_path` in `context.tickets` |
| `run_with_plugin_path()` | Same JSON extraction logic as `step_run_command()` |
| `step_output_matches_id_pattern()` | Validates JSON output with `id` field (was: regex for `prefix-hash` pattern) |
| `step_ticket_file_exists_with_title()` | Checks frontmatter `title:` field (was: body `# heading`) |
| `step_created_ticket_has_field()` | Strips surrounding quotes from values for comparison |
| `step_separate_tickets_dir()` | Uses title-based filename and frontmatter title |
| `step_output_valid_json_with_id()` | NEW step: validates JSON output has `id` field |
| `step_every_jsonl_line_has_field()` | NEW step: validates every JSONL line has a field |
| `step_file_named_exists_in_tickets()` | NEW step: checks for specific filename in `.tickets/` |
| 11 step defs using `f'{ticket_id}.md'` | All replaced with `find_ticket_file(context, ticket_id)` |

### Feature Files Updated (7 files)

| File | Changes |
|---|---|
| `ticket_creation.feature` | "match a ticket ID pattern" -> "valid JSON with an id field"; added 4 new scenarios (title-based filename, duplicate handling, JSON output, frontmatter title) |
| `ticket_query.feature` | Removed 3 `--include-full-path` scenarios; added 2 new scenarios (always includes full_path, includes title) |
| `ticket_show.feature` | `# Test ticket` -> `title:` + `Test ticket` checks; `# Parent ticket` -> `Parent ticket` |
| `ticket_edit.feature` | `edit-0001.md` -> `editable-ticket.md` (title-based filename) |
| `ticket_directory.feature` | "match a ticket ID pattern" -> "valid JSON with an id field" |
| `ticket_plugins.feature` | 3x "match a ticket ID pattern" -> "valid JSON with an id field" |
| 5 other feature files | No changes needed (assertions compatible with new data model) |

### Feature Files NOT Modified (5 files)

- `id_resolution.feature` - Works as-is with frontmatter-based `ticket_path()`
- `ticket_status.feature` - Output messages unchanged (IDs from frontmatter)
- `ticket_dependencies.feature` - IDs and deps work the same
- `ticket_links.feature` - Same
- `ticket_notes.feature` - Same
- `ticket_listing.feature` - Same

### New Scenarios Added: 6

1. **Title-based filename generation** - Verifies `my-test-ticket.md` filename
2. **Duplicate title creates suffixed filename** - Verifies `-1` suffix
3. **Create outputs JSON with expected fields** - Verifies JSON structure
4. **Title is stored in frontmatter** - Verifies `title:` field
5. **Query always includes full_path** - Verifies every line has `full_path`
6. **Query includes title field** - Verifies title in JSONL output

### Scenario Count Change

- Removed: 3 scenarios (`--include-full-path` related)
- Added: 6 new scenarios
- Net: +3 scenarios (from 126 to 129 total)

## Test Results

| Metric | Baseline (before changes) | After changes |
|---|---|---|
| Passing scenarios | 87 | 120 |
| Failing scenarios | 25 | 9 (all pre-existing plugin env issues) |
| Error scenarios | 14 | 0 |
| Net improvement | -- | +33 scenarios fixed, 0 regressions |

The 9 remaining failures are all pre-existing `Permission denied` errors from `/dev/shm/` `noexec` mount restriction on the test machine. These affect plugin execution tests only and are not caused by any code changes.
