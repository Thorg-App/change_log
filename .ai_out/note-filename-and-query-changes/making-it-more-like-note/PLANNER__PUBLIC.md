# Implementation Plan: Note-like Filename and Query Changes

## 1. Problem Understanding

### Goal
Transform the ticket system so that:
- Filenames are derived from the title (e.g., `my-note-title.md`) instead of the ID (e.g., `nt-a3x7.md`)
- The `id` field becomes a random 25-char alphanumeric string, decoupled from the filename
- Title lives in YAML frontmatter (not as `# heading` in body)
- `ticket_path()` resolves IDs by searching frontmatter, not by filename matching
- `create` outputs full JSON (not just the ID)
- `query` always includes `full_path` (remove `--include-full-path` flag)

### Key Constraints
- The `id` field in frontmatter is the authoritative identifier for all operations (deps, links, parent, etc.)
- All existing commands that take an ID argument must continue to work with partial matching
- Dependencies and links arrays store IDs (not filenames), so the stored format remains valid
- The `query` and `create` commands must NOT require `jq` (jq is optional for filtering)

### Assumptions
- The 25-char ID uses lowercase alphanumeric characters only (a-z, 0-9)
- Title-to-filename conversion: lowercase, spaces become hyphens, strip non-alphanumeric except hyphens, collapse multiple hyphens
- Duplicate filenames get numeric suffix: `-1`, `-2`, etc.
- Empty/missing title defaults to "Untitled" (filename: `untitled.md`)

## 2. High-Level Architecture

### Data Model Change (Before vs After)

**Before:**
```
File: .tickets/nt-a3x7.md
---
id: nt-a3x7          # id == filename stem
status: open
deps: []
---
# My Note Title       # title in body
```

**After:**
```
File: .tickets/my-note-title.md
---
id: abc123...xyz       # 25-char random, decoupled from filename
title: My Note Title   # title in frontmatter
status: open
deps: []
---
                       # no # heading in body
```

### Core Function Changes

```
generate_id()      -->  25-char random lowercase alphanumeric (no prefix)
title_to_filename() -->  NEW: converts title to slug, handles duplicates
id_from_file()     -->  NEW: extracts id from frontmatter (replaces basename pattern)
ticket_path()      -->  searches frontmatter id: fields instead of filename matching
cmd_create()       -->  writes title to frontmatter, uses title-based filename, outputs JSON
cmd_query()        -->  always includes full_path, title is auto-captured from frontmatter
7 awk scripts      -->  read title from frontmatter instead of body # heading
12 basename calls  -->  replaced with id_from_file() or yaml_field calls
```

### Data Flow

```
User runs: tk create "My Note Title"
  1. generate_id() -> "k7m2x..."  (25-char random)
  2. title_to_filename("My Note Title") -> "my-note-title" (or "my-note-title-1" if dup)
  3. Write file: .tickets/my-note-title.md with id: k7m2x..., title: My Note Title
  4. Run awk JSON generator on the single file
  5. Print JSONL to stdout

User runs: tk show k7m2x
  1. ticket_path("k7m2x") -> grep through .tickets/*.md for "id: " matching "k7m2x"
  2. Returns .tickets/my-note-title.md
  3. cmd_show renders the file
```

## 3. Implementation Phases

### Phase 1: New Helper Functions

**Goal**: Add the foundational functions without breaking existing behavior yet.

**Components Affected**: `/home/nickolaykondratyev/git_repos/note-ticket/ticket` (lines 80-132)

**Key Steps**:
1. Modify `generate_id()` to produce 25 random lowercase alphanumeric characters (no directory prefix)
2. Add `title_to_filename()` function that:
   - Converts title to lowercase
   - Replaces spaces with hyphens
   - Strips characters that are not `a-z`, `0-9`, or `-`
   - Collapses multiple consecutive hyphens
   - Trims leading/trailing hyphens
   - Falls back to "untitled" if result is empty
   - Checks for filename collisions and appends `-1`, `-2`, etc.
3. Add `id_from_file()` function that extracts `id:` from a file's YAML frontmatter using `yaml_field`

**Dependencies**: None

**Verification**: Unit test `title_to_filename` with various inputs including edge cases (special characters, all-spaces, empty, duplicates)

---

### Phase 2: Rewrite `ticket_path()` for Frontmatter-Based ID Resolution

**Goal**: Make ID resolution work by searching the `id:` field inside files rather than matching filenames.

**Components Affected**: `ticket_path()` function (lines 104-132)

**Key Steps**:
1. Replace the current filename-matching logic with a grep/awk-based approach:
   - First, try exact match: `grep -rl "^id: ${id}$" "$TICKETS_DIR"/*.md` (returns file where `id:` field exactly matches)
   - If no exact match, try partial match: scan all files for `id:` fields containing the search string
   - Handle ambiguous matches (multiple files match) with the same error message
   - Handle no matches with the same error message
2. The function signature and return value (file path) remain the same -- this is a drop-in replacement

**Implementation Approach (KISS)**:
```
ticket_path() {
    local search="$1"
    read -r search <<< "$search"  # trim whitespace

    # Exact match via grep through frontmatter
    local matches
    matches=$(awk -v search="$search" '
        FNR==1 { if (prev_file && id == search) { print prev_file; found++ }; id=""; in_front=0; prev_file=FILENAME }
        /^---$/ { in_front = !in_front; next }
        in_front && /^id:/ { id = substr($0, 5); gsub(/^ +| +$/, "", id) }
        END { if (prev_file && id == search) { print prev_file; found++ }; print found > "/dev/stderr" }
    ' "$TICKETS_DIR"/*.md 2>&1 >/dev/null)
    # ... (pseudocode - actual implementation will use a single awk pass for both exact and partial)
```

Actually, the simplest robust approach: **single awk pass** that collects all `id:` values mapped to filenames, then checks for exact match first, then partial match. This avoids multiple grep calls and handles all cases in one pass.

**Dependencies**: Phase 1 (id_from_file exists but ticket_path doesn't use it; ticket_path uses its own awk for efficiency)

**Verification**: All existing `id_resolution.feature` scenarios must pass (after updating test setup to use new file format)

---

### Phase 3: Update `cmd_create()` -- Title in Frontmatter, Title-based Filename, JSON Output

**Goal**: Create writes title to frontmatter, uses title-based filename, and outputs JSONL.

**Components Affected**: `cmd_create()` (lines 157-234)

**Key Steps**:
1. Generate title-based filename via `title_to_filename()`
2. Generate random 25-char ID via `generate_id()`
3. Write frontmatter with `title: "..."` field (after `id:`, before `status:`)
4. Do NOT write `# Title` heading in the body
5. After writing the file, generate JSONL output for the single created file using an awk one-liner (reuse the same awk logic from `cmd_query` but applied to a single file)
6. Print the JSONL line to stdout (always includes `full_path`)

**Design Decision: JSON output for create**:
- Extract the awk JSON-generation logic from `cmd_query()` into a function `_file_to_jsonl()` that takes a file path
- `cmd_create()` calls `_file_to_jsonl "$file"`
- `cmd_query()` calls the same logic on all files
- This avoids duplication (DRY) and ensures consistent JSON format

**Dependencies**: Phase 1, Phase 2

**Verification**: Create a ticket and verify JSON output contains id, title, full_path, and all standard fields

---

### Phase 4: Replace All `basename "$file" .md` Patterns with `id_from_file()`

**Goal**: Everywhere the code extracts an ID from a file path by stripping `.md`, replace with reading the `id:` field from frontmatter.

**Components Affected**: 12 locations across multiple functions

**Key Steps**:
1. `cmd_create()` line 187: `parent=$(yaml_field "$parent_file" "id")`
2. `cmd_status()` line 264: `echo "Updated $(id_from_file "$file") -> $status"`
3. `cmd_dep()` line 629: `dep_id=$(id_from_file "$dep_file")`
4. `cmd_dep()` line 650: `echo "Added dependency: $(id_from_file "$file") -> $dep_id"`
5. `cmd_undep()` line 950: `dep_id=$(id_from_file "$dep_file")`
6. `cmd_undep()` line 967: `echo "Removed dependency: $(id_from_file "$file") -/-> $dep_id"`
7. `cmd_link()` line 1003: `ids+=("$(id_from_file "$file")")`
8. `cmd_unlink()` line 1101: `id=$(id_from_file "$file")`
9. `cmd_unlink()` line 1102: `target_id=$(id_from_file "$target_file")`
10. `cmd_unlink()` line 1116: `echo "Removed link: $(id_from_file "$file") <-> $target_id"`
11. `cmd_show()` line 1128: `target_id=$(id_from_file "$file")`
12. `cmd_add_note()` line 1302: `echo "Note added to $(id_from_file "$file")"`

**Dependencies**: Phase 1 (id_from_file function)

**Verification**: All commands that output ticket IDs in messages should output the frontmatter `id:` value, not the filename stem

---

### Phase 5: Update All Awk Scripts to Read Title from Frontmatter

**Goal**: Change the 7 awk scripts that read title from `# heading` to read from `title:` frontmatter field.

**Components Affected**: awk blocks in `cmd_dep_tree`, `cmd_dep_cycle`, `cmd_ls`, `cmd_ready`, `cmd_closed`, `cmd_blocked`, `cmd_show`

**Key Steps**:
1. In each awk script, replace:
   ```awk
   !in_front && /^# / && title == "" { title = substr($0, 3) }
   ```
   with:
   ```awk
   in_front && /^title:/ { title = substr($0, 8); gsub(/^ +| +$/, "", title); gsub(/^"(.*)"$/, "\\1", title) }
   ```
   Note: The title value may or may not be quoted in frontmatter. The gsub handles both cases.

2. The 7 locations to update are at lines: 321, 505, 682, 729, 819, 866, 1146

**Dependencies**: Phase 3 (title is now in frontmatter)

**Verification**: `tk ls`, `tk ready`, `tk blocked`, `tk closed`, `tk show`, `tk dep tree`, `tk dep cycle` all display correct titles

---

### Phase 6: Update `cmd_query()` -- Always Include full_path, Title Auto-captured

**Goal**: Remove the `--include-full-path` flag and always include `full_path`. Since title is now a frontmatter field, it will be automatically captured by the existing awk logic.

**Components Affected**: `cmd_query()` (lines 1321-1384)

**Key Steps**:
1. Remove the `--include-full-path` flag parsing (line 1325)
2. Remove the `include_full_path` variable (line 1322)
3. In the awk script, always include `full_path` in output (remove the `if (include_path == 1)` conditional, line 1370-1372)
4. Remove the `-v include_path="$include_full_path"` from the awk invocation (line 1332)
5. Title will be automatically captured as a frontmatter field by the generic `in_front && /^[a-zA-Z]/` pattern (line 1340)

**Dependencies**: Phase 3 (title in frontmatter)

**Verification**: `tk query` output includes `full_path` and `title` for every ticket

---

### Phase 7: Update `cmd_help()` and README

**Goal**: Update help text and documentation to reflect new behavior.

**Components Affected**: `cmd_help()`, `/home/nickolaykondratyev/git_repos/note-ticket/README.md`

**Key Steps**:
1. In `cmd_help()`: Remove `--include-full-path` from query options
2. In `cmd_help()`: Update create description to mention JSON output
3. In `cmd_help()`: Update ID matching description (no longer filename-based)
4. In README: Update the Usage section with new `cmd_help()` output
5. In README: Update any examples that reference old ID format or `--include-full-path`

**Dependencies**: All previous phases

**Verification**: `tk help` output is accurate

---

### Phase 8: Update Test Infrastructure

**Goal**: Update the test helpers and step definitions to work with the new data model.

**Components Affected**:
- `/home/nickolaykondratyev/git_repos/note-ticket/features/steps/ticket_steps.py`
- `/home/nickolaykondratyev/git_repos/note-ticket/features/environment.py`

**Key Steps**:

1. **Update `create_ticket()` helper** (line 30-57):
   - Generate a title-based filename (same logic as the bash script): `title.lower().replace(' ', '-')` + strip non-alnum/hyphen
   - Write `title: {title}` in frontmatter
   - Do NOT write `# {title}` heading in body
   - Use `ticket_id` parameter as the `id:` frontmatter value (for test determinism)
   - Store the file path mapping in `context.tickets[ticket_id]`
   - Example output file `.tickets/test-ticket.md` with `id: abc-1234` in frontmatter

2. **Add `find_ticket_file()` helper**:
   - Given a ticket_id, search `.tickets/*.md` files for `id: {ticket_id}` in frontmatter
   - Returns the Path to the matching file
   - Used by all step definitions that currently construct path as `f'{ticket_id}.md'`

3. **Update all step definitions that access ticket files by ID**:
   - `step_ticket_has_status()` (line 103): Use `find_ticket_file()` or `context.tickets[ticket_id]`
   - `step_ticket_depends_on()` (line 112): Same
   - `step_ticket_linked_to()` (line 134): Same for both files
   - `step_ticket_has_notes()` (line 170): Same
   - `step_ticket_has_field_value()` (line 460): Same
   - `step_ticket_has_dep()` (line 473): Same
   - `step_ticket_not_has_dep()` (line 485): Same
   - `step_ticket_has_link()` (line 497): Same
   - `step_ticket_not_has_link()` (line 509): Same
   - `step_ticket_contains()` (line 521): Same
   - `step_ticket_has_timestamp_in_notes()` (line 529): Same

4. **Update `step_output_matches_id_pattern()`** (line 374):
   - Change pattern from `^[a-z0-9]+-[a-z0-9]{4}$` to match 25-char lowercase alphanumeric
   - Wait -- create no longer outputs just the ID. It outputs JSON. This step needs to change to validate JSON output instead.

5. **Update `step_run_command()`** (line 290):
   - The `last_created_id` extraction (line 325) must change: parse JSON output to extract `id` field
   - `context.last_created_id = json.loads(result.stdout.strip())['id']`

6. **Update `step_ticket_file_exists_with_title()`** (line 397):
   - Title is now in frontmatter, not body. Check for `title: {title}` or `title: "{title}"` instead of `# {title}`

7. **Update `step_created_ticket_contains()`** (line 424):
   - Must find ticket file by ID (from `context.last_created_id`) using `find_ticket_file()` or `context.tickets`

8. **Update `step_created_ticket_has_field()`** (line 433): Same file lookup change

9. **Update `step_created_ticket_has_timestamp()`** (line 447): Same file lookup change

10. **Update `step_separate_tickets_dir()`** (line 187):
    - Use title-based filename and title in frontmatter

**Dependencies**: Phase 3 (create outputs JSON), understanding of all previous phases

**Verification**: `make test` runs without import/setup errors (tests may still fail due to feature file changes)

---

### Phase 9: Update Feature Files

**Goal**: Update all `.feature` files to match new behavior.

**Components Affected**: All 12 feature files

**Key Steps**:

1. **`ticket_creation.feature`**:
   - "output should match a ticket ID pattern" -> change to validate JSON output (new step: "the output should be valid JSON with field X")
   - "a ticket file should exist with title X" -> now checks frontmatter for `title:` instead of body for `# X`
   - Add new scenarios:
     - Title-based filename generation (verify filename is `my-first-ticket.md`)
     - Duplicate filename handling (create two tickets with same title, verify `-1` suffix)
     - Title in frontmatter (verify `title:` field exists)
     - Create outputs JSON (verify JSON structure)
     - JSON output includes full_path
   - Remove/update scenarios that assert old ID pattern format

2. **`ticket_query.feature`**:
   - Remove "Query with --include-full-path" scenarios (lines 50-66)
   - Remove "Query without --include-full-path excludes file path" scenario (lines 68-72)
   - Add: "Query always includes full_path"
   - Add: "Query includes title field"
   - Update remaining scenarios as needed

3. **`id_resolution.feature`**:
   - The given steps create tickets with specific IDs like "abc-1234". These will now be in frontmatter, not filenames
   - The test setup (`create_ticket` helper) handles this
   - Scenarios should still work because `ticket_path()` now searches frontmatter
   - "Exact match takes precedence" scenario: Still valid since exact match on frontmatter `id:` field

4. **`ticket_status.feature`**:
   - Output messages like `"Updated test-0001 -> in_progress"` -- these should still work since we use `id_from_file()` which returns the frontmatter ID
   - The given step `create_ticket("test-0001", ...)` still puts `id: test-0001` in frontmatter

5. **`ticket_show.feature`**:
   - Line 14: `"# Test ticket"` -> change to `"title: Test ticket"` (title is now in frontmatter)
   - Line 76: `"# Parent ticket"` -> may need to be updated depending on show output format

6. **`ticket_edit.feature`**:
   - Line 14: `".tickets/edit-0001.md"` -> filename is now `editable-ticket.md` (based on title). Need to update expected filename or use a contains-pattern for the path

7. **`ticket_dependencies.feature`**: Likely no changes needed (IDs in deps are frontmatter IDs which haven't changed in test setup)

8. **`ticket_links.feature`**: Same as dependencies

9. **`ticket_notes.feature`**: Messages still reference ID from frontmatter

10. **`ticket_listing.feature`**: Title source changes but output format is the same

11. **`ticket_directory.feature`**:
    - "output should match a ticket ID pattern" needs updating (create outputs JSON now)
    - General create-related assertions need JSON awareness

12. **`ticket_plugins.feature`**:
    - "output should match a ticket ID pattern" needs updating (super create outputs JSON now)

**Dependencies**: Phase 8

**Verification**: `make test` -- all tests pass

---

## 4. Technical Considerations

### Performance: `ticket_path()` Frontmatter Search

The new `ticket_path()` must scan all `.md` files to find an ID match. For each invocation:
- **Best case**: Single awk pass through all files, O(n) where n = number of tickets
- **Typical usage**: Most repos have <500 tickets, so this is <50ms
- **Worst case**: Commands that call `ticket_path()` multiple times (e.g., `cmd_dep` calls it twice) will do 2 scans

This is acceptable for the 80/20 approach. If performance becomes an issue in the future, an index cache file could be introduced (but NOT now -- that would be over-engineering).

### Title Quoting in Frontmatter

The `title:` field in YAML frontmatter should handle titles with special characters:
- Titles with colons: `title: "My Title: Subtitle"` (must be quoted)
- Titles with quotes: `title: "She said \"hello\""` (must be escaped)

**KISS approach**: Always quote the title value in frontmatter to avoid YAML parsing issues. Use double quotes.

The awk reader should strip surrounding quotes: `gsub(/^"(.*)"$/, "\\1", title)`.

### JSON Output Consistency

The `_file_to_jsonl()` function must produce the same JSON structure whether called from `cmd_create()` (single file) or `cmd_query()` (all files). Both must include `full_path` and `title`.

### Edge Cases for Title-to-Filename

| Input | Output Filename |
|---|---|
| "My Note Title" | `my-note-title.md` |
| "Untitled" (default) | `untitled.md` |
| "" (empty) | `untitled.md` |
| "Fix bug #123" | `fix-bug-123.md` |
| "---" | `untitled.md` (all stripped) |
| "My Note Title" (duplicate) | `my-note-title-1.md` |
| "  Spaces  " | `spaces.md` |
| "ALL CAPS" | `all-caps.md` |

### Error Handling

- `ticket_path()` failure modes remain the same: "not found" and "ambiguous ID"
- `title_to_filename()` should never fail (always falls back to "untitled")
- `generate_id()` should never produce a duplicate in practice (25^25 = astronomically large space)

## 5. Testing Strategy

### New Scenarios Needed

**Title-based filename generation:**
- GIVEN a clean tickets directory / WHEN I create a ticket with title "My Test Ticket" / THEN a file named "my-test-ticket.md" should exist in .tickets/

**Duplicate filename handling:**
- GIVEN a ticket exists with title "Duplicate" / WHEN I create another ticket with title "Duplicate" / THEN a file named "duplicate-1.md" should exist

**Title in frontmatter:**
- WHEN I create a ticket with title "Frontmatter Title" / THEN the created ticket should have field "title" with value matching "Frontmatter Title"
- AND the ticket body should NOT contain "# Frontmatter Title"

**ID resolution via frontmatter:**
- GIVEN a ticket file named "my-note.md" with id "abc123def" in frontmatter / WHEN I run show with partial ID "abc123" / THEN it should succeed and show the ticket

**Create outputs JSON:**
- WHEN I create a ticket / THEN the output should be valid JSON
- AND the JSON should have field "id"
- AND the JSON should have field "title"
- AND the JSON should have field "full_path"
- AND the JSON should have field "status" with value "open"

**Query always includes full_path and title:**
- GIVEN a ticket exists / WHEN I run query / THEN every JSONL line should have "full_path" and "title"

### Existing Scenarios to Update

Every scenario that asserts `output should match a ticket ID pattern` must change to assert JSON output instead. Every scenario that checks `# Title` in ticket content must check `title: Title` in frontmatter instead.

### Key Integration Test Points

- Create a ticket, then resolve it by partial ID, then update its status -- end-to-end flow
- Create two tickets with the same title, verify both are accessible by their unique IDs
- Create a ticket, add a dependency using the ID, verify the dependency tree works

## 6. Open Questions / Decisions Needed

### #QUESTION_FOR_HUMAN: Title quoting strategy
Should the `title:` field in frontmatter always be quoted (e.g., `title: "My Title"`) or only when necessary (e.g., `title: My Title` but `title: "Title: With Colon"`)?

**Recommendation**: Always quote for consistency and safety. This avoids edge cases with YAML-special characters in titles.

### #QUESTION_FOR_HUMAN: Backward compatibility for existing tickets
If there are existing `.tickets/` directories with old-format files (id == filename, title in body), should we provide a migration path? Or is this a clean break?

**Recommendation**: Clean break. The `migrate-beads` command exists as precedent for migration tooling. A `migrate-v1` command could be added later if needed, but not in this PR.

### #QUESTION_FOR_HUMAN: ID length confirmation
The task says 25-char lowercase alphanumeric. Just confirming: this means `[a-z0-9]{25}` (not `[a-zA-Z0-9]{25}`)? This gives ~10^38 possible IDs which is more than sufficient.

### #QUESTION_FOR_HUMAN: What should `dep_id` store in deps array after resolution?
Currently `cmd_dep` resolves partial IDs via `ticket_path()` then extracts the full ID via `basename`. After the change, it will extract via `id_from_file()`. The full 25-char ID will be stored in deps arrays. This seems correct but wanted to confirm -- deps arrays should contain the full frontmatter `id:` value (the 25-char string)?

## 7. Phasing Summary

| Phase | Description | Risk | Effort |
|---|---|---|---|
| 1 | New helper functions | Low | Small |
| 2 | Rewrite ticket_path() | **High** (core function) | Medium |
| 3 | Update cmd_create() | Medium | Medium |
| 4 | Replace basename patterns | Medium (many locations) | Medium |
| 5 | Update awk title reading | Low (mechanical) | Small |
| 6 | Update cmd_query() | Low | Small |
| 7 | Update help/docs | Low | Small |
| 8 | Update test infrastructure | **High** (many changes) | Large |
| 9 | Update feature files | Medium | Large |

**Recommended implementation order**: Phases 1-7 (script changes), then Phase 8-9 (test changes). This allows running manual smoke tests between phases.

**Commit strategy**: One commit per phase, or group Phases 1-2, 3-6, 7, 8-9. The implementor should use judgment based on the natural breakpoints.
