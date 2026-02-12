# PLANNER Private Context

## Status: COMPLETE

## Key Observations

### Change 1: Strip Partial ID Matching
- `entry_path()` at lines 87-130 uses a single awk pass that collects exact matches AND partial matches (substring via `index()`).
- Simplification: remove all partial match logic, keep only exact match. The awk script becomes much simpler.
- 8 test scenarios in `id_resolution.feature` -- need to keep: Exact ID match, Non-existent ID error. Remove: partial suffix/prefix/substring, ambiguous, exact-precedence, add-note-with-partial.
- Secondary test impacts: `changelog_show.feature` "Show with partial ID" (line 30-34), `changelog_edit.feature` "Edit with partial ID" (line 21-24), `changelog_notes.feature` "Add note with partial ID" (line 50-53) -- all need removal.
- Help text references: line 519 `show <id> Display entry (supports partial ID)` and the bottom of help text.
- README.md: two references to partial ID.
- CLAUDE.md: reference to partial ID in entry_path description.
- CHANGELOG.md: historical references (leave those, they describe past behavior).

### Change 2: Add `--details_in_md` Flag
- Currently, `cmd_create()` writes frontmatter then closes with `---` and a blank line (lines 335-373).
- The `--details_in_md` flag adds markdown body AFTER the closing `---`.
- `_file_to_jsonl()` only processes frontmatter (between `---` markers), so details are automatically excluded from JSONL output. No changes needed there.
- Help text needs: clarify title is concise, desc is short (both in query output), details are markdown body (NOT in query output).
- The `cmd_show()` function already uses `cat` to display the full file, so details will naturally be visible there.

### Implementation Simplicity
- The awk in `_file_to_jsonl()` already stops processing at the closing `---`, so body content after frontmatter is automatically excluded. This is the key insight -- no JSONL changes needed.
- For `entry_path()`, simplification is straightforward: remove `partial_count`/`partial_file` variables and the partial match conditions.
