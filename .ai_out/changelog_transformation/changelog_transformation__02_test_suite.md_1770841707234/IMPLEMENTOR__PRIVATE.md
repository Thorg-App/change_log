# IMPLEMENTOR Private Context -- Phase 02

## Completion State
All 11 phases complete + SHOULD_FIX iteration. 76 scenarios pass. No blockers.

## Key Implementation Notes

### Step Definition Architecture
- `changelog_steps.py` uses regex matcher (same as old `ticket_steps.py`)
- More specific When steps defined BEFORE generic `I run "X"` to avoid regex precedence issues
- `_run_command()` is the single entry point for all subprocess execution
- `_track_created_entry()` automatically tracks create command output for later assertions

### Fixture Design
- `create_entry()` creates files at `<test_dir>/change_log/2024-01-01_00-00-{NN}Z.md`
- Counter is `len(context.tickets)` -- increments per-scenario as entries are created
- Frontmatter includes only: id, title, created_iso, type, impact (minimal viable fixture)

### Environment Variables
- `CHANGE_LOG_DIR` is resolved relative to `context.test_dir` in the env override step
- `CHANGE_LOG_SCRIPT` env var can override the script path (for CI flexibility)

### Error Message Matching
All error assertions use substring matching (`output should contain`) to be resilient to minor message formatting changes. Verified all error messages against the actual script source.

### Known Pre-existing Issues Not Tested
- `json_escape()` double-escaping (inherited from original script)
- `$2: unbound variable` for missing flag arguments (inherited from `set -u`)

### Test Timing
Full suite runs in ~0.9 seconds. No sleep-dependent tests.

### SHOULD_FIX Iteration (Round 2)
- SHOULD_FIX-01: Fixed duplicate `"list-000"` assertion in listing "List all entries" scenario. Now asserts `"First entry"` and `"Second entry"` to verify both entries appear.
- SHOULD_FIX-02: Added "Query outputs most recent first" scenario to `changelog_query.feature`. Uses `output line N should contain` step to verify ordering.
- SHOULD_FIX-03: Added "Add note via piped stdin" scenario to `changelog_notes.feature`. Uses existing `step_pipe_to_command` step definition. No step definition changes needed.
- No changes to `changelog_steps.py` were required -- all needed steps already existed.
