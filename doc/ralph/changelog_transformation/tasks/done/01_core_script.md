# Phase 01: Core Script Transformation

## Objective
Transform the `ticket` bash script into the `change_log` script with the new changelog data model, directory structure, filename format, and command set.

## Prerequisites
- None (first phase)

## Scope
### In Scope
- Copy `ticket` → `change_log` and transform in place
- Remove all dead code: `cmd_start`, `cmd_close`, `cmd_reopen`, `cmd_status`, `cmd_dep`, `cmd_undep`, `cmd_link`, `cmd_unlink`, `cmd_ready`, `cmd_blocked`, `cmd_closed`, plugin dispatch logic, `cmd_super`
- Remove helper functions only used by removed commands (dep tree rendering, cycle detection, link management, status updates)
- Rename directory: `.tickets/` → `./change_log/`
- Rename env var: `TICKETS_DIR` → `CHANGE_LOG_DIR`
- Update `find_change_log_dir()`: walk up parents looking for `./change_log/`; if not found, walk up to git repo root and **create** `./change_log/` there
- New filename format: `YYYY-MM-DD_HH-MM-SSZ.md` (ISO8601 UTC, dashes replacing colons)
- New frontmatter fields in `cmd_create()`:
  - `id` (25-char random, unchanged)
  - `title` (double-quoted, from positional arg)
  - `desc` (optional, `--desc "text"`)
  - `created_iso` (ISO8601 UTC: `2026-02-11T16:32:16Z`)
  - `type` (default: `default`, `-t/--type`, valid: `feature`, `bug_fix`, `refactor`, `chore`, `breaking_change`, `docs`, `default`)
  - `impact` (**required**, `--impact N`, valid: 1-5)
  - `author` (default: git user.name, `-a/--author`)
  - `tags` (optional, `--tags a,b,c` → YAML array)
  - `dirs` (optional, `--dirs src/a,src/b` → YAML array)
  - `ap` (optional, `--ap key=value`, repeatable → YAML map, **omit if not provided**)
  - `note_id` (optional, `--note-id key=value`, repeatable → YAML map, **omit if not provided**)
- Remove old create args: `--design`, `--acceptance`, `-p/--priority`, `--external-ref`, `--parent`
- Remove old frontmatter: `status`, `deps`, `links`, `priority`, `external-ref`, `parent`
- Update `cmd_show()`: display new fields, remove dep/link/blocking sections
- Update `cmd_edit()`: use new directory/ID resolution
- Update `cmd_add_note()`: use new directory/ID resolution
- Update `cmd_ls()`: most-recent-first (reverse filename sort), `--limit=N` flag, remove `--status`/`-a`/`-T` filters (or keep `-T` for tag filter if useful)
- Update `cmd_query()` / `_file_to_jsonl()`: include `desc` in JSONL, most-recent-first, handle new fields (dirs, ap, note_id as proper JSON)
- Update `cmd_help()`: rewrite help text for changelog context
- Update dispatch case statement: only `create`, `show`, `edit`, `ls`/`list`, `query`, `add-note`, `help`
- Partial ID resolution (`entry_path()`) still works via frontmatter `id:` field

### Out of Scope
- BDD tests (Phase 02)
- Removing old files from repo (Phase 03)
- Documentation updates (Phase 03)

## Implementation Guidance
- Start by copying `ticket` to `change_log`, then work on the copy
- Work top-down: first gut dead code, then modify remaining functions
- The `_file_to_jsonl()` awk function needs careful update for new fields (map types `ap` and `note_id` require special awk handling or simplification)
- For `ap`/`note_id` map fields in JSONL: output as JSON objects `{"key1":"val1","key2":"val2"}`
- `ls` can sort by filename (since filenames are timestamps, reverse alpha = most recent first)
- `query` similarly: `find` results sorted reverse by filename
- Validate `--impact` is 1-5 integer, fail with clear error if missing or invalid
- Validate `--type` against allowed list
- For directory auto-create: use `git rev-parse --show-toplevel` to find repo root

## Acceptance Criteria
- [ ] `change_log` script exists and is executable
- [ ] `change_log create "Title" --impact 3` creates `./change_log/YYYY-MM-DD_HH-MM-SSZ.md` with correct frontmatter
- [ ] `change_log create "Title"` (no --impact) fails with clear error
- [ ] `change_log create "Title" --impact 6` fails with clear error
- [ ] All optional fields (`--desc`, `--tags`, `--dirs`, `--ap`, `--note-id`) write correctly to frontmatter
- [ ] `ap` and `note_id` are omitted from frontmatter when not provided
- [ ] `change_log show <id>` displays an entry (partial ID supported)
- [ ] `change_log edit <id>` opens in $EDITOR
- [ ] `change_log ls` lists entries most-recent-first
- [ ] `change_log ls --limit=N` limits output
- [ ] `change_log query` outputs JSONL with all fields including `desc`, most-recent-first
- [ ] `change_log add-note <id> "text"` appends timestamped note
- [ ] `change_log help` shows changelog-appropriate help text
- [ ] No ticketing commands work (`change_log start` etc. → error)
- [ ] `CHANGE_LOG_DIR` env var overrides directory
- [ ] Auto-creates `./change_log/` at git repo root if not found

## Notes
- The existing `generate_id()` function can be reused as-is
- The `yaml_field()` and `update_yaml_field()` helpers are likely still useful
- The awk-based `_file_to_jsonl()` is the most complex piece to update due to new field types (maps)
- Keep the pager support for `show` command (`$PAGER` / `$CHANGE_LOG_PAGER`)
