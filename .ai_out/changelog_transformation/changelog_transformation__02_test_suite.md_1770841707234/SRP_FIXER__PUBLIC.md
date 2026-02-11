# SRP Analysis: Phase 02 BDD Test Suite

## Result

1 scattered responsibility violation found and fixed. 1 dead defensive code item removed. All 76 scenarios pass after changes.

## Violation Found and Fixed

### FIX-01: "Parse create command JSON output" scattered across `extract_created_id` and `_track_created_entry`

**Type**: Scattered responsibility (same concern split across two functions).

**The responsibility**: "How to parse the JSON output of a `change_log create` command and extract tracking data (id, full_path)."

This responsibility was split between two functions:
- `extract_created_id(stdout)` -- parsed JSON once via `json.loads()` to extract the `id` field
- `_track_created_entry()` -- called `extract_created_id()` to get `id`, then called `json.loads()` a second time on the same string to extract `full_path`

The scattered parsing meant two `json.loads()` calls on identical input. More importantly, the knowledge of "what fields exist in create command output" was split: `extract_created_id` knew about `id`, while `_track_created_entry` knew about `full_path`. If the output format changes, both would need to change.

`extract_created_id` had no callers other than `_track_created_entry`, so it was not a shared utility -- it was just a fragment of the same responsibility.

**Fix**: Consolidated into a single `_track_created_entry()` that parses JSON once and extracts both `id` and `full_path` from the same parsed object. Removed `extract_created_id()` entirely.

**Dead code removed**: The `hasattr(context, 'tickets')` guard (old line 119) was dead defensive code. `context.tickets` is always initialized as `{}` in `before_scenario()` (`environment.py` line 20). Removed the guard; direct dictionary access is correct.

**Lines removed**: ~10

## Items Analyzed but NOT Violations

### Feature files -- each tests exactly one concern

| Feature File | Concern | Scenarios | Verdict |
|---|---|---|---|
| `changelog_creation.feature` | `create` command and all its flags/validation | 26 | Clean |
| `changelog_listing.feature` | `ls`/`list` command output and formatting | 7 | Clean |
| `changelog_show.feature` | `show` command display | 5 | Clean |
| `changelog_edit.feature` | `edit` command behavior | 3 | Clean |
| `changelog_notes.feature` | `add-note` command | 8 | Clean |
| `changelog_query.feature` | `query` command JSONL output | 9 | Clean |
| `changelog_directory.feature` | Directory resolution and CLI-level error handling | 10 | Acceptable (see note) |
| `id_resolution.feature` | Partial/exact ID matching | 8 | Clean |

**Note on `changelog_directory.feature`**: The "Unknown command shows helpful error" scenario (line 64) tests generic command dispatch, not directory resolution. Strictly, this is a different axis of change. However, creating a separate feature file for a single scenario would be over-engineering (violates 80/20). The scenario is at home among the other "CLI infrastructure" tests in this file. Flagged but not moved.

### Helper function structure in `changelog_steps.py` -- NOT a violation

The helpers serve two conceptual groups:
1. **Test data setup**: `create_entry()`, `find_entry_file()`
2. **Command execution infrastructure**: `get_script()`, `_run_command()`, `_track_created_entry()`, `_parse_jsonl()`

In a larger codebase, these would warrant separate modules. In a 470-line file with clear section comments, the navigational cost of splitting outweighs the benefit. Each helper has a single, focused purpose and the groups are visually separated. Not a violation at this scale.

### Step definitions organized by Given/When/Then -- NOT a violation

All step definitions are thin wrappers delegating to helpers. The Given/When/Then organization follows behave conventions and groups steps by their role in the test lifecycle. Within each section, steps are ordered from specific to generic (important for behave's regex matching). This is correct and cohesive.

### `environment.py` -- NOT a violation

`before_scenario` handles test isolation (temp dir, state reset). `after_scenario` handles cleanup. `before_all` resolves project directory. Each hook has one reason to change. The empty `before_feature`/`after_feature` hooks are documented extension points. No violation.

### `_run_command` doing command execution AND result tracking -- NOT a violation

`_run_command` stores results on context AND calls `_track_created_entry`. One might argue these are separate concerns. However, they change together: if how we execute commands changes (e.g., adding timeout), the result storage must change with it. The tracking call is a lightweight hook that keeps step definitions clean. This is a single cohesive responsibility: "execute a CLI command in the test harness and capture all results."

## Test Results After Fix

```
8 features passed, 0 failed, 0 skipped
76 scenarios passed, 0 failed, 0 skipped
394 steps passed, 0 failed, 0 skipped
Took 0min 0.768s
```

## Files Modified

- `features/steps/changelog_steps.py` -- 1 SRP fix applied, 1 dead code item removed (~10 lines net reduction)
