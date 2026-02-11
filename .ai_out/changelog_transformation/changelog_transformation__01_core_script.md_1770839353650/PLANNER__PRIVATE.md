# PLANNER Private Context -- Phase 01 Core Script

## Key Implementation Notes for IMPLEMENTOR

### Awk `_file_to_jsonl` -- The Hard Part

The awk rewrite is the highest-risk piece. Key details:

1. **Map field detection**: A YAML map looks like `ap:` with empty value, followed by indented `  key: value` lines. The sentinel `__MAP__` in `field_vals` indicates it is a map. The actual pairs are stored in `map_pairs_k[mapkey, index]` and `map_pairs_v[mapkey, index]`.

2. **Awk array cleanup between files**: In the `emit()` function, after outputting JSON for a file, you MUST `delete` the map arrays (`map_pair_count`, `map_pairs_k`, `map_pairs_v`) and reset `field_count` to 0. Otherwise state leaks between files.

3. **Impact as number**: The `impact` field should be output as a bare number in JSON (not quoted). The awk just checks `if (key == "impact")` and skips the quotes around the value.

4. **Empty arrays handling**: If `tags: []` has zero elements, output as `"tags":[]` (empty JSON array). The current awk does this correctly via the split-on-comma logic.

### `find_change_log_dir()` Design Decision

I chose to always auto-create at git root rather than having separate read/write command logic. Rationale:
- The old `init_tickets_dir()` had a `WRITE_COMMANDS` check which was complexity for marginal value
- For a changelog, it's always useful to auto-create -- if someone runs `ls` and the dir doesn't exist, creating it and returning empty is better than an error
- This simplifies the pre-dispatch block to a single call

### `cmd_show()` Simplification

The current `cmd_show()` is ~140 lines of awk that resolves deps, blocking relationships, parents, and children. ALL of that is removed. The new show is literally `cat $file` (with pager support). This is a massive simplification.

### Filename Format Gotcha

The filename `YYYY-MM-DD_HH-MM-SSZ.md` uses underscores and hyphens (no colons, which are illegal on Windows and macOS). The `date -u` format string is `+%Y-%m-%d_%H-%M-%SZ`. Note: the `Z` is literal (not a format specifier) -- it indicates UTC.

### `cmd_query()` -- `xargs` Gotcha

When piping sorted filenames to `xargs _file_to_jsonl`, the function reference may not work in all bash versions with `xargs`. Alternative approach: collect filenames into an array and pass directly:

```bash
local -a sorted_array
mapfile -t sorted_array < <(printf '%s\n' "${md_files[@]}" | sort -r)
_file_to_jsonl "${sorted_array[@]}"
```

This avoids the xargs issue entirely. Recommend this approach for both `cmd_query()` and `cmd_ls()`.

### What NOT to Touch

- The `ticket` file must remain unchanged (Phase 03 removes it)
- Feature files in `features/` must remain unchanged (Phase 02 rewrites them)
- README.md, CLAUDE.md, CHANGELOG.md -- Phase 03

### Lines to Delete (by function, approximate ranges)

Working from bottom to top to avoid line-shift issues:
1. Plugin dispatch + super (1540-1559)
2. `_list_plugins` (1442-1472)
3. `cmd_unlink` (1188-1215)
4. `remove_link_from_file` (1169-1186)
5. `cmd_link` (1090-1167)
6. `add_link_to_file` (1068-1088)
7. `cmd_undep` (1034-1066)
8. `cmd_blocked` (935-1032)
9. `cmd_closed` (888-933)
10. `cmd_ready` (798-886)
11. `cmd_dep` (699-749)
12. `cmd_dep_cycle` (588-697)
13. `cmd_dep_tree` (389-586)
14. `cmd_start`, `cmd_close`, `cmd_reopen` (365-387)
15. `validate_status`, `cmd_status` (335-363)
16. `WRITE_COMMANDS`, `init_tickets_dir` (30-56)
17. `title_to_filename` (89-117)

### Commit Strategy

Since tests are Phase 02, there is no automated verification in this phase. The implementor should:
1. Commit after Step 1 (gut) -- "chore: copy ticket to change_log, remove dead code"
2. Commit after Steps 2-3 (dir + create) -- "feat: change_log create with new data model"
3. Commit after Steps 4-5 (jsonl + ls) -- "feat: change_log query/ls with new field types"
4. Commit after Steps 6-7 (remaining commands + help) -- "feat: complete change_log command set"

This gives good rollback points if something goes wrong.
