# PLAN_REVIEWER Private Context -- Phase 01 Core Script

## Key Findings

### The `xargs _file_to_jsonl` Problem
The biggest actionable finding. The PLANNER already caught this in their private context and recommended `mapfile`. The public plan text in Step 6 still shows the broken `xargs` approach. This is the one thing the implementor MUST know to deviate from the public plan text.

### Awk Map Parsing: Verified Sound
I traced through the awk state machine carefully:
- `in_front && /^  [a-zA-Z]/` catches indented map lines
- `in_front && /^[a-zA-Z]/` catches top-level fields and closes any open map
- The closing `---` also closes any open map (via the `if (in_map)` check)
- The `__MAP__` sentinel cleanly separates scalars, arrays, and maps in emit()
- The `delete` of map arrays in emit() prevents cross-file state leakage

This design handles multi-file passes correctly.

### Line Number References Are Accurate
I verified the plan's line references against the actual `ticket` script:
- `title_to_filename()` starts at line 89 (correct)
- `VALID_STATUSES` at line 335 (correct)
- `WRITE_COMMANDS` at line 30 (correct)
- `init_tickets_dir()` at lines 33-56 (correct)
- Plugin dispatch at lines 1540-1559 (correct)
- Dispatch case at lines 1568-1592 (correct)

### What I Did NOT Flag (And Why)

1. **`set -euo pipefail`**: The original has this. The plan does not explicitly mention keeping it, but since it says "copy and gut" (not "rewrite from scratch"), it is implicitly preserved. Fine.

2. **`validate_type()` not a separate function**: The plan inlines type validation in `cmd_create()` rather than extracting a `validate_type()` function (like the old `validate_status()`). For a simple list check, inlining is the KISS choice. Correct decision.

3. **`desc` quoting in frontmatter**: The plan shows `echo "desc: \"$escaped_desc\""` which mirrors how `title` is handled. Consistent.

4. **No `--status` filter on `ls`**: The high-level doc says "remove `--status`/`-a`/`-T` filters (or keep `-T` for tag filter if useful)". The plan removes ALL filters from `ls`, keeping only `--limit`. This is correct for PARETO -- no status exists in the new model, and tag filtering can be done via `query` with jq. No need to maintain bash-level filters when `query` exists.

5. **The `entry_path()` function uses awk over ALL .md files**: With timestamp filenames, there is no way to resolve a partial ID without scanning. The awk approach is O(n) in the number of files, which is fine for a CLI tool with typically <1000 entries. No concern.

### Potential Follow-up for Phase 02 (Testing)

The `_file_to_jsonl()` awk rewrite is the highest-risk piece and should be the first thing tested in Phase 02. Recommend BDD scenarios covering:
- Entry with all fields (scalar, array, map)
- Entry with minimal fields (just id, title, impact, type)
- Multiple entries in a single query call
- Map values with special characters
- Empty arrays (`tags: []`)

### Commit Strategy Assessment

The 4-commit approach from PLANNER_PRIVATE is good. However, Step 1 (gut) should be manually verified with `./change_log help` before proceeding. If the gut step leaves dangling references (e.g., a call to `title_to_filename()` still exists in `cmd_create()`), it will fail at runtime even though bash does not do compile-time checks.

The plan correctly notes that `cmd_create()` will be REWRITTEN in Step 3, so dangling references in `cmd_create()` from Step 1 are acceptable as long as they are fixed by Step 3. The implementor should be aware that `./change_log create` will NOT work between Step 1 and Step 3 -- only `help` is guaranteed to work after Step 1.
