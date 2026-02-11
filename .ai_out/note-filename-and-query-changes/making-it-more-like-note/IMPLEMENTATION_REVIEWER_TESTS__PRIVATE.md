# IMPLEMENTATION_REVIEWER_TESTS - Private Notes

## Review Methodology

1. Read all 12 feature files (both changed and unchanged)
2. Read full `ticket_steps.py` diff and final state
3. Read `environment.py`
4. Compared Python `title_to_slug()` against bash `title_to_filename()` line-by-line
5. Ran `make test` on branch: 120 pass, 9 fail (plugin env)
6. Ran `make test` on master: identical 120 pass, 9 fail -- confirming zero regressions
7. Searched for any remaining `{ticket_id}.md` patterns -- none found
8. Verified all 11 step definitions that accessed files by ID were updated to `find_ticket_file()`
9. Checked DRY compliance on duplicated code blocks

## Detailed Findings

### DRY Violation: Duplicated JSON extraction (lines 382-394 and 772-784)
The `step_run_command()` and `run_with_plugin_path()` functions contain identical 13-line blocks for parsing JSON output from create commands and storing ticket IDs/paths. This should be extracted to a shared helper function like `_track_created_ticket(context, command, result)`.

### Inconsistency: Quote stripping in field comparison
- `step_created_ticket_has_field()` (line 517) strips quotes from values for comparison
- `step_ticket_has_field_value()` (line 546) does NOT strip quotes
- Currently no tests exercise `step_ticket_has_field_value` with a `title` field so this doesn't cause failures, but it's an inconsistency. If someone writes `ticket "X" should have field "title" with value "Y"` it would fail because the stored value is `"Y"` (with quotes).

### Minor: title_to_slug missing 200-char truncation
The bash `title_to_filename()` truncates to 200 chars. The Python `title_to_slug()` does not. This is unlikely to matter for tests (test titles are short), but is a fidelity gap between the test helper and the actual implementation.

### Coverage Assessment
All 6 new behaviors from the plan are covered:
1. Title-based filenames: YES (ticket_creation.feature line 100)
2. Duplicate handling: YES (ticket_creation.feature line 105)
3. Frontmatter title: YES (ticket_creation.feature line 121)
4. JSON output from create: YES (ticket_creation.feature line 112)
5. Always full_path in query: YES (ticket_query.feature line 50)
6. Title in query: YES (ticket_query.feature line 57)

### Old patterns fully removed
- All `f'{ticket_id}.md'` references replaced with `find_ticket_file()`
- `# {title}` body heading replaced with `title:` frontmatter in `create_ticket()` and `step_separate_tickets_dir()`
- `--include-full-path` scenarios removed (3 removed, 2 new added -- net -1 query scenarios)
- All `"output should match a ticket ID pattern"` updated to `"output should be valid JSON with an id field"`

### Scenarios removed vs added
Removed: 3 scenarios (--include-full-path related in ticket_query.feature)
Added: 6 new scenarios (4 in creation, 2 in query)
Net: +3

This is acceptable. The removed scenarios tested a flag that no longer exists. The added scenarios test the new behaviors.

## Verdict
The DRY violation is the only IMPORTANT issue. The quote-stripping inconsistency is a latent bug but doesn't currently manifest. Both are straightforward fixes. IMPLEMENTATION_ITERATION can be skipped if the team accepts these as follow-up items.
