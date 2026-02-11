# DRY_FIXER__PUBLIC: Phase 01 -- Core Script

## Summary

Three changes made to `/home/nickolaykondratyev/git_repos/Thorg-App_change_log/change_log`. Line count reduced from 578 to 548 (30 lines net). All changes are behavior-preserving. Full smoke test passed (create, ls, ls --limit, show, edit, add-note, query, query with jq filter, empty directory).

## Changes Made

### 1. Removed Dead Code: `_sed_i()` and `update_yaml_field()` (22 lines removed)

Both functions were carried over from the original `ticket` script but never called by any `change_log` command. `_sed_i()` was only called by `update_yaml_field()`, and `update_yaml_field()` was never called at all. No command in `change_log` modifies frontmatter fields after creation -- `add-note` appends to the body, not frontmatter.

**Files changed:** `change_log` lines 56-61 (`_sed_i`) and lines 139-152 (`update_yaml_field`) removed.

### 2. Simplified `cmd_query()` Arg Parsing (5 lines -> 1 line)

Replaced a `while/case` loop containing only a `*)` catch-all with `local filter="${1:-}"`. The loop was unnecessary overhead -- a case statement with only a wildcard match is just assignment with extra steps.

**Before:**
```bash
local filter=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        *) filter="$1"; shift ;;
    esac
done
```

**After:**
```bash
local filter="${1:-}"
```

### 3. Extracted `_sorted_entries()` Helper (knowledge deduplication)

`cmd_ls()` and `cmd_query()` both contained an identical 5-line pattern: glob `.md` files, guard for empty directory, reverse-sort by filename. This is a single piece of knowledge -- "how to get the list of changelog entries in chronological order" -- that was duplicated.

The change question confirms this is knowledge duplication: if the file extension changes, or the sort order changes, or the glob pattern changes, both call sites would need to change together.

**Extracted helper (8 lines):**
```bash
# List all entry files, most-recent-first (one path per line).
# Returns 1 if no entries exist.
_sorted_entries() {
    local md_files
    md_files=("$CHANGE_LOG_DIR"/*.md)
    [[ ! -f "${md_files[0]}" ]] && return 1
    printf '%s\n' "${md_files[@]}" | sort -r
}
```

**Callers simplified to:**
```bash
local -a sorted_files
mapfile -t sorted_files < <(_sorted_entries) || return 0
```

Note: `entry_path()` also globs `.md` files but does NOT sort and has different error handling (emits an error message with the search term). The usage is different enough that forcing it through the same helper would add complexity, not remove it. Left as-is.

## What Was NOT Changed (and Why)

### `entry_path()` glob pattern not deduplicated
The glob `"$CHANGE_LOG_DIR"/*.md` appears in both `entry_path()` and `_sorted_entries()`. However, `entry_path()` does not sort and has unique error handling that depends on the search parameter. Extracting just the glob into a helper would save 2 lines per call site at the cost of an additional indirection. Not worth it.

### `cmd_create()` ap/note_id loops look similar but represent different knowledge
The two loops (lines 354-361 and 363-370) emit `ap:` and `note_id:` YAML map sections respectively. They have identical structure but represent different fields with potentially different future requirements. If the format for anchor points changes, note_id references would not necessarily change. Different knowledge -- not a DRY violation.

### `impact` hardcoded as numeric field in awk
Line 238 `if (key == "impact")` -- only one numeric field exists. Adding a configurable list of numeric fields would be over-engineering for one field.

### `cmd_show()` and `cmd_edit()` usage-check pattern
Both start with `if [[ $# -lt 1 ]]` followed by a usage message. This is standard CLI pattern, not knowledge duplication. Each message is command-specific.
