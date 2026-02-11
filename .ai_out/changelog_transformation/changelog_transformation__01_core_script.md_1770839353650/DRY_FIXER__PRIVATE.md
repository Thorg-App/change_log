# DRY_FIXER__PRIVATE: Phase 01 -- Core Script

## Analysis Process

1. Read the full `change_log` script (578 lines) and all context files (Pareto analysis, Implementor summary).
2. Confirmed dead code with grep: `_sed_i` only referenced by `update_yaml_field`, which is never called.
3. Identified 3 instances of `md_files=("$CHANGE_LOG_DIR"/*.md)` glob pattern (entry_path, cmd_ls, cmd_query).
4. Identified 2 instances of the full glob+guard+sort pattern (cmd_ls, cmd_query) -- verbatim 5-line duplicate.
5. Applied the "will it change together?" test to each pattern.
6. Verified entry_path uses the glob differently (no sort, error with search term) -- not a candidate for shared helper.
7. Verified ap/note_id loops in cmd_create represent different knowledge (different fields, could diverge).

## Decisions Made

- Removed `_sed_i()` and `update_yaml_field()`: Clear dead code. No command path reaches them.
- Simplified `cmd_query()` arg parsing: A case statement with only `*)` is a no-op wrapper around assignment.
- Extracted `_sorted_entries()`: The glob+guard+sort is one piece of knowledge (how to enumerate entries chronologically). Two call sites. Clean function boundary (outputs to stdout, returns 1 on empty).
- Did NOT touch `entry_path()` glob: Different usage pattern (no sort, different error semantics). The 2 shared lines (glob + guard) are not worth a helper -- the helper's interface would need to accommodate both "return 0 silently" and "error with context" behaviors, adding complexity.

## Testing

Ran full smoke test in /tmp/test_cl_dry:
- `help` -- works
- `create` with all options (impact, desc, tags, dirs, ap, note-id) -- produces correct JSONL
- `ls` -- shows entries
- `ls --limit=1` -- limits correctly
- `query` -- produces JSONL
- `query '.impact > 2'` -- jq filter works
- `show <id>` -- displays file
- `add-note <id> "text"` -- appends note
- Empty dir `ls` -- returns 0 with no output

All passed.
