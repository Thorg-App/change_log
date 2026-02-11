# Plan Review

## Executive Summary

The plan is thorough, well-phased, and correctly identifies the highest-risk areas. The overall architecture is sound. I found two issues that need clarification before implementation (one in the `ticket_path()` specification, one in scope of `migrate-beads`), and several minor gaps in test coverage and feature file analysis. None of these are architectural blockers -- the plan can proceed with minor inline fixes.

## Critical Issues (BLOCKERS)

None.

## Major Concerns

### 1. `ticket_path()` specification is unfinished

- **Concern:** Phase 2 starts with a grep-based approach, then pivots mid-paragraph to "Actually, the simplest robust approach: single awk pass." The pseudocode at lines 130-136 of the plan is left incomplete and contradicts the final stated approach. The implementor needs ONE clear specification, not a narrative of the planner's thinking process.
- **Why:** This is the highest-risk function in the entire codebase. An ambiguous spec here will cause implementation confusion.
- **Suggestion:** Replace the Phase 2 implementation section with a single, clean specification. The final approach (single awk pass collecting all id-to-filename mappings, then checking exact match first, then partial match) is correct. Remove the grep-based approach and the incomplete pseudocode. Provide clean pseudocode like:

```
ticket_path(search):
  Single awk pass over $TICKETS_DIR/*.md:
    - For each file, extract "id:" from frontmatter
    - If id == search exactly: record as exact_match
    - If id contains search as substring: record as partial_match
  If exactly 1 exact_match: return it
  If 0 exact, exactly 1 partial: return it
  If 0 exact, >1 partial: error "ambiguous ID"
  If 0 exact, 0 partial: error "not found"
```

### 2. `migrate-beads` scope not addressed

- **Concern:** The plan does not mention `cmd_migrate_beads()` at all. This function (lines 1386-1441 in `/home/nickolaykondratyev/git_repos/note-ticket/ticket`) writes old-format files: filename = `{id}.md`, title as `# heading` in body, no `title:` in frontmatter.
- **Why:** After the changes, a user running `tk migrate-beads` would produce files that are incompatible with the new format. Since this is a "clean break" (per resolved questions), the implementor needs to know: update migrate-beads or explicitly leave it broken?
- **Suggestion:** Add a note to Phase 7 or create a small Phase 7.5: update `cmd_migrate_beads()` to write new-format files (title in frontmatter, title-based filename, 25-char random ID). OR explicitly state it's out of scope and file a follow-up ticket. Either way, the plan must be explicit.

## Simplification Opportunities (PARETO)

### 1. Phase 4 could be partially merged with Phase 2

The 12 `basename "$file" .md` replacements (Phase 4) are low-risk mechanical changes. Since `id_from_file()` is created in Phase 1, these could be done alongside Phase 2 to reduce the "broken intermediate state" window. Not a blocker, just a suggestion for the implementor's discretion.

### 2. No need for `id_from_file()` as a separate function

`id_from_file()` is defined as a wrapper around `yaml_field "$file" "id"`. Unless there is additional logic (trimming, validation), this is a one-liner alias. Consider whether the indirection adds clarity or just adds a function to maintain. The plan's Phase 4 already shows some callsites using `yaml_field "$file" "id"` directly (e.g., line 180: `parent=$(yaml_field "$parent_file" "id")`). Pick one approach and be consistent.

- **Value:** One fewer function to maintain, no DRY violation since `yaml_field` is already a general utility.

## Minor Suggestions

### A. Awk `FS=": "` and quoted title values

The plan correctly proposes `title = substr($0, 8); gsub(/^ +| +$/, "", title); gsub(/^"(.*)"$/, "\\1", title)` for reading titles in awk. This is correct because `substr($0, 8)` operates on the raw line, avoiding the `FS=": "` splitting that would truncate titles containing `: `. However, the plan should explicitly warn implementors: DO NOT use `$2` for extracting title values, as `FS=": "` will split on colons within the title. The `id` field extraction using `$2` is safe because IDs are alphanumeric-only.

### B. Title regex: off-by-one on substr offset

`title: "My Title"` -- the `title:` prefix is 6 characters, then a space = 7 characters. So `substr($0, 8)` is correct (awk substr is 1-indexed). Good.

However, consider: `title:  "My Title"` (double space after colon). The plan's `gsub(/^ +| +$/, "", title)` handles this correctly by trimming leading spaces. Good.

### C. Feature file changes the plan missed

1. **`/home/nickolaykondratyev/git_repos/note-ticket/features/ticket_show.feature` line 76**: `And the output should contain "# Parent ticket"`. After the change, `cmd_show` outputs the raw file content via `getline`. If the file no longer has `# Parent ticket` in the body (title moved to frontmatter), this assertion must change to `title: "Parent ticket"` or similar. The plan mentions this at Phase 9 Step 5 for line 14 but does not explicitly call out line 76.

2. **`/home/nickolaykondratyev/git_repos/note-ticket/features/ticket_notes.feature`**: Output messages like `"Note added to note-0001"` rely on `basename "$file" .md`. After the change, `cmd_add_note()` will use `id_from_file()` per Phase 4 Step 12. The test IDs in the Background step are `note-0001`, which will be in the frontmatter `id:` field. So the output message will correctly say `"Note added to note-0001"`. No change needed. Good.

3. **`/home/nickolaykondratyev/git_repos/note-ticket/features/ticket_edit.feature` line 14**: `And the output should contain ".tickets/edit-0001.md"`. After the change, the filename will be based on the title `"Editable ticket"`, so the file will be `.tickets/editable-ticket.md`. The plan mentions this (Phase 9 Step 6) but should specify the exact expected filename. This is important because the test is checking a specific path string.

4. **`/home/nickolaykondratyev/git_repos/note-ticket/features/ticket_dependencies.feature` line 15**: `And the output should be "Added dependency: task-0001 -> task-0002"`. This depends on `basename "$file" .md` -> Phase 4 changes it to `id_from_file()`. The test's `create_ticket()` helper sets `id: task-0001` in frontmatter, so the output remains `"Added dependency: task-0001 -> task-0002"`. No feature file change needed. Correct.

5. **`/home/nickolaykondratyev/git_repos/note-ticket/features/ticket_plugins.feature`**: Three scenarios use `the output should match a ticket ID pattern` (lines 36, 70, 77). The plan mentions lines 36 and 70 at Phase 9 Step 12 but misses line 77 ("Built-in commands still work with plugins present"). All three need updating.

### D. Test helper `create_ticket()` title-to-filename logic

The plan says the Python helper should replicate the bash `title_to_filename()` logic. This introduces a DRY violation across languages (bash function + Python function doing the same transformation). Consider an alternative: have the test helper use a fixed/deterministic filename (e.g., based on the test `ticket_id` parameter itself: `f'{ticket_id}.md'`... wait, that reverts to the old approach).

Better alternative: since tests use `create_ticket()` to set up state directly (bypassing `cmd_create()`), the filename can be anything as long as the frontmatter `id:` is correct. Use a simple slug: `ticket_id.replace('-', '-')` + `.md` or just `title.lower().replace(' ', '-') + '.md'` with minimal sanitization. The key insight is that tests don't care about filename correctness for the *setup* helper -- they care about the *production code* producing correct filenames. Only the `cmd_create()` integration tests need to validate filename generation.

### E. `step_ticket_has_status()` and similar steps construct file paths as `f'{ticket_id}.md'`

The plan correctly identifies this at Phase 8 Step 3 and proposes a `find_ticket_file()` helper. A simpler approach: since `create_ticket()` stores `context.tickets[ticket_id] = ticket_path`, just use `context.tickets[ticket_id]` in all step definitions. This avoids the grep-through-files approach entirely and is faster. The plan already mentions this as an option at Phase 8 Step 6 ("or `context.tickets[ticket_id]`") but should commit to ONE approach.

**Recommendation:** Use `context.tickets[ticket_id]` as the primary lookup. Add `find_ticket_file()` only as a fallback for cases where the ticket was created by `cmd_create()` (not the helper). In those cases, parse the JSON output to get `full_path` directly and store it in `context.tickets`.

## Strengths

1. **Phasing is well thought out.** Dependencies between phases are correctly identified. The highest-risk change (ticket_path) is isolated in its own phase.

2. **DRY via `_file_to_jsonl()`** is the right call. Extracting the awk JSON-generation logic ensures create and query produce identical JSON structure.

3. **Edge case table for title-to-filename** (Section 4) is comprehensive and practical.

4. **The plan correctly identifies all 7 awk title-reading locations and all 12 basename-to-id_from_file locations.** I verified these against the source code and the counts are accurate.

5. **Performance analysis is pragmatic.** Acknowledging the O(n) scan for ticket_path is acceptable for <500 tickets without over-engineering an index cache is exactly the right 80/20 call.

6. **All four resolved questions are properly incorporated** into the plan (always-quote titles, clean break, lowercase-only IDs, full 25-char deps).

## Verdict

- [ ] APPROVED
- [x] APPROVED WITH MINOR REVISIONS
- [ ] NEEDS REVISION
- [ ] REJECTED

### Required Revisions (can be done inline by IMPLEMENTOR):

1. **Clean up Phase 2 `ticket_path()` specification**: Remove the incomplete pseudocode and the "actually..." pivot. Provide one clean specification using the single-awk-pass approach.

2. **Add explicit scope decision for `cmd_migrate_beads()`**: Either add it to Phase 7 or explicitly state "out of scope, will produce old-format files until updated separately."

3. **Fix Phase 9 Step 12 to include the third `ticket_plugins.feature` scenario** (line 77: "Built-in commands still work with plugins present").

4. **Commit to one approach for test file lookups**: Use `context.tickets[ticket_id]` consistently, with JSON parsing for `cmd_create()` outputs.

### PLAN_ITERATION: NOT REQUIRED

These are all minor clarifications that the implementor can resolve inline. No architectural changes needed.
