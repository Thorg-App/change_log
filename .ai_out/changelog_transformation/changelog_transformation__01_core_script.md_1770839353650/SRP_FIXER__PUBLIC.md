# SRP_FIXER__PUBLIC: Phase 01 -- Core Script

## Summary

No SRP violations found. Zero changes made to `/home/nickolaykondratyev/git_repos/Thorg-App_change_log/change_log`. The script (548 lines) is well-structured with clearly defined function responsibilities.

## Analysis: Every Function Reviewed

### Utility Functions -- All Clean

| Function | Lines | Responsibility | Verdict |
|----------|-------|---------------|---------|
| `find_change_log_dir()` | 8-39 | Directory resolution (env var, walk parents, auto-create) | Single axis of change: "where entries live" |
| `_grep()` | 44-48 | grep abstraction (ripgrep vs grep) | Single axis of change: "how to search" |
| `_iso_date()` | 51-53 | ISO timestamp formatting | Trivial, single purpose |
| `generate_id()` | 56-60 | Random ID generation | Trivial, single purpose |
| `timestamp_filename()` | 63-65 | Timestamp-based filename | Trivial, single purpose |
| `id_from_file()` | 68-70 | Extract ID from file (delegates to yaml_field) | Trivial, single purpose |
| `ensure_dir()` | 73-75 | Directory creation | Trivial, single purpose |
| `_sorted_entries()` | 79-84 | List entries most-recent-first | Single axis of change: "entry ordering" |
| `entry_path()` | 87-130 | Resolve ID to file path (partial matching) | Single axis of change: "ID resolution" |
| `yaml_field()` | 133-137 | Extract YAML frontmatter field | Single axis of change: "field extraction" |
| `_file_to_jsonl()` | 144-258 | YAML frontmatter to JSONL serialization | See detailed analysis below |

### `_file_to_jsonl()` -- Complex but Cohesive (114 lines)

This awk block is the most complex function. It handles:
- Frontmatter parsing (state machine for `---` delimiters)
- Map field parsing (`ap:`, `note_id:` with indented children)
- Array field parsing (`tags: [a, b]`)
- Numeric field handling (`impact`)
- JSON serialization with escaping

All of these sub-concerns serve ONE responsibility: **serialize changelog entry files to JSONL**. They change together -- if the YAML schema changes, the serialization must change. If the JSON output format changes, the serialization must change. There is one axis of change here: "how entries are serialized."

Splitting this awk into separate awk scripts would add complexity and lose the single-pass performance benefit.

### Command Handlers -- All Clean

| Function | Lines | Verdict |
|----------|-------|---------|
| `cmd_show()` | 378-393 | 15 lines, single purpose: display entry |
| `cmd_edit()` | 395-409 | 14 lines, single purpose: open in editor |
| `cmd_add_note()` | 411-441 | 30 lines, single purpose: append note |
| `cmd_ls()` | 443-481 | 38 lines, single purpose: list entries |
| `cmd_query()` | 483-497 | 14 lines, single purpose: JSONL query |
| `cmd_help()` | 499-526 | 27 lines, single purpose: print help |

### `cmd_create()` -- Largest Function, Examined Closely (116 lines)

This function has four identifiable sections:
1. **Argument parsing** (lines 270-295) -- 25 lines
2. **Validation** (lines 297-317) -- 20 lines
3. **File generation** (lines 319-373) -- 54 lines
4. **JSONL output** (line 375) -- 1 line

**Considered extracting validation into `_validate_create_args()`.**

Reasons I chose NOT to:
- In bash, extracting means either passing 2+ variables as arguments (verbose), or using globals (messy). Neither is a net improvement over the current inline approach.
- The validation block (20 lines) is clearly separated by comments and reads linearly top-to-bottom.
- The function as a whole follows the standard bash CLI pattern: parse, validate, execute. Splitting this pattern adds indirection without improving cohesion.
- The 116-line total is within acceptable range for a bash command handler with argument parsing.

**Change axes analysis for `cmd_create()`:**
- Business rules (validation) and file format (generation) are technically separate axes. But they are tightly coupled in practice: adding a new required field means changes to both argument parsing AND file writing AND validation. In a bash script this is natural and expected.

## Scattered Responsibility Check

Verified that no single responsibility is fragmented across multiple functions:
- **YAML writing**: Only in `cmd_create()` (the only command that creates files)
- **YAML reading/parsing**: `yaml_field()` for simple reads, `_file_to_jsonl()` for full serialization, `entry_path()` for ID resolution -- each with a different purpose
- **ID resolution**: Only in `entry_path()`, called by show/edit/add-note
- **Entry listing**: Only in `_sorted_entries()`, called by ls/query
- **File output formatting**: JSONL in `_file_to_jsonl()`, tabular in `cmd_ls()` awk -- different output formats, different responsibilities

No scattered responsibilities found.

## What Was NOT Changed (and Why)

### `cmd_create()` validation not extracted
See detailed analysis above. 20 lines of validation in a 116-line bash function does not justify a separate function when the variable-passing overhead in bash is considered.

### `_file_to_jsonl()` awk not split
114 lines of awk that forms a single-pass state machine. Splitting would require multi-pass processing or inter-process communication, adding complexity for no cohesion benefit.

### `cmd_ls()` inline awk not extracted
The 19-line awk in `cmd_ls()` is a display formatter specific to the `ls` command. It has no other callers and its format is coupled to the `ls` output requirements. Extracting it would just move it somewhere else without improving SRP.

### `find_change_log_dir()` multi-strategy resolution not split
The function tries env var, parent walk, git root in sequence. These are three strategies for ONE responsibility (find the directory). They change together if the resolution logic changes.
