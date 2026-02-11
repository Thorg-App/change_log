# Implementation Plan: Phase 01 -- Core Script Transformation

## Problem Understanding

Transform the `ticket` bash script (1593 lines) into a `change_log` script that serves as a changelog system for AI agents. The new script keeps the same bash+awk architecture but removes all ticketing concepts (status, deps, links, plugins) and replaces them with a simpler changelog data model.

**Key constraints:**
- This phase produces a working `change_log` script only. No tests (Phase 02), no repo cleanup (Phase 03).
- The old `ticket` file stays untouched. We create a new `change_log` file.
- Pareto: keep it simple, reuse what works, delete aggressively.

---

## Implementation Order (7 Steps)

The steps are ordered to build on each other: infrastructure first, then commands from simple to complex.

---

### Step 1: Copy and Gut

**Goal:** Create `change_log` from `ticket`, remove all dead code, producing a skeleton that compiles (runs without errors if you call `help`).

**Actions:**

1. `cp ticket change_log && chmod +x change_log`
2. Update the shebang comment: `# change_log - git-backed changelog for AI agents`
3. **Delete these functions entirely** (they have no callers in the new script):
   - `title_to_filename()` (lines 89-117)
   - `validate_status()` (lines 337-344)
   - `cmd_status()` (lines 346-363)
   - `cmd_start()` (lines 365-371)
   - `cmd_close()` (lines 373-379)
   - `cmd_reopen()` (lines 381-387)
   - `cmd_dep_tree()` (lines 389-586)
   - `cmd_dep_cycle()` (lines 588-697)
   - `cmd_dep()` (lines 699-749)
   - `cmd_ready()` (lines 798-886)
   - `cmd_closed()` (lines 888-933)
   - `cmd_blocked()` (lines 935-1032)
   - `cmd_undep()` (lines 1034-1066)
   - `add_link_to_file()` (lines 1068-1088)
   - `cmd_link()` (lines 1090-1167)
   - `remove_link_from_file()` (lines 1169-1186)
   - `cmd_unlink()` (lines 1188-1215)
   - `_list_plugins()` (lines 1442-1472)
   - The `VALID_STATUSES` constant (line 335)
   - The `WRITE_COMMANDS` constant (line 30)
   - The `init_tickets_dir()` function (lines 33-56)
4. **Delete the plugin dispatch block** (lines 1540-1559): the `_tk_super` variable, the plugin lookup loop, and the `cmd_super` concept.
5. **Delete the `init_tickets_dir` call** in the pre-dispatch block (lines 1562-1565). This will be replaced by `find_change_log_dir()`.
6. **Gut the dispatch case statement** (lines 1568-1592) to only keep:
   ```
   create, ls|list, show, edit, add-note, query, help|--help|-h, *) unknown
   ```
7. Rename `TICKET_PAGER` to `CHANGE_LOG_PAGER` (line 58).
8. Rename the function `ticket_path()` to `entry_path()`. Update all callers. Also rename `id_from_file()` -- actually, `id_from_file()` is fine, keep the name since it's still extracting an id from a file. Just update `ticket_path` -> `entry_path` and update all internal error messages from "ticket" to "entry".

**Verification:** `./change_log help` runs without errors (help text will still be old at this point, that is fine).

---

### Step 2: `find_change_log_dir()` and Directory Initialization

**Goal:** Replace `find_tickets_dir()` with `find_change_log_dir()` that auto-creates at git root.

**Rename/Rewrite `find_tickets_dir()` to `find_change_log_dir()`:**

```
find_change_log_dir() {
    # 1. Env var override
    if CHANGE_LOG_DIR is set and non-empty, echo it and return 0

    # 2. Walk parents looking for change_log/
    Walk from $PWD upward. If change_log/ directory found, echo its path, return 0.

    # 3. Auto-create at git root
    Use `git rev-parse --show-toplevel` to find git root.
    If successful: mkdir -p "$git_root/change_log", echo "$git_root/change_log", return 0

    # 4. Fallback: cannot find or create
    Print error to stderr, return 1
}
```

**Replace the pre-dispatch initialization block** (the old `init_tickets_dir` call) with:

```bash
case "${1:-help}" in
    help|--help|-h) ;;
    *)
        CHANGE_LOG_DIR=$(find_change_log_dir) || exit 1
        ;;
esac
```

**Key difference from the old design:** No special "write vs read command" distinction. `find_change_log_dir()` always auto-creates if not found. This is simpler and the changelog is always at git root, which is predictable.

**Update all references** of `TICKETS_DIR` to `CHANGE_LOG_DIR` throughout the file. Also update `$TICKETS_DIR/*.md` glob patterns.

**Update `ensure_dir()`:** Change to `mkdir -p "$CHANGE_LOG_DIR"`. Actually, since `find_change_log_dir()` already creates the directory, `ensure_dir()` can just be a safety `mkdir -p "$CHANGE_LOG_DIR"` or removed entirely. Keep it as a one-liner for safety.

**Verification:** From a git repo without `change_log/`, run `./change_log help` (should work without creating dir). Then `./change_log ls` should create `change_log/` at git root and list nothing.

---

### Step 3: `cmd_create()` -- New Frontmatter and Timestamp Filename

**Goal:** Rewrite create to produce the new changelog entry format.

**New function: `timestamp_filename()`**

```bash
timestamp_filename() {
    date -u +%Y-%m-%d_%H-%M-%SZ
}
```

This generates the filename stem. The full path is `$CHANGE_LOG_DIR/$(timestamp_filename).md`.

**Handle collision:** If the file already exists (two creates in the same second), sleep 1 second and regenerate. Simple approach:

```bash
local filename
filename="$(timestamp_filename).md"
if [[ -f "$CHANGE_LOG_DIR/$filename" ]]; then
    sleep 1
    filename="$(timestamp_filename).md"
fi
```

**Rewrite `cmd_create()` argument parsing:**

Remove old flags: `-d/--description`, `--design`, `--acceptance`, `-p/--priority`, `--external-ref`, `--parent`, `-a/--assignee`.

New flags:
| Flag | Variable | Required | Default | Validation |
|------|----------|----------|---------|------------|
| (positional) | `title` | yes (falls back to "Untitled") | "Untitled" | none |
| `--impact` | `impact` | **YES** | none | must be 1-5 integer |
| `-t/--type` | `entry_type` | no | `default` | must be one of: `feature`, `bug_fix`, `refactor`, `chore`, `breaking_change`, `docs`, `default` |
| `--desc` | `desc` | no | "" | none |
| `--tags` | `tags` | no | "" | comma-separated |
| `--dirs` | `dirs` | no | "" | comma-separated |
| `--ap` | `ap_pairs` (array) | no | () | `key=value` format, repeatable |
| `--note-id` | `note_id_pairs` (array) | no | () | `key=value` format, repeatable |
| `-a/--author` | `author` | no | `git config user.name` | none |

**Validation (before writing file):**

1. If `impact` is empty: `echo "Error: --impact is required (1-5)" >&2; return 1`
2. If `impact` is not 1-5: `echo "Error: --impact must be 1-5, got '$impact'" >&2; return 1`
3. If `entry_type` not in valid list: `echo "Error: invalid type '$entry_type'. Valid: feature, bug_fix, refactor, chore, breaking_change, docs, default" >&2; return 1`

**Frontmatter output:**

```bash
{
    echo "---"
    echo "id: $id"
    echo "title: \"$escaped_title\""
    [[ -n "$desc" ]] && echo "desc: \"$escaped_desc\""
    echo "created_iso: $now"
    echo "type: $entry_type"
    echo "impact: $impact"
    [[ -n "$author" ]] && echo "author: $author"
    if [[ -n "$tags" ]]; then
        echo "tags: [${tags//,/, }]"
    fi
    if [[ -n "$dirs" ]]; then
        echo "dirs: [${dirs//,/, }]"
    fi
    # ap: only if pairs provided
    if [[ ${#ap_pairs[@]} -gt 0 ]]; then
        echo "ap:"
        for pair in "${ap_pairs[@]}"; do
            local key="${pair%%=*}"
            local val="${pair#*=}"
            echo "  $key: $val"
        done
    fi
    # note_id: only if pairs provided
    if [[ ${#note_id_pairs[@]} -gt 0 ]]; then
        echo "note_id:"
        for pair in "${note_id_pairs[@]}"; do
            local key="${pair%%=*}"
            local val="${pair#*=}"
            echo "  $key: $val"
        done
    fi
    echo "---"
    echo ""
} > "$file"
```

**Output:** Use `_file_to_jsonl "$file"` (same as before -- outputs JSON with id and full_path).

**Note on `--ap` and `--note-id` parsing:** These are repeatable flags. The arg parser accumulates them:

```bash
--ap) ap_pairs+=("$2"); shift 2 ;;
--note-id) note_id_pairs+=("$2"); shift 2 ;;
```

Each value must contain `=`. Validate: `[[ "$2" == *=* ]] || { echo "Error: --ap requires key=value format" >&2; return 1; }`

**Verification:** `./change_log create "Test entry" --impact 3` creates a file, prints JSONL. `./change_log create "No impact"` fails.

---

### Step 4: `_file_to_jsonl()` -- Awk Rewrite for New Fields

**Goal:** Handle the new field types (YAML maps `ap`, `note_id`; `desc` field; arrays `tags`, `dirs`).

This is the most complex piece. The current awk only handles single-line key-value pairs and arrays. Now it must also handle:
1. YAML map fields (`ap:` and `note_id:`) which are multi-line indented key-value blocks
2. The `desc` field which is a quoted string (already handled by existing string logic)
3. `impact` which is an integer (currently would be emitted as string -- acceptable for JSONL, but ideally as number)

**Awk rewrite strategy:**

The current awk reads frontmatter lines matching `^[a-zA-Z]` (top-level keys). For map fields, we need to also read indented lines (`^  `) that follow a map key.

**State machine additions:**

```
Current state: in_front && line starts with [a-zA-Z] => new field
New state:     in_front && line starts with "  " (2-space indent) => continuation of previous map field
```

**Pseudocode for the updated awk:**

```awk
BEGIN { FS=": "; in_front=0 }
FNR==1 {
    if (prev_file) emit()
    # Reset state
    field_count=0; in_front=0; in_map=0; map_key=""
    prev_file=FILENAME
}
/^---$/ {
    # End of map if we were in one
    if (in_map) { in_map=0; map_key="" }
    in_front = !in_front
    next
}
# Indented line (map continuation) while in frontmatter
in_front && /^  [a-zA-Z]/ {
    if (in_map && map_key != "") {
        # Parse "  key: value"
        line = $0
        sub(/^  /, "", line)
        k = line; sub(/:.*/, "", k)
        v = line; sub(/^[^:]+: */, "", v)
        # Append to map_data for this map_key
        map_pair_count[map_key]++
        idx = map_pair_count[map_key]
        map_pairs_k[map_key, idx] = k
        map_pairs_v[map_key, idx] = v
    }
    next
}
# Top-level field
in_front && /^[a-zA-Z]/ {
    # If we were in a map, close it
    if (in_map) { in_map=0; map_key="" }

    key = $1
    val = substr($0, length($1) + 3)
    gsub(/^ +| +$/, "", val)

    # Check if this is a map field (value is empty or just whitespace)
    if (val == "" || val ~ /^[[:space:]]*$/) {
        in_map = 1
        map_key = key
        field_count++
        field_keys[field_count] = key
        field_vals[field_count] = "__MAP__"
        map_pair_count[key] = 0
        next
    }

    field_count++
    field_keys[field_count] = key
    field_vals[field_count] = val
}
```

**Updated `emit()` function:**

The emit function needs three code paths for values:
1. **Array** (`[...]`): existing logic, output as JSON array of strings
2. **Map** (`__MAP__` sentinel): output as JSON object from `map_pairs_k` / `map_pairs_v`
3. **Scalar**: existing logic (strip quotes, output as JSON string). Special case: `impact` should be emitted as a JSON number (unquoted).

```awk
function emit(    i, key, val, n, j, items, mk, mv) {
    if (field_count > 0) {
        printf "{"
        first = 1
        for (i = 1; i <= field_count; i++) {
            if (!first) printf ","
            first = 0
            key = field_keys[i]
            val = field_vals[i]

            if (val == "__MAP__") {
                # Emit as JSON object
                printf "\"%s\":{", json_escape(key)
                for (j = 1; j <= map_pair_count[key]; j++) {
                    if (j > 1) printf ","
                    mk = map_pairs_k[key, j]
                    mv = map_pairs_v[key, j]
                    printf "\"%s\":\"%s\"", json_escape(mk), json_escape(mv)
                }
                printf "}"
            } else if (val ~ /^\[.*\]$/) {
                # Array (existing logic)
                gsub(/^\[|\]$/, "", val)
                n = split(val, items, ", *")
                printf "\"%s\":[", json_escape(key)
                for (j = 1; j <= n; j++) {
                    if (j > 1) printf ","
                    gsub(/^ +| +$/, "", items[j])
                    if (items[j] != "") printf "\"%s\"", json_escape(items[j])
                }
                printf "]"
            } else if (key == "impact") {
                # Numeric field
                if (val ~ /^".*"$/) val = substr(val, 2, length(val) - 2)
                printf "\"%s\":%s", json_escape(key), val
            } else {
                # Scalar string
                if (val ~ /^".*"$/) val = substr(val, 2, length(val) - 2)
                printf "\"%s\":\"%s\"", json_escape(key), json_escape(val)
            }
        }
        printf ",\"full_path\":\"%s\"", json_escape(prev_file)
        printf "}\n"
    }
    # Reset map state for next file
    delete map_pair_count
    delete map_pairs_k
    delete map_pairs_v
}
```

**Important:** The `json_escape` function stays the same. The `delete` statements in emit clear map state between files.

**Verification:** Create an entry with all fields (`--ap`, `--note-id`, `--desc`, `--tags`, `--dirs`) and run `./change_log query` to verify the JSONL output is valid JSON. Pipe through `jq .` to validate.

---

### Step 5: `cmd_ls()` -- Reverse Filename Sort with `--limit`

**Goal:** List entries most-recent-first (since filenames are timestamps, reverse alpha sort = most recent first), with `--limit=N`.

**Rewrite `cmd_ls()`:**

Remove old filters: `--status`, `-a/--assignee`, `-T/--tag`.

New flags: `--limit=N` (optional, defaults to showing all).

**Implementation approach:** Since filenames are `YYYY-MM-DD_HH-MM-SSZ.md`, reverse alphabetical filename sort gives most-recent-first. Use `ls -r` on the glob or pipe through `sort -r`.

```bash
cmd_ls() {
    local limit=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit=*) limit="${1#--limit=}"; shift ;;
            --limit) limit="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; return 1 ;;
        esac
    done

    local md_files
    md_files=("$CHANGE_LOG_DIR"/*.md)
    [[ ! -f "${md_files[0]}" ]] && return 0

    # Reverse sort (most recent first) -- filenames are timestamps
    local sorted_files
    sorted_files=$(printf '%s\n' "${md_files[@]}" | sort -r)

    # Apply limit
    if [[ -n "$limit" ]]; then
        sorted_files=$(echo "$sorted_files" | head -n "$limit")
    fi

    # Single awk pass over the selected files
    echo "$sorted_files" | xargs awk '
    BEGIN { FS=": "; in_front=0 }
    FNR==1 {
        if (prev_file) emit()
        id=""; title=""; impact=""; entry_type=""; in_front=0
        prev_file=FILENAME
    }
    /^---$/ { in_front = !in_front; next }
    in_front && /^id:/ { id = $2 }
    in_front && /^impact:/ { impact = $2 }
    in_front && /^type:/ { entry_type = $2 }
    in_front && /^title:/ { title = substr($0, 8); gsub(/^ +| +$/, "", title); if (title ~ /^".*"$/) title = substr(title, 2, length(title) - 2) }
    END { if (prev_file) emit() }
    function emit() {
        if (id != "") {
            printf "%-8s [I%s][%s] %s\n", id, impact, entry_type, title
        }
    }
    '
}
```

The output format: `<id-prefix>  [I<impact>][<type>] <title>`. This mirrors the old `[P<priority>][<status>]` pattern but with changelog-relevant fields.

**Note on `xargs awk` order:** The filenames are piped in reverse-sorted order to `xargs awk`. Since awk processes files in the order given, the output is automatically most-recent-first.

**Verification:** Create 3 entries (sleeping 1 second between each), run `./change_log ls` and verify reverse chronological order. Run `./change_log ls --limit=2` and verify only 2 shown.

---

### Step 6: `cmd_show()`, `cmd_edit()`, `cmd_add_note()`, `cmd_query()` Updates

**Goal:** Update the remaining commands for the new data model.

#### `cmd_show()` -- Simplify drastically

The current show uses a complex awk pass over ALL tickets to resolve deps/links/parents/blocking relationships. None of that exists in the changelog model.

**Rewrite to simply display the file content:**

```bash
cmd_show() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $(basename "$0") show <id>" >&2
        return 1
    fi

    local file
    file=$(entry_path "$1") || return 1

    if [[ -t 1 && -n "$CHANGE_LOG_PAGER" ]]; then
        read -r -a pager_cmd <<<"$CHANGE_LOG_PAGER"
        "${pager_cmd[@]}" "$file"
    else
        cat "$file"
    fi
}
```

This is dramatically simpler. Just cat the file (or page it). No awk needed.

#### `cmd_edit()` -- Minimal change

Just update the function name reference from `ticket_path` to `entry_path` and the usage text. The body stays the same.

#### `cmd_add_note()` -- Minimal change

Same as edit: update `ticket_path` -> `entry_path` and usage text references from "ticket" to "entry".

#### `cmd_query()` -- Update sort order

The current implementation uses `_file_to_jsonl "$TICKETS_DIR"/*.md`. We need most-recent-first ordering.

```bash
cmd_query() {
    local filter=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            *) filter="$1"; shift ;;
        esac
    done

    local md_files
    md_files=("$CHANGE_LOG_DIR"/*.md)
    [[ ! -f "${md_files[0]}" ]] && return 0

    # Reverse sort for most-recent-first
    local sorted_files
    sorted_files=$(printf '%s\n' "${md_files[@]}" | sort -r)

    local json_output
    json_output=$(echo "$sorted_files" | xargs -d '\n' _file_to_jsonl)

    if [[ -n "$filter" ]]; then
        echo "$json_output" | jq -c "select($filter)"
    else
        echo "$json_output"
    fi
}
```

**Note:** `xargs -d '\n'` ensures filenames with spaces work (unlikely with our timestamp format, but defensive).

**Verification:**
- `./change_log show <partial-id>` displays the entry
- `./change_log edit <partial-id>` opens in $EDITOR
- `./change_log add-note <partial-id> "test note"` appends a note
- `./change_log query` outputs valid JSONL in reverse chronological order
- `./change_log query '.impact > 3'` filters correctly (requires jq)

---

### Step 7: `cmd_help()` -- Complete Rewrite

**Goal:** Replace help text with changelog-appropriate content.

```
change_log - git-backed changelog for AI agents

Usage: change_log <command> [args]

Commands:
  create <title> [options]  Create changelog entry (prints JSON)
    --impact N              Impact level 1-5 (required)
    -t, --type TYPE         Type (feature|bug_fix|refactor|chore|breaking_change|docs|default) [default: default]
    --desc TEXT             Description text
    -a, --author NAME       Author [default: git user.name]
    --tags TAG,TAG,...      Comma-separated tags
    --dirs DIR,DIR,...      Comma-separated affected directories
    --ap KEY=VALUE          Anchor point (repeatable)
    --note-id KEY=VALUE     Note ID reference (repeatable)
  ls|list [--limit=N]       List entries (most recent first)
  show <id>                 Display entry (supports partial ID)
  edit <id>                 Open entry in $EDITOR
  add-note <id> [text]      Append timestamped note (text or stdin)
  query [jq-filter]         Output entries as JSONL (requires jq for filter)
  help                      Show this help

Entries stored as markdown in ./change_log/ (auto-created at git repo root)
Override directory with CHANGE_LOG_DIR env var
IDs stored in frontmatter; supports partial ID matching
```

Remove all plugin-related help text.

**Verification:** `./change_log help` shows the new text. No mention of tickets, plugins, status, deps, or links.

---

## `entry_path()` -- Updated Error Messages

Rename `ticket_path()` to `entry_path()`. The awk logic stays the same (search frontmatter `id:` fields for partial match). Update:
- Error messages: "ticket" -> "entry"
- Variable: `$TICKETS_DIR` -> `$CHANGE_LOG_DIR`
- Comment at the top of the function

---

## Functions to Keep As-Is

These utility functions need NO changes (they are generic):

| Function | Lines | Why keep |
|----------|-------|----------|
| `_grep()` | 61-65 | Portable grep wrapper |
| `_iso_date()` | 68-70 | Used for created_iso and notes |
| `_sed_i()` | 73-78 | Portable sed -i |
| `generate_id()` | 81-85 | 25-char random ID |
| `yaml_field()` | 176-180 | YAML field extraction |
| `update_yaml_field()` | 183-196 | YAML field update |
| `id_from_file()` | 120-122 | Extract id from frontmatter |

---

## Summary of Final Script Structure

After all steps, the `change_log` script will contain (in order):

1. Shebang and header comment
2. `find_change_log_dir()` -- directory discovery with auto-create
3. `CHANGE_LOG_PAGER` env var
4. `_grep()` -- portable grep
5. `_iso_date()` -- ISO timestamp
6. `_sed_i()` -- portable sed
7. `generate_id()` -- random ID
8. `timestamp_filename()` -- ISO8601 filename (**new**)
9. `id_from_file()` -- extract id from file
10. `ensure_dir()` -- mkdir safety
11. `entry_path()` -- partial ID resolution (renamed from `ticket_path`)
12. `yaml_field()` / `update_yaml_field()` -- YAML helpers
13. `_file_to_jsonl()` -- JSONL generator (**rewritten**)
14. `cmd_create()` -- create entry (**rewritten**)
15. `cmd_show()` -- display entry (**simplified**)
16. `cmd_edit()` -- open in editor (**minor update**)
17. `cmd_add_note()` -- append note (**minor update**)
18. `cmd_ls()` -- list entries (**rewritten**)
19. `cmd_query()` -- JSONL output (**updated sort**)
20. `cmd_help()` -- help text (**rewritten**)
21. Directory initialization (pre-dispatch)
22. Dispatch case statement (**gutted**)

**Estimated line count:** ~350-400 lines (down from 1593).

---

## Acceptance Criteria (Manual Testing Checklist)

Run these in order from a clean git repo:

```bash
# 1. Help works
./change_log help
# Expect: changelog help text, no mention of tickets/plugins

# 2. Create requires impact
./change_log create "Test"
# Expect: error about --impact required

# 3. Create validates impact range
./change_log create "Test" --impact 6
# Expect: error about valid range 1-5

# 4. Create validates type
./change_log create "Test" --impact 3 -t invalid
# Expect: error about valid types

# 5. Minimal create works
./change_log create "First change" --impact 2
# Expect: JSONL output with id and full_path
# Expect: file created at change_log/YYYY-MM-DD_HH-MM-SSZ.md

# 6. Create with all options
./change_log create "Full change" --impact 4 -t feature --desc "Full desc" \
    --tags auth,security --dirs src/auth,src/api \
    --ap handler=anchor_point.login --note-id design=resABC123
# Expect: file with all fields in frontmatter
# Expect: ap and note_id as YAML maps (indented under key)

# 7. Verify frontmatter content
cat change_log/*.md  # inspect both files

# 8. ls works (most recent first)
./change_log ls
# Expect: 2 entries, most recent first

# 9. ls --limit works
./change_log ls --limit=1
# Expect: only 1 entry

# 10. show works (use partial ID from ls output)
./change_log show <partial-id>
# Expect: full file content displayed

# 11. edit works
EDITOR=cat ./change_log edit <partial-id>
# Expect: file content printed (cat acts as editor)

# 12. add-note works
./change_log add-note <partial-id> "Additional context here"
# Expect: "Note added to <id>" message
# Verify: ## Notes section with timestamp in file

# 13. query works (JSONL)
./change_log query
# Expect: 2 JSONL lines, most recent first, valid JSON

# 14. query with desc field
./change_log query | jq '.desc'
# Expect: desc value for entry that has it, null/empty for one that doesn't

# 15. query with jq filter
./change_log query '.impact > 3'
# Expect: only the impact-4 entry

# 16. Unknown command
./change_log start abc
# Expect: "Unknown command: start" error

# 17. CHANGE_LOG_DIR override
CHANGE_LOG_DIR=/tmp/test_cl ./change_log create "Override test" --impact 1
# Expect: file created in /tmp/test_cl/

# 18. Auto-create at git root
cd /tmp && mkdir test_repo && cd test_repo && git init
# Run from a subdirectory
mkdir -p sub/dir && cd sub/dir
/path/to/change_log create "From subdir" --impact 1
# Expect: change_log/ created at /tmp/test_repo/change_log/
```

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Awk map parsing fails on edge cases | Keep map values simple (no colons in values). Validate `key=value` format on input. |
| Filename collision (two creates same second) | Sleep-and-retry approach. Sufficient for single-user CLI. |
| `xargs` portability with `sort -r` pipe | Use `printf '%s\n'` array expansion + `sort -r` which is portable POSIX. |
| `desc` field with quotes/special chars in JSONL | Existing `json_escape()` handles backslashes and double quotes. Test with special chars. |
