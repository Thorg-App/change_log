# Pareto Complexity Analysis

## Pareto Assessment: PROCEED

**Value Delivered:** Six concrete requirements fulfilled -- title-based filenames, title in frontmatter, 25-char random IDs decoupled from filename, create prints JSON, query always includes full_path, query includes title.

**Complexity Cost:** +375 / -186 lines across 10 files. Core script grew ~90 net lines. Test infrastructure grew ~140 net lines. 6 new test scenarios added, 3 obsolete ones removed.

**Ratio:** High

## Overall Pareto Score: 8/10

## 1. Value Delivered

All six requirements are implemented and tested:

| Requirement | Status | Verification |
|---|---|---|
| Filename based on title | Done | `title_to_filename()` with collision handling |
| Title in frontmatter as `title: "..."` | Done | `cmd_create()` writes it, 7 awk blocks read it |
| 25-char random ID, decoupled from filename | Done | `generate_id()` rewritten, `ticket_path()` searches frontmatter |
| `create` prints full JSON | Done | Reuses `_file_to_jsonl()` |
| `query` always includes `full_path` | Done | `--include-full-path` flag removed, always-on |
| `query` includes title | Done | Automatic via frontmatter field capture |

The data model change (ID decoupled from filename, title in frontmatter) is a genuine architectural improvement that makes filenames human-readable while keeping IDs stable. This is the core value proposition and it is well-executed.

## 2. Justified Complexity

### `ticket_path()` rewrite (lines 130-173)
The old `ticket_path()` did a simple filename match. The new one does a single-pass awk scan through all files searching frontmatter `id:` fields. This is necessarily more complex because the ID is no longer in the filename. The implementation is clean: one awk pass, exact-match-first logic, same error messages. **Justified.**

### `_file_to_jsonl()` extraction (lines 200-252)
Extracting the awk JSON generator into a shared function is textbook DRY. It is used by both `cmd_create()` and `cmd_query()`. The old code had this logic duplicated (or rather, only in query). Adding `json_escape()` is a genuine correctness fix the old code lacked. **Justified.**

### `title_to_filename()` with collision handling (lines 89-117)
The collision handling (append `-1`, `-2`, etc.) is the simplest approach and directly addresses the requirement for duplicate title handling. The slug conversion is a single pipeline. 200-char truncation is a practical safeguard. **Justified.**

### 7x awk title extraction pattern change
Each of the 7 awk blocks that read titles needed to change from `!in_front && /^# /` to `in_front && /^title:/`. This is a mechanical replacement -- annoying but unavoidable given the data model change. **Justified.**

### Test infrastructure changes (186 lines in step defs)
The `create_ticket()` helper, `find_ticket_file()`, and `extract_created_id()` are all necessary because the data model changed. The test infrastructure mirrors the production code patterns. **Justified.**

## 3. Unjustified Complexity -- Minor Items

### Repeated awk title-extraction line (7 occurrences)
The exact same awk line appears 7 times:
```awk
in_front && /^title:/ { title = substr($0, 8); gsub(/^ +| +$/, "", title); if (title ~ /^".*"$/) title = substr(title, 2, length(title) - 2) }
```
This is a DRY violation, but it is a **known limitation of inline awk in bash**. Each awk block is a self-contained script with its own variable scope. Extracting this into a shared awk file or function would add indirection and complexity that outweighs the duplication cost. The line is short, deterministic, and unlikely to diverge. **Acceptable trade-off, not a blocker.**

### `id_from_file()` wrapper (line 120-122)
This is a one-liner wrapping `yaml_field "$1" "id"`. It adds a named abstraction for readability at the call sites (12 usages). The cost is trivial. **Acceptable.**

## 4. Under-Engineering -- Areas to Watch

### No migration path for existing tickets
The plan explicitly calls this out as a clean break. This is the right 80/20 call -- building a migration command now would be speculative complexity. If needed later, a `migrate-v1` plugin can be added.

### No ID uniqueness check on create
`generate_id()` produces 25 characters from `[a-z0-9]` which gives 36^25 possibilities (~1.8 * 10^38). Collision probability is astronomically low. Checking for uniqueness would add a `ticket_path` call (scanning all files) on every create. **Correctly omitted.**

### `ticket_path()` performance on large ticket sets
The single-pass awk scan is O(n) per invocation. Some commands invoke it twice (e.g., `cmd_dep`). For <500 tickets this is sub-50ms. The plan correctly identifies this as a future optimization candidate, not a current concern. **Correctly deferred.**

## 5. 80/20 Assessment

Could 80% of the value have been delivered with significantly less complexity? **No.**

The six requirements are tightly coupled -- you cannot have title-based filenames without decoupling the ID from the filename, which requires rewriting `ticket_path()`, which requires updating all awk scripts that read IDs, and so on. There is no meaningful subset that delivers most of the value independently.

The implementation avoids gold-plating:
- No index/cache file for `ticket_path()` lookups
- No migration command
- No backward compatibility layer
- No configuration options for ID length or filename format
- `_file_to_jsonl()` is shared (DRY) rather than duplicated

The +375/-186 line diff for a data model change that touches ID generation, file naming, ID resolution, file creation, JSON output, 7 awk scripts, help text, README, and 12 feature files is **lean**.

## 6. Deviations from Plan -- All Justified

The implementor documented 5 deviations from the plan. All were pragmatic fixes:
1. awk backreference fix (plan had invalid awk syntax)
2. SIGPIPE fix for `set -euo pipefail` compatibility
3. Glob handling fix (suppressed awk stderr properly)
4. Added `json_escape()` (correctness improvement over old code)
5. Left `cmd_migrate_beads()` untouched (correct scoping)

None of these added gratuitous complexity.

## Final Verdict: PASS

**Recommendation:** Proceed as-is. The implementation delivers all 6 requirements with proportional complexity. The 7x repeated awk line is the only DRY concern and is an acceptable trade-off in inline bash/awk. No simplifications would meaningfully reduce complexity without sacrificing required functionality.
