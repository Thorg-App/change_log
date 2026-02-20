# Plan Review: Change Default Directory `.change_log` to `_change_log`

## Executive Summary

The plan is well-structured, complete, and correctly identifies all 31 references across 8 files plus the directory rename. The approach (mechanical `replace_all` with post-verification grep) is the right one for this kind of change. I have two minor issues to flag but nothing that blocks implementation.

## Critical Issues (BLOCKERS)

None.

## Major Concerns

None. The plan correctly:
- Identifies that every occurrence of `.change_log` in the codebase refers to the directory name (verified independently).
- Excludes `doc/` directory from changes (those are historical design documents and should remain as-is).
- Leaves `CHANGE_LOG_DIR` env var name and function names like `find_change_log_dir` unchanged (correct -- these reference the concept, not the directory literal).
- Plans a clean break with no migration code (appropriate for a tool consumed by AI agents, not end users with long-lived installations).

## Simplification Opportunities (PARETO)

None needed. The plan is already maximally simple -- `replace_all` on each file, `git mv` the directory, run tests. No over-engineering.

## Minor Suggestions

### 1. Occurrence Count for changelog_steps.py: 14, not 13

The plan claims 13 occurrences in `changelog_steps.py`. My independent grep shows **14 lines** containing `.change_log`:
- Lines 36, 38, 71, 72, 165, 166, 175, 176, 409, 410, 411, 494, 495, 498

That is 14 lines. The plan's Phase 2 line-by-line breakdown lists exactly these 14 lines (lines 36, 38, 71, 72, 165, 166, 175, 176, 409, 410, 411, 494, 495, 498). So the detailed breakdown is correct -- the summary count of "13" is just a minor arithmetic error. Since the approach is `replace_all` on the whole file, this does not affect implementation correctness.

**Action:** Implementer should not rely on the count for verification; just confirm zero remaining occurrences after replacement.

### 2. Verification grep should also exclude `doc/` explicitly

The plan's verification grep at Step 2 already excludes `doc/`:
```bash
rg '\.change_log' --no-ignore --hidden -g '!.ai_out' -g '!.tmp' -g '!doc/' -g '!.git' -g '!ask.dnc.md' -g '!formatted_request.dnc.md'
```

This is correct. The `doc/ralph/changelog_transformation/` file contains 8 historical references to `.change_log` that are archival and should NOT be modified.

### 3. `README.generate.sh` dependency on `templatize_mustache_v2` and `cdi`

The README generation script (`README.generate.sh`) uses `templatize_mustache_v2` and `cdi` from what appears to be a shell utility framework. If the implementer's environment does not have these functions available, Phase 6 (regenerate README) will fail. The implementer should verify the tool is available, or as a fallback, manually update `README.md` (the help text block will already be correct from the script change in Phase 1, so only line 4 of README.md needs manual update -- and the plan already covers that in Phase 4a).

**Suggestion:** If `README.generate.sh` fails, just manually update README.md as specified in Phase 4a. The plan already covers those exact changes.

### 4. CHANGELOG.md historical reference

The plan proposes changing the historical reference at line 14:
```
Storage directory changed from `.tickets/` to `./.change_log/`
```
to:
```
Storage directory changed from `.tickets/` to `./_change_log/`
```

This is debatable. This line documents what happened historically. At the time of that change, the directory WAS `.change_log`. However, since this is in the `[Unreleased]` section and will be read by future consumers who will see `_change_log`, updating it prevents confusion. The plan's choice to update it is reasonable -- it documents the final state as of this release. Acceptable.

## Strengths

1. **Exhaustive enumeration.** Every file and line number is identified. The line-by-line table for the main script is precise and matches the actual source.
2. **Clean break philosophy.** No backward-compatibility shim, no migration, no dual-path logic. Correct for this tool's audience.
3. **Correct exclusion of non-functional files.** `doc/`, `ask.dnc.md`, `formatted_request.dnc.md`, `.ai_out/` are all correctly excluded.
4. **Correct exclusion of conceptual names.** Function names and env var names that use `change_log` as a concept (not a directory literal) are correctly left alone.
5. **Execution order is well-reasoned.** Script first (so help output is correct for README generation), then tests, then docs, then regeneration.
6. **Verification strategy is solid.** Tests + grep + directory check covers all bases.
7. **`replace_all` approach is the right call.** Since every occurrence of `.change_log` in each file refers to the directory name, blanket replacement is safe and simple.

## Risk Assessment

**Low risk.** The change is purely mechanical string substitution. The test suite exercises the complete lifecycle (directory creation, discovery, error messages). If any reference is missed, the tests will catch it because the feature file assertions check the exact error message strings.

One risk not mentioned: **parent repo references**. The parent monorepo's CLAUDE.md (at `/usr/local/workplace/mirror/thorg-root-mirror-5/CLAUDE.md`) contains the `change_log help` output with `.change_log/`. That file is auto-generated from `auto_load` files. Since this is a submodule, the parent repo update is out of scope for this change -- but the implementer should note that the parent repo's CLAUDE.md will need regeneration after this submodule is bumped. This is not a blocker.

## Verdict

- [x] APPROVED WITH MINOR REVISIONS

Minor revisions: Fix the "13" count to "14" in the summary (or just ignore it since `replace_all` does not depend on counts). Everything else is ready for implementation. PLAN_ITERATION can be skipped.
