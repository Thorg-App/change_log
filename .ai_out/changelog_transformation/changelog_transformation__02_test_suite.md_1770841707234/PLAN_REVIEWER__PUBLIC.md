# Plan Review: Phase 02 -- BDD Test Suite Rewrite

## Executive Summary

The plan is well-structured, thorough, and follows the 80/20 principle correctly by cutting from 131 to ~67 scenarios while maintaining full behavioral coverage of the `change_log` script. The DRY consolidation of subprocess execution into `_run_command()` is a meaningful improvement. Two minor gaps exist: missing scenarios for behaviors explicitly listed in the high-level design (unknown command error, auto-create at git root, `--author` flag). These are easily fixable inline.

## Critical Issues (BLOCKERS)

None.

## Major Concerns

None. The plan is sound.

## Minor Issues

### MINOR-01: Missing "Unknown Command" error scenario

**What**: The high-level design explicitly lists a behavior:
> **Error: Unknown Command** -- WHEN `change_log foo` -- THEN a helpful error is shown suggesting `change_log help`

The plan has no scenario for this. The script (line 544) outputs `"Unknown command: $1"` and `"Run 'change_log help' for usage information"` to stderr.

**Suggested fix**: Add to `changelog_directory.feature` (or create a small `changelog_help.feature`):

```gherkin
Scenario: Unknown command shows helpful error
  When I run "change_log foo"
  Then the command should fail
  And the output should contain "Unknown command: foo"
```

This fits best as scenario 9 in Phase 9 (`changelog_directory.feature`), since that file already tests help and error conditions.

---

### MINOR-02: Missing "Create auto-creates directory at git root" scenario

**What**: The high-level design lists:
> **Behavior: Create Auto-Creates Directory** -- GIVEN no `./change_log/` directory exists in any parent AND the current directory is inside a git repository -- WHEN `change_log create "First entry" --impact 1` -- THEN `./change_log/` is created at the git repo root

The plan's `changelog_directory.feature` tests directory *discovery* and *error when missing*, but not *auto-creation via create*.

**Why it matters**: This is an explicitly listed success criterion in the high-level design.

**Suggested fix**: Add a scenario to Phase 9:

```gherkin
Scenario: Create auto-creates changelog directory at git root
  Given the changelog directory does not exist
  # This scenario requires git init in test_dir to trigger auto-create
  When I run "git init" from the test directory
  And I run "change_log create 'First entry' --impact 1"
  Then the command should succeed
  And the changelog directory should exist
```

**Caveat**: This requires a `git init` in the test temp dir, which the exploration report flagged as a risk area (section E, risk #5). The implementor must add a Given step like `the test directory is a git repository` that runs `git init` in `context.test_dir`. This is a small addition but important for correctness.

---

### MINOR-03: `--author` scenario mentioned in Open Questions but not in scenario table

**What**: The plan's Open Question #2 recommends: "Add one scenario `Create with --author` that passes `-a 'Test Author'` and verifies the field." But the Phase 3 scenario table (24 scenarios) does not include this scenario.

**Suggested fix**: Add as scenario 25 in Phase 3:

```
| 25 | Create with --author flag | succeed, field "author" has value "Test Author" |
```

Gherkin:
```gherkin
Scenario: Create with --author flag
  When I run "change_log create 'Test' --impact 3 -a 'Test Author'"
  Then the command should succeed
  And the created entry should have field "author" with value "Test Author"
```

---

### MINOR-04: Impact error message assertion is slightly imprecise

**What**: Plan scenario 4 (Phase 3) says: `stderr contains "Error: --impact must be 1-5"`. The actual script outputs: `"Error: --impact must be 1-5, got '0'"` (line 305 of `change_log`). The `output should contain` step does substring matching, so this WILL work. However, scenario 6 (non-numeric impact) asserts the same message, and the actual output will be `"Error: --impact must be 1-5, got 'high'"`. Still works via substring match.

**Assessment**: No fix needed. The substring matching approach is intentionally loose, which is correct for BDD tests that should not be brittle to message formatting changes. Noted for the implementor's awareness.

---

### MINOR-05: `--note-id` validation scenario missing

**What**: The plan tests `--ap rejects missing equals sign` (scenario 19) but does not have an analogous scenario for `--note-id badformat`. The script validates both identically (line 288).

**Suggested fix**: Add as scenario 26 in Phase 3:

```
| 26 | --note-id rejects missing equals sign | fail, stderr contains "Error: --note-id requires key=value format" |
```

---

### MINOR-06: Plan scenario count says "21 total" but lists 24 scenarios

**What**: Phase 3 header says "(21 total)" but the table lists scenarios numbered 1-24. This is a documentation inconsistency.

**Suggested fix**: Change "(21 total)" to "(24 total)" or, with the additions from MINOR-03 and MINOR-05, "(26 total)".

## Simplification Opportunities (PARETO)

None identified. The plan already demonstrates good 80/20 thinking by:
- Cutting from 131 to ~67 scenarios
- Consolidating 4 subprocess execution patterns into 1 `_run_command()` helper
- Explicitly excluding known pre-existing quirks from testing

## Strengths

1. **DRY consolidation of `_run_command()`**: The old code had 4 near-identical subprocess invocations. Consolidating to one helper with optional `env_override` is clean and maintainable.

2. **Deterministic fixture filenames**: Using `2024-01-01_00-00-{NN}Z.md` with a counter is an elegant solution to the "tests need deterministic ordering without real clocks" problem.

3. **Phased implementation with incremental validation**: Each phase produces a testable artifact. This is good engineering practice.

4. **Correct handling of `ap`/`note_id` as YAML maps**: The plan correctly identifies these as map fields and includes scenarios for both presence and omission. The `create_entry()` helper's minimal frontmatter (without `ap`/`note_id`) is correct since fixtures typically do not need these fields.

5. **Regex step matcher ordering awareness**: The plan explicitly notes that more specific step patterns must be defined before generic ones. This avoids a common behave pitfall.

6. **Explicit out-of-scope documentation**: Pre-existing quirks (double-escaping, unbound variable) are explicitly listed as not tested, with rationale.

7. **Correct error message verification**: Plan scenarios use `output should contain` (substring match) rather than exact match, which is resilient to minor message changes.

## Coverage Cross-Check: High-Level Design Behaviors vs Plan

| High-Level Behavior | Plan Coverage | Status |
|---|---|---|
| Create Entry | Phase 3, scenarios 1-2 | COVERED |
| Create Entry with All Options | Phase 3, scenarios 13-20 | COVERED |
| Create Auto-Creates Directory | Not in plan | GAP (MINOR-02) |
| Impact Required | Phase 3, scenario 3 | COVERED |
| List Entries | Phase 4, scenarios 1-3, 6 | COVERED |
| List with Limit | Phase 4, scenario 5 | COVERED |
| Show Entry | Phase 5, scenarios 1, 4 | COVERED |
| Edit Entry | Phase 6, scenario 1 | COVERED |
| Query as JSONL | Phase 8, scenarios 1, 3 | COVERED |
| Query with jq Filter | Phase 8, scenario 2 | COVERED |
| Add Note | Phase 7, scenarios 1-3 | COVERED |
| Help | Phase 9, scenario 6 | COVERED |
| Error: Invalid Impact | Phase 3, scenarios 4-6 | COVERED |
| Error: Unknown Command | Not in plan | GAP (MINOR-01) |
| `desc` in query output | Phase 8, scenario 8 | COVERED |

## Verdict

- [x] APPROVED WITH MINOR REVISIONS

The plan is ready for implementation. The six minor issues identified above are all additive (adding missing scenarios) and do not require restructuring. The implementor should:

1. Add the "Unknown command" scenario (MINOR-01) -- 1 scenario
2. Add the "Auto-create at git root" scenario (MINOR-02) -- 1 scenario, plus a new Given step
3. Add the `--author` scenario (MINOR-03) -- 1 scenario
4. Add the `--note-id` validation scenario (MINOR-05) -- 1 scenario
5. Fix the scenario count in the Phase 3 header (MINOR-06)

These additions bring the total to approximately 71 scenarios, which remains well within the 80/20 target.

**Recommendation**: These are small enough that PLAN_ITERATION can be skipped. The implementor can incorporate these 4 additional scenarios during implementation. The fixes are documented clearly above.
