# Implementation Review: Strip Partial ID Matching + Add `--details_in_md` Flag

## Summary

Two well-scoped changes across 2 commits:

1. **Commit `e25d53f`**: Stripped partial ID matching from `entry_path()` -- simplified to exact-match-only awk. Removed 6 partial ID test scenarios from 4 feature files. Added 1 new negative test (substring does NOT match). Updated help text and documentation.

2. **Commit `08a467c`**: Added `--details_in_md TEXT` flag to `cmd_create()`. Details written after frontmatter closing `---`. Added 3 new test scenarios. Updated help text, README, CHANGELOG, and CLAUDE.md.

**All 71 test scenarios pass** (8 features, 367 steps, 0 failures).

The implementation is clean, well-tested, and follows the approved plan closely. One important edge case was found during review.

---

## CRITICAL Issues

None.

## IMPORTANT Issues

### 1. `_file_to_jsonl()` leaks body content into JSONL when details contain `---` lines

**Severity**: IMPORTANT (not critical because it is an edge case, but it violates the documented contract)

**Location**: `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/change_log` lines 141-253 (`_file_to_jsonl()`)

**Problem**: The awk in `_file_to_jsonl()` uses `in_front = !in_front` to toggle between frontmatter and body mode when it encounters `---`. If the details body contains a line that is exactly `---` (a common markdown horizontal rule), the awk re-enters "frontmatter" mode. Any subsequent lines matching `key: value` patterns will be parsed as frontmatter fields and included in the JSONL output.

**Reproduction**:
```bash
change_log create 'Test' --impact 3 --details_in_md $'Some text\n---\nfake_field: leaked_value\n---\nMore text'
change_log query  # Output includes "fake_field":"leaked_value"
```

**Impact**: This violates the documented invariant that details are "NOT in query output." The plan reviewer's analysis (that "additional `---` lines in the body would toggle the flag but no field patterns would match") was incorrect.

**Recommended fix**: This is a **pre-existing architectural limitation** of the awk parser, NOT introduced by this PR. However, this PR introduces the feature (`--details_in_md`) that makes this path practically reachable. Two options:

- (a) **In `_file_to_jsonl()` awk**: Track `---` count and only consider the FIRST pair of `---` as frontmatter delimiters (i.e., set `in_front = 0` permanently after the second `---`). This is the correct fix.
- (b) **Accept as known limitation** and document it: "details body should not contain a line that is exactly `---`." This is the PARETO approach.

**Recommendation**: Given the 80/20 principle and the fact that this is a tool for AI agents (not end users), option (b) is acceptable for this PR. However, a follow-up ticket should be created to fix the awk parser (option a) since it is a one-line change (replace `in_front = !in_front` with a counter that stops after 2).

#QUESTION_FOR_HUMAN: The `_file_to_jsonl()` awk parser can leak body content into JSONL when `--details_in_md` contains `---` horizontal rules. Should we: (a) fix the awk parser in this PR (small change), (b) create a follow-up ticket, or (c) accept as known limitation?

---

## Suggestions

### 1. Consider adding `--details_in_md` to the help text in CLAUDE.md `5_change_log_usage.md`

The parent repo's CLAUDE.md at `/usr/local/workplace/mirror/thorg-root-mirror-2/CLAUDE.md` (file `5_change_log_usage.md`) contains the `change_log help` output. This should be updated to match the new help text. However, if that help text is dynamically generated (run `change_log help`), this may not be needed.

### 2. Missing argument validation for `--details_in_md` (and other flags)

When `--details_in_md` is the last argument with no value (e.g., `change_log create 'Test' --impact 3 --details_in_md`), the script produces a bash `unbound variable` error (`$2: unbound variable`) due to `set -u`. This is **not a regression** -- all other flags (`--desc`, `--impact`, etc.) have the same behavior. A follow-up enhancement could add `[[ $# -ge 2 ]]` guards before accessing `$2`, but this is low priority.

---

## Verification Checklist

| Check | Result |
|-------|--------|
| `make test` passes | PASS (71 scenarios, 367 steps, 0 failures) |
| `entry_path()` exact match only | PASS -- awk uses `id == search` only |
| Defensive `count > 1` kept | PASS -- line 116 |
| Partial ID scenarios removed from id_resolution.feature | PASS -- 6 removed |
| Partial ID scenarios removed from show/edit/notes features | PASS -- 3 removed |
| New negative test (substring does NOT match) | PASS -- id_resolution.feature line 20 |
| `--details_in_md` flag parsed correctly | PASS -- line 286-287 |
| Details written after frontmatter `---` | PASS -- lines 371-373 |
| `printf '%s\n'` used (not echo) | PASS -- line 372 |
| Empty details_in_md ("") produces no body | PASS -- `[[ -n "$details" ]]` guard at line 371 |
| Help text updated with --details_in_md | PASS -- line 511 |
| Help text matches README usage block | PASS |
| CHANGELOG.md updated | PASS |
| CLAUDE.md updated | PASS |
| No regressions in other functions | PASS |
| `_file_to_jsonl()` not modified | PASS (relied on existing awk behavior) |

---

## Files Reviewed

| File | Path | Verdict |
|------|------|---------|
| Main script | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/change_log` | OK |
| ID resolution tests | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/id_resolution.feature` | OK |
| Creation tests | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_creation.feature` | OK |
| Query tests | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_query.feature` | OK |
| Show tests | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_show.feature` | OK |
| Edit tests | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_edit.feature` | OK |
| Notes tests | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_notes.feature` | OK |
| Step definitions | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/steps/changelog_steps.py` | OK |
| README | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/README.md` | OK |
| CHANGELOG | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/CHANGELOG.md` | OK |
| CLAUDE.md | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/CLAUDE.md` | OK |

---

## Verdict

- [ ] APPROVED
- [x] APPROVED WITH MINOR REVISIONS
- [ ] NEEDS REVISION
- [ ] REJECTED

**Rationale**: The implementation is correct, clean, well-tested, and follows the plan. The one IMPORTANT issue (awk parser leaking body content on `---` lines) is a pre-existing architectural limitation, not introduced by this PR. A decision from the human engineer is needed on whether to fix it in this PR (small scope -- one-line awk change + test) or defer it to a follow-up.
