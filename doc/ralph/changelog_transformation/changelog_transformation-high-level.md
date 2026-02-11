# Changelog Transformation

## Problem Statement
The current `ticket` CLI is a git-backed issue tracker with dependency graphs, status workflows, and linking. We need to transform it into a **changelog system** (`change_log`) whose primary purpose is letting AI agents learn what recently changed, with a secondary goal of serving as a basis for release notes.

## Goals
- Replace the ticketing system with a streamlined changelog system
- Provide agents a fast way to query recent changes (by recency, type, directory, tags)
- Use ISO8601 timestamp filenames for natural chronological sorting

## Non-Goals (Out of Scope)
- Dependency tracking between entries
- Status workflows (open/closed/in_progress)
- Linking between entries
- Plugin system
- Package distribution (Homebrew, AUR)
- CI/CD workflows

## Solution Overview
Gut the `ticket` script, rename to `change_log`, and rebuild around a changelog data model. Storage moves from `.tickets/` to `./change_log/`. Filenames become ISO8601 timestamps (`2026-02-11_16-32-16Z.md`). Frontmatter is simplified to changelog-relevant fields with `impact` as a required field. All listing/query commands default to most-recent-first.

## User-Facing Behavior

- **Behavior: Create Entry**
  - GIVEN a `./change_log/` directory exists (or git repo root is discoverable)
  - WHEN `change_log create "Add auth" --impact 3`
  - THEN a file `YYYY-MM-DD_HH-MM-SSZ.md` is created in `./change_log/`
  - AND JSON `{"id":"...","full_path":"..."}` is printed to stdout

- **Behavior: Create Entry with All Options**
  - GIVEN a `./change_log/` directory exists
  - WHEN `change_log create "Add auth" --impact 3 -t feature --desc "Added OAuth2" --dirs src/auth,src/api --tags auth,security --ap handler=anchor_point.X --note-id design=resABC`
  - THEN frontmatter contains all specified fields with correct values

- **Behavior: Create Auto-Creates Directory**
  - GIVEN no `./change_log/` directory exists in any parent
  - AND the current directory is inside a git repository
  - WHEN `change_log create "First entry" --impact 1`
  - THEN `./change_log/` is created at the git repo root
  - AND the entry is created there

- **Behavior: Impact Required**
  - GIVEN a `./change_log/` directory exists
  - WHEN `change_log create "Title"` (no --impact)
  - THEN the command fails with an error indicating impact is required

- **Behavior: List Entries**
  - GIVEN multiple changelog entries exist
  - WHEN `change_log ls`
  - THEN entries are listed most-recent-first

- **Behavior: List with Limit**
  - GIVEN 10 changelog entries exist
  - WHEN `change_log ls --limit=3`
  - THEN only the 3 most recent entries are shown

- **Behavior: Show Entry**
  - GIVEN a changelog entry exists
  - WHEN `change_log show <id>` (supports partial ID)
  - THEN the full entry content is displayed

- **Behavior: Edit Entry**
  - GIVEN a changelog entry exists
  - WHEN `change_log edit <id>`
  - THEN the entry opens in `$EDITOR`

- **Behavior: Query as JSONL**
  - GIVEN multiple changelog entries exist
  - WHEN `change_log query`
  - THEN JSONL is output with all fields including `desc`, most-recent-first

- **Behavior: Query with jq Filter**
  - GIVEN changelog entries exist
  - WHEN `change_log query '.type == "feature"'`
  - THEN only matching entries are returned as JSONL

- **Behavior: Add Note**
  - GIVEN a changelog entry exists
  - WHEN `change_log add-note <id> "Additional context"`
  - THEN a timestamped note is appended to the entry body

- **Behavior: Help**
  - WHEN `change_log help`
  - THEN help text describes the changelog system (not a ticketing system)

- **Error: Invalid Impact Value**
  - WHEN `change_log create "Title" --impact 6`
  - THEN the command fails with an error about valid impact range (1-5)

- **Error: Unknown Command**
  - WHEN `change_log foo`
  - THEN a helpful error is shown suggesting `change_log help`

## Key Decisions
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Filename format | `YYYY-MM-DD_HH-MM-SSZ.md` | Sortable, no filesystem-problematic chars, human-readable |
| `impact` required | Yes, no default | Forces intentional classification of change significance |
| `type` default | `default` | Low-friction entry creation when type isn't clear |
| `ap`/`note_id` omitted when empty | Not written to frontmatter | Clean entries; avoid noise in YAML |
| `ap`/`note_id` shape | Always YAML map | Consistent structure: `key: value` pairs |
| Directory auto-create | At git repo root | Predictable location, works from any subdirectory |
| `desc` in query only | Not in `ls` output | Keeps `ls` scannable; `query` for machine consumption |
| Field rename | `created` → `created_iso` | Explicit about format |

## Key Types & Interfaces

| Type/Interface | Purpose | Location | Key Fields/Methods |
|----------------|---------|----------|-------------------|
| Frontmatter | Changelog entry metadata | YAML in each `.md` file | `id`, `title`, `desc`, `created_iso`, `type`, `impact`, `author`, `tags`, `dirs`, `ap`, `note_id` |

## Components / Architecture
Single bash script (`change_log`) with:
- `find_change_log_dir()` - Directory discovery with git-root auto-create
- `generate_id()` - 25-char random ID (unchanged)
- `timestamp_filename()` - ISO8601 timestamp → filename
- `entry_path()` - Partial ID resolution via awk
- `_file_to_jsonl()` - Awk-based JSONL generator for new fields
- `cmd_create()`, `cmd_show()`, `cmd_edit()`, `cmd_ls()`, `cmd_query()`, `cmd_add_note()` - Command handlers
- Simple case-statement dispatch (no plugin system)

## Approved Behavior Changes

| Existing Behavior | Approved Change | Approval Note |
|-------------------|-----------------|---------------|
| All ticketing behaviors | Complete replacement with changelog system | Engineer explicitly approved full transformation |
| `.tickets/` directory | Replaced by `./change_log/` | Confirmed |
| `ticket` command name | Replaced by `change_log` | Confirmed |
| Plugin dispatch system | Removed entirely | Confirmed |
| All status/dep/link commands | Removed entirely | Confirmed |
| `TICKETS_DIR` env var | Replaced by `CHANGE_LOG_DIR` | Confirmed |
| Filename: title-based slug | Replaced by ISO8601 timestamp | Confirmed |

## Success Criteria
- [ ] `change_log create` works with all specified fields and validates `impact` as required
- [ ] Filenames are ISO8601 timestamps in `YYYY-MM-DD_HH-MM-SSZ.md` format
- [ ] `ls` lists entries most-recent-first with `--limit` support
- [ ] `query` outputs JSONL with `desc`, most-recent-first
- [ ] `show`, `edit`, `add-note` work with partial ID resolution
- [ ] Directory auto-creates at git root when not found
- [ ] `help` clearly describes a changelog system
- [ ] No ticketing commands remain (status, dep, link, etc.)
- [ ] No plugin system code remains
- [ ] BDD tests cover all new behaviors
- [ ] Repo cleaned of dead files (plugins/, pkg/, scripts/, .github/, old ticket script)
- [ ] README.md and CLAUDE.md updated
- [ ] **INVARIANT**: Existing user-facing behaviors NOT listed in "Approved Behavior Changes" SHALL remain unchanged
- [ ] **INVARIANT**: Tests that solidify existing user behavior SHALL NOT be deleted or modified without explicit approval

## Phases Overview
| Phase | Name | Summary |
|-------|------|---------|
| 01 | core_script | Transform `ticket` → `change_log`: new data model, commands, directory structure |
| 02 | test_suite | Rewrite BDD tests for all changelog commands |
| 03 | repo_cleanup_and_docs | Remove dead files, update README.md, CLAUDE.md, CHANGELOG.md |

See individual task file(s) in `./tasks/` for details.

## Callouts

### Phase 01: core_script

| What | Why Called Out | Why It Was Done |
|------|---------------|-----------------|
| `_sed_i()` and `update_yaml_field()` removed | Dead code carried from `ticket` -- no `change_log` command modifies existing frontmatter | Identified by Pareto analysis, removed by DRY fixer to reduce maintenance surface |
| Pre-existing `json_escape()` double-escaping | Titles/descs with embedded double quotes produce `\\\"` in JSONL instead of `\"` | Inherited from original `ticket` script, not a regression; fixing requires awk rewrite beyond scope |
| Pre-existing unhelpful error on missing flag argument | `change_log create "Test" --impact` (no value) shows `$2: unbound variable` due to `set -u` | Inherited from original script; fails correctly (exit 1) but message is confusing; deferred |

### Phase 02: test_suite

- No callouts during 02_test_suite.md.

### Phase 03: repo_cleanup_and_docs

- No callouts during 03_repo_cleanup_and_docs.md.
