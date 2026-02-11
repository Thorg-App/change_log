# Plan Review: Phase 01 -- Core Script Transformation

## Executive Summary

The plan is well-structured, appropriately scoped, and follows PARETO principles by aggressively deleting dead code (~1200 lines) to produce a focused ~350-400 line script. The 7-step ordering is correct (infrastructure, then commands from simple to complex). I found two issues that need inline correction (the `xargs _file_to_jsonl` portability problem and a missing field-state reset in awk), but no architectural problems requiring plan iteration.

## Critical Issues (BLOCKERS)

None.

## Major Concerns

### 1. `xargs _file_to_jsonl` Will Not Work as Written

- **Concern:** In Step 6 (`cmd_query()`), the plan pipes filenames through `xargs -d '\n' _file_to_jsonl`. Since `_file_to_jsonl` is a bash function (not an executable in PATH), `xargs` cannot invoke it. This applies to `cmd_ls()` in Step 5 as well, though there the plan uses `xargs awk '...'` directly (which does work since `awk` is a real executable).

- **Why:** `xargs` spawns a new process that has no access to the calling shell's function definitions.

- **Inline Adjustment:** The PLANNER_PRIVATE.md already identifies this and recommends using `mapfile`:
  ```bash
  local -a sorted_array
  mapfile -t sorted_array < <(printf '%s\n' "${md_files[@]}" | sort -r)
  _file_to_jsonl "${sorted_array[@]}"
  ```
  **This is the correct approach.** The implementor MUST use the `mapfile` approach for `cmd_query()`, not `xargs`. The plan's Step 6 `cmd_query()` pseudocode should be treated as superseded by the private context recommendation.

### 2. Awk `field_count` Reset Missing in `emit()`

- **Concern:** The plan's Step 4 awk pseudocode for `emit()` deletes `map_pair_count`, `map_pairs_k`, and `map_pairs_v` at the end, but does NOT reset `field_count`, `field_keys`, or `field_vals`. The existing `_file_to_jsonl` resets `field_count` in the `FNR==1` block, but the `emit()` function runs BEFORE that reset (it is called from the `FNR==1` handler of the NEXT file, and also from `END`). This means if `emit()` does not clean up `field_keys`/`field_vals`, the arrays retain stale data from a previous file.

- **Why:** In practice, the `field_count` reset at `FNR==1` means the for-loop only iterates up to the new count, so stale entries in higher indices are never read. This is actually fine. The existing code works the same way. No fix needed -- I retract this concern upon closer analysis. The awk state machine is correct.

### 3. Map Values Containing Colons

- **Concern:** The plan's awk map parsing uses `FS=": "` (field separator) for the top-level fields. For indented map lines like `  handler: anchor_point.X`, the manual line parsing (`sub(/^[^:]+: */, "", v)`) correctly handles this. However, if a map value itself contains `: ` (e.g., `  key: value: with: colons`), the sub regex would only strip up to the first colon.

- **Why:** The regex `sub(/^[^:]+: */, "", v)` strips everything up to and including the first `: `, which is the correct behavior for `key: value` parsing since we want everything after the first colon. This is actually correct for the common case. The plan's risk table acknowledges "Keep map values simple (no colons in values)" which is an acceptable constraint.

- **Inline Adjustment:** None needed. The constraint is documented.

## Simplification Opportunities (PARETO)

### 1. Consider Using `mapfile` Consistently for Sorted File Lists

Both `cmd_ls()` (Step 5) and `cmd_query()` (Step 6) need reverse-sorted file lists. The plan uses different approaches: `sort -r | xargs awk` for ls, and `xargs -d '\n' _file_to_jsonl` for query. Recommend a single shared pattern:

```bash
# Shared idiom for both cmd_ls and cmd_query:
local -a sorted_files
mapfile -t sorted_files < <(printf '%s\n' "${md_files[@]}" | sort -r)
```

Then `cmd_ls` passes `"${sorted_files[@]}"` to inline awk, and `cmd_query` passes `"${sorted_files[@]}"` to `_file_to_jsonl`. This eliminates the `xargs` dependency entirely.

**Value:** Consistency, portability, one pattern to understand.

### 2. `cmd_ls` Limit via Awk Counter (Not `head`)

The plan's Step 5 applies limit via `head -n "$limit"` on the filename list before passing to awk. This is fine and arguably simpler than doing it in awk. No change recommended -- this is already KISS.

## Minor Suggestions

### 1. Collision Handling: `sleep 1` Is Correct but Worth a Comment

The plan's collision handling (`sleep 1` then regenerate) is appropriately simple for a single-user CLI. The implementor should add a brief comment explaining why (two creates in the same second from a fast script loop).

### 2. `cmd_ls` Output Format: Partial ID Truncation

The format string `%-8s` in `cmd_ls()` will print the first 8 characters of the 25-char ID. However, the plan's awk only captures `id = $2` (the full 25-char ID). Consider explicitly truncating to 8 chars in awk: `substr(id, 1, 8)`. The existing ticket script does the same `%-8s` which naturally truncates the printf output, so this is just a cosmetic consistency note. The `%-8s` format will pad short IDs and truncate long ones, which is correct behavior.

### 3. `find_change_log_dir()` -- Walking Parents Should Look for `change_log/` Not `./change_log/`

The plan's pseudocode says "Walk from $PWD upward. If `change_log/` directory found, echo its path, return 0." This is correct. The high-level doc says `./change_log/` in some places which is just relative path notation. Just ensure the implementation checks for `"$dir/change_log"` (not `"$dir/./change_log"`). This matches how the original `find_tickets_dir()` checks for `"$dir/.tickets"`.

### 4. Title Positional Argument -- "Untitled" Fallback

The plan says title "falls back to 'Untitled'" when not provided. The high-level design behaviors all show a title being provided. Consider whether "Untitled" is actually useful or whether requiring a title would be better (since `--impact` is already required, requiring a title adds minimal friction). However, the existing script has this fallback, so keeping it is fine for consistency. No change required.

### 5. `cmd_add_note()` Uses `grep` Directly (Line 1395 of Original)

The original `cmd_add_note()` uses `grep -q '^## Notes'` instead of `_grep -q`. The plan says "minimal change" for this function. The implementor should also fix this to use `_grep -q` for consistency with the portable grep wrapper. Minor polish.

## Strengths

1. **Aggressive deletion**: Removing ~1200 lines and 17+ functions is exactly the right approach. The plan does not try to preserve or adapt dead code.

2. **Step ordering is correct**: Infrastructure (copy/gut, directory) before commands, simple commands before complex ones (create before ls before query).

3. **The awk map parsing design is sound**: Using a `__MAP__` sentinel with separate `map_pairs_k`/`map_pairs_v` arrays is a clean approach that integrates well with the existing awk pattern.

4. **`cmd_show()` simplification is dramatic and correct**: Going from ~140 lines of awk (deps, blocking, children, links) to a simple `cat` with pager support is a perfect PARETO move.

5. **The private context identifies the `xargs` portability issue** and recommends the correct `mapfile` approach. This shows good technical foresight.

6. **The commit strategy** (4 commits at logical boundaries) provides good rollback points.

7. **The acceptance criteria section** is thorough with 18 concrete manual tests covering happy paths and error cases.

8. **`find_change_log_dir()` auto-create at git root** is simpler than the old read/write command distinction and more predictable.

## Verification Checklist (Against Task Requirements)

| Acceptance Criterion | Plan Coverage | Status |
|---|---|---|
| `change_log` script exists and is executable | Step 1 (`cp`, `chmod +x`) | COVERED |
| `create` with `--impact` creates correct file | Step 3 (full rewrite) | COVERED |
| `create` without `--impact` fails | Step 3 (validation) | COVERED |
| `create` with `--impact 6` fails | Step 3 (1-5 range check) | COVERED |
| All optional fields write correctly | Step 3 (frontmatter output) | COVERED |
| `ap`/`note_id` omitted when not provided | Step 3 (conditional output) | COVERED |
| `show <id>` displays entry | Step 6 | COVERED |
| `edit <id>` opens in $EDITOR | Step 6 | COVERED |
| `ls` most-recent-first | Step 5 (reverse filename sort) | COVERED |
| `ls --limit=N` | Step 5 | COVERED |
| `query` outputs JSONL with all fields | Step 4 + Step 6 | COVERED |
| `add-note` appends timestamped note | Step 6 | COVERED |
| `help` shows changelog text | Step 7 | COVERED |
| No ticketing commands work | Step 1 (dispatch gutting) | COVERED |
| `CHANGE_LOG_DIR` env override | Step 2 | COVERED |
| Auto-creates at git root | Step 2 | COVERED |

All 16 acceptance criteria from the task file are covered by the plan.

## Verdict

- [ ] APPROVED
- [x] APPROVED WITH MINOR REVISIONS
- [ ] NEEDS REVISION
- [ ] REJECTED

**PLAN_ITERATION needed: NO**

The plan is approved. The critical inline adjustment is: **use `mapfile` instead of `xargs` for `cmd_query()`** (already identified in PLANNER_PRIVATE.md). The implementor should treat the private context `mapfile` recommendation as the authoritative approach for both `cmd_query()` and `cmd_ls()`.
