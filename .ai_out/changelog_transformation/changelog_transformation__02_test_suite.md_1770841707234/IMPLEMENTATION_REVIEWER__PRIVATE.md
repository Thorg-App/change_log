# Implementation Review Private Context

## Review Session Notes

### Tests Run
- `make test` passes: 8 features, 74 scenarios, 382 steps, 0 failures
- No `sanity_check.sh` present

### Coverage Cross-Reference (High-Level Design Behaviors)

| Behavior | Covered? | Feature File | Notes |
|----------|----------|--------------|-------|
| Create Entry | Yes | changelog_creation.feature | Basic + all options |
| Create Entry with All Options | Yes | changelog_creation.feature | desc, tags, dirs, ap, note_id all tested |
| Create Auto-Creates Directory | Yes | changelog_directory.feature | Scenario: "Create auto-creates changelog directory at git root" |
| Impact Required | Yes | changelog_creation.feature | "Create fails without --impact" |
| List Entries | Yes | changelog_listing.feature | Multiple scenarios |
| List with Limit | Yes | changelog_listing.feature | "--limit" scenario |
| Show Entry | Yes | changelog_show.feature | Full + partial ID |
| Edit Entry | Yes | changelog_edit.feature | non-TTY mode tested |
| Query as JSONL | Yes | changelog_query.feature | Multiple scenarios |
| Query with jq Filter | Yes | changelog_query.feature | "Query with jq filter by type" |
| Add Note | Yes | changelog_notes.feature | text, timestamp, multiple, partial ID |
| Help | Yes | changelog_directory.feature | "Help command works without changelog directory" |
| Error: Invalid Impact Value | Yes | changelog_creation.feature | Impact 0, 6, non-numeric |
| Error: Unknown Command | Yes | changelog_directory.feature | "Unknown command shows helpful error" |

### Gap: Query Ordering Not Tested
The high-level design says query outputs "most-recent-first" but there is no scenario verifying query output ordering. The listing feature has an ordering test but query does not.

### Gap: Piped stdin for add-note Not Tested
The `step_pipe_to_command` step is defined but unused. The exploration report identified piped stdin as a scenario. The old test suite had piped note scenarios.

### Issue: Duplicate Assertion in List All Entries
Lines 14-15 of `changelog_listing.feature` both assert `"list-000"`, which is identical. This doesn't verify both entries actually appear.

### DRY Analysis of Step Definitions
- `_run_command()` consolidates subprocess execution -- good.
- `step_pipe_to_command` duplicates most of `_run_command` -- could be refactored. But since it's unused, this is moot.
- `step_output_valid_json_with_id` and `step_output_matches_entry_id_pattern` are very similar. The second is only slightly more specific (checks non-empty string). Both are used in different scenarios so this is acceptable.

### context.tickets Variable Name
Kept as `context.tickets` per the plan. Only appears in Python, not feature files.
