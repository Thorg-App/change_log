# Pareto Complexity Analysis: Phase 01 Core Script

## Verdict: WARN

The implementation is well-executed with good complexity reduction (1592 -> 578 lines, 64% cut). However, there is dead code that should be removed and the `_file_to_jsonl()` awk deserves scrutiny. None of the issues are blocking.

---

## 1. Overall Complexity Assessment

**578 lines for a 7-command CLI with YAML frontmatter parsing: Acceptable.**

| Component | Lines | Assessment |
|-----------|-------|------------|
| Infrastructure (dir discovery, utils) | ~85 | Appropriate |
| `entry_path()` (partial ID via awk) | 46 | Justified -- single awk pass over all files |
| `_file_to_jsonl()` (JSONL generation) | 116 | Highest complexity area -- see Section 3 |
| `cmd_create()` (arg parsing + validation + file write) | 118 | Reasonable for the number of options supported |
| `cmd_ls()` (awk listing) | 45 | Clean |
| `cmd_query()` | 26 | Clean |
| `cmd_show/edit/add_note/help` | ~115 combined | Straightforward |
| Dead code (`update_yaml_field`, `_sed_i`) | ~28 | Should be removed |
| Dispatch + init | ~17 | Minimal |

**Ratio: High.** The 578 lines deliver all 16 acceptance criteria. The original had 1592 lines with substantial complexity (dependency graphs, cycle detection, plugin system) that has been correctly eliminated.

---

## 2. Function-Level Analysis

### Functions that are right-sized:
- `find_change_log_dir()` -- 43 lines for env-var override, parent walk, git-root auto-create. Each path is a distinct concern. No simplification possible without losing functionality.
- `entry_path()` -- 46 lines. The awk approach for single-pass ID resolution across all files is the correct pattern. Matches the original `ticket_path()` design.
- `cmd_ls()` -- 45 lines. Clean: file glob, sort, single awk pass, formatted output.
- `cmd_show()`, `cmd_edit()` -- 17 and 16 lines respectively. Minimal.
- `cmd_add_note()` -- 32 lines. Straightforward.
- `cmd_query()` -- 26 lines. Delegates correctly to `_file_to_jsonl()`.

### Functions with minor concerns:
- `cmd_create()` at 118 lines -- This is long but justified. It handles 10 CLI options, validation (impact required, impact range, type validation), frontmatter generation with conditional fields (ap/note_id only when provided), and JSONL output. The arg-parsing case statement alone is 25 lines. No unnecessary bloat detected.

---

## 3. `_file_to_jsonl()` Awk Analysis (116 lines)

**Value Delivered:** Machine-readable JSONL output from YAML frontmatter. Handles scalars, arrays, maps, numeric `impact`, quoted strings, and multi-file processing in a single awk pass.

**Complexity Cost:** 116 lines of awk with a state machine tracking `in_front`, `in_map`, `map_key`, plus associative arrays for map pairs.

**Is the complexity justified?** Mostly yes, with one caveat.

The awk must handle 5 distinct value types:
1. Scalar strings (title, desc, author, type, created_iso, id)
2. Quoted strings (stripping outer quotes)
3. Arrays (tags, dirs)
4. Numeric (impact)
5. YAML maps (ap, note_id) -- requires the state machine

Types 1-4 existed in the original `ticket` script (52 lines). The map support adds ~64 lines. This is the single biggest complexity addition.

**Could it be simpler?** The map handling is the minimum viable approach for parsing 2-level YAML maps in awk. Alternatives:
- Shell-level approach (parse maps in bash before awk): Would require two passes and bash string manipulation, likely more fragile.
- Require `yq` dependency: Would simplify but adds an external dependency, contradicting the "coreutils only" design.
- Store ap/note_id as flat key-value strings instead of YAML maps: Would simplify parsing but produce worse YAML (less human-readable).

**Assessment: The map complexity is justified by the design decision to use YAML maps for ap/note_id.** If the design decision is correct (and it appears to be -- maps are the natural YAML shape for key-value pairs), then the awk state machine is the simplest correct implementation.

---

## 4. Map Field Handling (ap/note_id) -- Is the Awk State Machine the Simplest Approach?

The state machine tracks:
- `in_map` (boolean): currently parsing indented map entries
- `map_key` (string): which map field we are inside
- `map_pair_count[key]`, `map_pairs_k[key, idx]`, `map_pairs_v[key, idx]`: collected key-value pairs

This is a minimal two-state machine (in_map=0 or 1). It transitions on:
- Empty-value top-level field -> enter map
- Next top-level field or `---` -> exit map
- Indented `key: value` lines -> accumulate pairs

**This is the simplest correct approach within awk.** The alternative of pre-processing in bash would be more lines, more fragile, and split the parsing logic across two languages.

One note: the `__MAP__` sentinel in `field_vals` is a pragmatic approach to avoid adding a separate field-type array. It works but is slightly magical. Given this is an internal detail of a single function, it is acceptable.

---

## 5. Dead Code Assessment

### Dead code found (WARN):

| Function | Lines | Reason Dead |
|----------|-------|-------------|
| `update_yaml_field()` | 139-152 (14 lines) | Never called. No command in change_log modifies frontmatter fields after creation. |
| `_sed_i()` | 56-61 (6 lines) | Only called from `update_yaml_field()`, which is dead. |

Total: ~20 lines of dead code.

These were useful in the original `ticket` script (status updates, dep management) but no `change_log` command modifies existing frontmatter. The `add-note` command appends to the body, not frontmatter.

**Recommendation:** Remove `update_yaml_field()` and `_sed_i()`. If a future command needs field updates, re-adding them is trivial (they are well-understood patterns).

### Potentially unnecessary but defensible:

| Function | Lines | Assessment |
|----------|-------|------------|
| `yaml_field()` | 132-136 (5 lines) | Called only by `id_from_file()`. Could be inlined. However, keeping it as a named utility is cleaner and costs only 5 lines. Keep. |

---

## 6. Missing Simplifications

### 6a. `cmd_create()` impact validation could be 1 line shorter
Current approach uses a regex check followed by a separate error. This is fine -- explicit is better than clever.

### 6b. `cmd_query()` case statement
```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        *) filter="$1"; shift ;;
    esac
done
```
A case statement with only a `*)` catch-all is unnecessary -- `filter="${1:-}"` would suffice. This is 5 lines that could be 1. Minor.

### 6c. `impact` hardcoded as numeric field in awk
Line 253: `if (key == "impact")` -- The numeric field is identified by string comparison rather than a configurable list. This is correct for now (impact is the only numeric field), but if more numeric fields are added, this pattern does not scale. For the current scope, this is fine -- do not pre-optimize.

### 6d. No unused imports/dependencies
The script correctly has no unnecessary dependencies. `jq` is only required for query filtering. The `rg` fallback to `grep` is clean.

---

## Summary

```
## Pareto Assessment: PROCEED (with minor cleanup)

**Value Delivered:** Complete changelog CLI with 7 commands, YAML frontmatter
parsing, JSONL output, partial ID matching, directory auto-discovery.

**Complexity Cost:** 578 lines total; ~116 lines for the most complex piece
(_file_to_jsonl awk with map support); ~20 lines dead code.

**Ratio:** High -- 64% reduction from original while adding new field types
(maps, required impact validation, timestamp filenames).

**Recommendation:**
- Remove `update_yaml_field()` and `_sed_i()` (dead code, ~20 lines)
- Optionally simplify `cmd_query()` arg parsing (5 lines -> 1 line)
- Everything else: proceed as-is
```

### Specific Red Flag Checklist

| Red Flag | Present? | Notes |
|----------|----------|-------|
| 5x effort for 10% more capability | No | Each function serves a distinct, required purpose |
| "We might need this later" | Minor | `update_yaml_field` and `_sed_i` are retained but unused |
| Config complexity exceeding use-case diversity | No | Simple env var + directory walk |
| Implementation complexity exceeding value | No | The awk map parsing is justified by the YAML map design decision |
| Premature abstraction | No | No unnecessary interfaces or extension points |
| Scope creep | No | Stays within the 7 defined commands |
