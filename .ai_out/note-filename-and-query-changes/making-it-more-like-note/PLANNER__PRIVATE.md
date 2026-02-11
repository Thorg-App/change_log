# Planner Private Context

## Analysis Complete: 2026-02-11

### Key Findings

**Scope of Impact**: This is a FUNDAMENTAL change to the data model. The current system assumes id == filename stem everywhere. There are 12 locations using `basename "$file" .md` to extract ID from filename.

### Critical Observation: `basename` usage as ID extraction

The following places use `basename "$file" .md` to get the ticket ID from the file path:
1. `cmd_create()` line 187 - parent resolution
2. `cmd_status()` line 264 - status update message
3. `cmd_dep()` line 629 - dep_id resolution
4. `cmd_dep()` line 650 - status message
5. `cmd_undep()` line 950 - dep_id resolution
6. `cmd_undep()` line 967 - status message
7. `cmd_link()` line 1003 - id extraction for link operations
8. `cmd_unlink()` line 1101-1102 - id and target_id extraction
9. `cmd_unlink()` line 1116 - status message
10. `cmd_show()` line 1128 - target_id extraction
11. `cmd_add_note()` line 1302 - status message

### Critical Observation: awk scripts read title from body

7 locations use `!in_front && /^# / && title == "" { title = substr($0, 3) }`:
- cmd_dep_tree (line 321)
- cmd_dep_cycle (line 505)
- cmd_ls (line 682)
- cmd_ready (line 729)
- cmd_closed (line 819)
- cmd_blocked (line 866)
- cmd_show (line 1146)

### Critical Observation: ticket_path() resolution approach

Current: filename match
New: must scan frontmatter `id:` field

**Performance consideration**: For a small-medium ticket set (<1000), grepping through files is fine. For large sets, could cache. PARETO says: simple grep approach first.

**Approach Options for ticket_path():**
1. **grep through all files for id: field** - Simple, uses existing `_grep`. O(n) per lookup.
2. **awk scan of all .md files** - More overhead per call but can handle partial matching.
3. **Build an index file** - Complex, violates KISS.

Recommendation: Option 1 with `_grep` for exact match, fall back to awk for partial match.

### Critical Observation: Dependencies/links store IDs, not filenames

The deps and links arrays in frontmatter store IDs like `[task-0001, task-0002]`. Since the ID format is changing from short prefix-hash to 25-char random string, existing deps/links references remain valid as long as they use the frontmatter `id:` value, not the filename.

This means `cmd_dep()` line 629 `dep_id=$(basename "$dep_file" .md)` is WRONG after the change. It should extract the id from frontmatter instead.

### Critical Observation: Test file setup writes files directly

`create_ticket()` in step definitions creates files with `ticket_id` as both the filename stem AND the `id:` frontmatter field. After the change, this helper must:
1. Generate a title-based filename
2. Use the provided ticket_id as the frontmatter `id:` field
3. Store the mapping so tests can still find files by ID

### Design Decision: How to extract ID from file path

Need a helper function: `id_from_file()` that reads the `id:` field from a file's frontmatter. Used in place of `basename "$file" .md`.

```bash
id_from_file() {
    yaml_field "$1" "id"
}
```

### Design Decision: Title-to-filename conversion

```bash
title_to_filename() {
    local title="$1"
    # lowercase, replace spaces with hyphens, strip non-alphanumeric/hyphen
    local base
    base=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
    [[ -z "$base" ]] && base="untitled"

    # Check for duplicates
    local file="$TICKETS_DIR/${base}.md"
    if [[ ! -f "$file" ]]; then
        echo "$base"
        return
    fi

    local i=1
    while [[ -f "$TICKETS_DIR/${base}-${i}.md" ]]; do
        ((i++))
    done
    echo "${base}-${i}"
}
```

### Design Decision: create prints JSON

cmd_create() needs to output JSONL instead of just the ID. Since the query awk script exists, we could:
1. Call cmd_query() after creating the file with a filter for the new ID
2. Construct JSON manually in bash (fragile)
3. Use a small awk one-liner on the single file

Option 1 is cleanest (DRY - reuses existing JSON generation), but cmd_query reads ALL files. For a single ticket, option 3 is better performance-wise. However, PARETO says option 1 is simplest and sufficient until performance becomes an issue.

Actually, the simplest approach: after writing the file, run cmd_query with a jq filter for the new id. But this requires jq. The create command should NOT require jq.

Better approach: extract the awk JSON-generation logic into a reusable function that can operate on a single file or all files. Or just run the awk on the single file.

### Test Impact Summary

**Features that need modification:**
- `ticket_creation.feature` - Major rewrites (new output format, title in frontmatter, filename format)
- `ticket_query.feature` - Remove --include-full-path tests, add always-has-full-path tests, add title field tests
- `id_resolution.feature` - Major rewrites (ID resolution now searches frontmatter, not filenames)
- `ticket_status.feature` - Messages reference filename, not ID anymore... wait, they should still reference ID
- `ticket_dependencies.feature` - dep_id resolution changes
- `ticket_show.feature` - Title in frontmatter not body
- `ticket_edit.feature` - Filename changes
- `ticket_notes.feature` - Messages reference ID from frontmatter
- `ticket_links.feature` - ID resolution changes
- `ticket_listing.feature` - Title source changes
- `ticket_directory.feature` - Filename changes
- `ticket_plugins.feature` - create output changes

**Step definitions that need modification:**
- `create_ticket()` - filename generation, title in frontmatter
- `step_ticket_has_status()` - find file by ID in frontmatter, not filename
- `step_ticket_depends_on()` - find file by ID in frontmatter
- `step_ticket_linked_to()` - find file by ID in frontmatter
- `step_ticket_has_notes()` - find file by ID in frontmatter
- `step_output_matches_id_pattern()` - ID is now 25-char string
- `step_ticket_file_exists_with_title()` - title is in frontmatter, not body
- Many `then` steps that access files via `f'{ticket_id}.md'`
