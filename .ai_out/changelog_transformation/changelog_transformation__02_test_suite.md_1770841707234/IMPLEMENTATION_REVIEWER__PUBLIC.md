# Phase 02: BDD Test Suite -- Implementation Review

## VERDICT: PASS_WITH_MINOR_FIXES

All 74 scenarios pass. Behavioral coverage is thorough. The issues below are minor and none block the phase.

---

## Summary

The test suite was fully rewritten from the old `ticket`-centric BDD tests (131 scenarios across 12 feature files) to 74 changelog-focused scenarios across 8 feature files. All old `ticket_*.feature` files and `ticket_steps.py` are deleted. No "ticket" references remain in feature files. The step definitions are DRY (consolidated `_run_command()` helper), the `create_entry()` fixture helper correctly produces `change_log` frontmatter, and assertions correctly match the actual script output.

**Test results:** 8 features passed, 74 scenarios passed, 382 steps passed, 0 failures.

---

## SHOULD_FIX Issues

### SHOULD_FIX-01: "List all entries" has duplicate identical assertions

**File:** `/home/nickolaykondratyev/git_repos/Thorg-App_change_log/features/changelog_listing.feature`, lines 14-15

```gherkin
  Scenario: List all entries
    Given a changelog entry exists with ID "list-0001" and title "First entry"
    And a changelog entry exists with ID "list-0002" and title "Second entry"
    When I run "change_log ls"
    Then the command should succeed
    And the output should contain "list-000"
    And the output should contain "list-000"
```

Both `Then` lines assert the exact same string `"list-000"`. The second assertion is a no-op. This does not verify that **both** entries appear in the output. One entry appearing would pass this test.

**Suggested fix:**
```gherkin
    And the output should contain "First entry"
    And the output should contain "Second entry"
```

### SHOULD_FIX-02: Missing query ordering test

**File:** `/home/nickolaykondratyev/git_repos/Thorg-App_change_log/features/changelog_query.feature`

The high-level design specifies: "WHEN `change_log query` THEN JSONL is output with all fields including `desc`, **most-recent-first**." The listing feature has an ordering scenario but the query feature does not. Since query is a separate code path (`cmd_query` vs `cmd_ls`), the ordering behavior should be verified independently.

**Suggested fix:** Add a scenario:
```gherkin
  Scenario: Query outputs most recent first
    Given a changelog entry exists with ID "order-aaa" and title "Older entry"
    And a changelog entry exists with ID "order-bbb" and title "Newer entry"
    When I run "change_log query"
    Then the command should succeed
    And the output line 1 should contain "order-bbb"
    And the output line 2 should contain "order-aaa"
```

### SHOULD_FIX-03: Missing piped stdin test for add-note

**File:** `/home/nickolaykondratyev/git_repos/Thorg-App_change_log/features/changelog_notes.feature`

The `change_log` script supports piped stdin for `add-note` (`elif [[ ! -t 0 ]]; then note=$(cat)` at line 424 of `change_log`). The step definition `step_pipe_to_command` is defined in `/home/nickolaykondratyev/git_repos/Thorg-App_change_log/features/steps/changelog_steps.py` (line 271) but no feature file uses it. The old test suite included piped note scenarios and the exploration report identified this as a scenario to cover.

**Suggested fix:** Add a scenario:
```gherkin
  Scenario: Add note via piped stdin
    When I pipe "Piped note content" to "change_log add-note note-0001"
    Then the command should succeed
    And entry "note-0001" should contain "Piped note content"
```

---

## NIT Issues

### NIT-01: `step_pipe_to_command` duplicates `_run_command` logic

**File:** `/home/nickolaykondratyev/git_repos/Thorg-App_change_log/features/steps/changelog_steps.py`, lines 271-295

The `step_pipe_to_command` function duplicates the subprocess execution pattern from `_run_command`. It could delegate to a shared internal helper that accepts an optional `input_text` parameter. However, since this step is currently unused, this is low priority; if SHOULD_FIX-03 is addressed by adding the piped stdin scenario, this would become worth refactoring.

### NIT-02: Grammar in step text "a entry" should be "an entry"

**File:** `/home/nickolaykondratyev/git_repos/Thorg-App_change_log/features/changelog_creation.feature`, lines 13, 19

```gherkin
    And a entry file should exist with title "My first entry"
```

Should be "**an** entry file should exist". This appears in both the feature file step text and the step definition regex at `/home/nickolaykondratyev/git_repos/Thorg-App_change_log/features/steps/changelog_steps.py` line 451.

---

## Acceptance Criteria Checklist

| Criterion | Status | Evidence |
|-----------|--------|----------|
| All old `ticket_*.feature` files are removed | PASS | Glob for `features/ticket_*.feature` returns no files |
| New feature files cover all changelog commands | PASS | create, ls, show, edit, add-note, query, help, directory discovery all have scenarios |
| Step definitions updated for changelog semantics | PASS | `changelog_steps.py` uses `change_log` command, `CHANGE_LOG_DIR`, `change_log/` directory |
| `make test` passes with all scenarios green | PASS | 74 passed, 0 failed, 0 skipped |
| Coverage: creation (happy + error paths) | PASS | 26 scenarios in `changelog_creation.feature` |
| Coverage: show | PASS | 5 scenarios |
| Coverage: edit | PASS | 3 scenarios |
| Coverage: ls (ordering + limit) | PASS | ordering + limit + format + empty list |
| Coverage: query (JSONL + filter + ordering) | PARTIAL | JSONL format and jq filter tested; ordering not tested (SHOULD_FIX-02) |
| Coverage: add-note | PARTIAL | Text, timestamp, multiple notes, partial ID tested; piped stdin not tested (SHOULD_FIX-03) |
| Coverage: directory discovery | PASS | parent walking, grandparent, env var override, auto-create at git root, error cases |
| Coverage: ID resolution | PASS | exact, prefix, suffix, substring, ambiguous, not found, exact precedence |
| No references to "ticket" remain in test code | PASS | Feature files: zero matches. Python: only internal variable name `context.tickets` (per plan) |
