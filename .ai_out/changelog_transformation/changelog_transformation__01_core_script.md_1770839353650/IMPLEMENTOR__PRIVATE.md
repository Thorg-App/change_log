# IMPLEMENTOR__PRIVATE: Phase 01 State

## Implementation Complete
All 7 steps from the plan executed. All 18 acceptance criteria verified via manual smoke tests.

## Key Implementation Decisions

### Awk Map Key Colon Fix
When `FS=": "` and a line is `ap:` (no value), awk's `$1` is `ap:` (with colon). Fixed by adding `sub(/:$/, "", key)` after extracting `$1`. This is the only non-trivial deviation from the plan.

### Script Written From Scratch
Rather than doing incremental `cp` + edit, wrote the complete `change_log` script in one pass. This produced cleaner code than surgically removing functions from the 1593-line original.

### mapfile Pattern Used Consistently
Both `cmd_ls()` and `cmd_query()` use:
```bash
local -a sorted_files
mapfile -t sorted_files < <(printf '%s\n' "${md_files[@]}" | sort -r)
```
This avoids the `xargs` + bash function problem identified by the reviewer.

## Functions Retained from ticket
- `_grep()` -- portable grep wrapper (lines 47-51)
- `_iso_date()` -- ISO timestamp (lines 54-56)
- `_sed_i()` -- portable sed -i (lines 59-63)
- `generate_id()` -- 25-char random ID (lines 66-69)
- `id_from_file()` -- extract id from frontmatter (lines 77-79)
- `entry_path()` -- partial ID resolution (renamed from `ticket_path`, lines 87-122)
- `yaml_field()` -- YAML field extraction (lines 125-129)
- `update_yaml_field()` -- YAML field update (lines 132-144)

## Functions New or Heavily Rewritten
- `find_change_log_dir()` -- auto-create at git root (lines 8-39)
- `timestamp_filename()` -- ISO8601 filename stem (lines 72-74)
- `_file_to_jsonl()` -- awk with map support (lines 159-245)
- `cmd_create()` -- new frontmatter, validation (lines 247-340)
- `cmd_show()` -- simplified to cat/pager (lines 342-355)
- `cmd_ls()` -- reverse filename sort + --limit (lines 377-417)
- `cmd_query()` -- most-recent-first sort (lines 419-441)
- `cmd_help()` -- complete rewrite (lines 443-470)

## Functions Removed (from ticket)
`title_to_filename`, `validate_status`, `cmd_status`, `cmd_start`, `cmd_close`, `cmd_reopen`, `cmd_dep_tree`, `cmd_dep_cycle`, `cmd_dep`, `cmd_ready`, `cmd_closed`, `cmd_blocked`, `cmd_undep`, `add_link_to_file`, `cmd_link`, `remove_link_from_file`, `cmd_unlink`, `_list_plugins`, `init_tickets_dir`, plugin dispatch block, `WRITE_COMMANDS`, `VALID_STATUSES`.

## Next Phase Dependencies
- Phase 02 (test_suite): Will need to create BDD tests for all `change_log` commands
- Phase 03 (repo_cleanup): Will need to remove old files, update README.md, CLAUDE.md
