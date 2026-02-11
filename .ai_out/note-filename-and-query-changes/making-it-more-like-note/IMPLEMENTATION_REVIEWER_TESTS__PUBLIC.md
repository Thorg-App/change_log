# Test Changes Review (Phase 2)

## Summary

The test changes cleanly update all step definitions and feature files to match the new data model (title-based filenames, frontmatter title, JSON output from create, always-included full_path). All 120 scenarios pass. The 9 failures are identical to master (pre-existing plugin `/dev/shm` permission issue). Zero regressions introduced.

## Verdict: APPROVE with minor items

The issues found are minor and do not warrant an implementation iteration cycle. They can be addressed as follow-up.

---

## IMPORTANT Issues

### 1. DRY Violation: Duplicated JSON extraction logic

**File:** `/home/nickolaykondratyev/git_repos/note-ticket/features/steps/ticket_steps.py`
**Lines:** 382-394 and 772-784

The `step_run_command()` and `run_with_plugin_path()` functions contain identical 13-line blocks:

```python
# If this was a create command, track the created ticket ID from JSON output
if 'ticket create' in command and result.returncode == 0:
    created_id = extract_created_id(result.stdout)
    if created_id:
        context.last_created_id = created_id
        try:
            data = json.loads(result.stdout.strip())
            if 'full_path' in data:
                if not hasattr(context, 'tickets'):
                    context.tickets = {}
                context.tickets[created_id] = Path(data['full_path'])
        except (json.JSONDecodeError, KeyError):
            pass
```

**Fix:** Extract to a helper function like `_track_created_ticket(context, command, result)` and call from both locations.

---

## Suggestions

### 1. Inconsistent quote-stripping between field assertion steps

**File:** `/home/nickolaykondratyev/git_repos/note-ticket/features/steps/ticket_steps.py`

`step_created_ticket_has_field()` (line 517) strips surrounding quotes from field values for comparison. `step_ticket_has_field_value()` (line 546) does NOT. This means asserting `ticket "X" should have field "title" with value "Y"` would fail because the stored value is `"Y"` (with quotes). Currently no test exercises this path, but it is a latent inconsistency.

**Fix:** Apply the same quote-stripping logic in `step_ticket_has_field_value()` or, better, extract a shared comparison helper.

### 2. Python `title_to_slug()` missing 200-char truncation

The bash `title_to_filename()` truncates slugs to 200 characters (line 98 of `ticket`). The Python mirror `title_to_slug()` (line 30 of `ticket_steps.py`) does not. For test purposes this will never matter (test titles are short), but it is a fidelity gap.

---

## POSITIVE

1. **Complete migration** -- zero remaining `f'{ticket_id}.md'` patterns in the entire `features/` directory. Verified via grep.
2. **find_ticket_file() helper** is well designed: checks the `context.tickets` dict first (fast path), then falls back to scanning frontmatter (robust path). The regex uses `re.escape()` properly.
3. **extract_created_id() fallback** gracefully handles non-JSON output (returns raw string), preventing brittle failures if a non-create command accidentally triggers the check.
4. **New scenarios are well-structured BDD** -- the "Duplicate title creates suffixed filename" scenario in particular is a good regression test for the collision-handling logic.
5. **Feature files unchanged that should be unchanged** -- `id_resolution.feature`, `ticket_status.feature`, `ticket_dependencies.feature`, `ticket_links.feature`, `ticket_notes.feature`, and `ticket_listing.feature` all correctly work without changes because the step definitions handle the new data model transparently.
6. **No use cases removed** -- the 3 removed `--include-full-path` scenarios are replaced by equivalent "always includes full_path" coverage. The `dep cycle` feature was never covered and was not removed.
7. **environment.py** properly initializes `context.tickets = {}` in `before_scenario`, preventing state leakage between tests.

## Coverage Check

| New Behavior | Covered? | Location |
|---|---|---|
| Title-based filenames | YES | `ticket_creation.feature:100` |
| Duplicate filename handling | YES | `ticket_creation.feature:105` |
| Title in frontmatter | YES | `ticket_creation.feature:121` |
| Create outputs JSON | YES | `ticket_creation.feature:112` |
| Query always includes full_path | YES | `ticket_query.feature:50` |
| Query includes title field | YES | `ticket_query.feature:57` |

## Recommendation

**IMPLEMENTATION_ITERATION can be skipped.** The DRY violation and quote-stripping inconsistency are real but minor, and all tests pass. These can be addressed as follow-up commits without blocking the current PR.
