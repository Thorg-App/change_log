# Changelog

## [Unreleased]

### Added
- `--details_in_md` flag for `create` command -- adds markdown body content visible via `show` but excluded from `query` JSONL output

### Removed
- Partial ID matching -- `show`, `edit`, `add-note` now require exact IDs

### Changed
- Clarified help text: `--desc` is short description (in query output), `--details_in_md` is markdown body (not in query output)
- **BREAKING**: Complete transformation from ticket system (`tk`) to changelog system (`change_log`)
- Storage directory changed from `.tickets/` to `./.change_log/`
- Environment variable changed from `TICKETS_DIR` to `CHANGE_LOG_DIR`
- Pager variable changed from `TICKET_PAGER` to `CHANGE_LOG_PAGER`
- Filenames changed from title-based slugs to ISO8601 timestamps (`YYYY-MM-DD_HH-MM-SSZ.md`)
- `create` command now requires `--impact` (1-5) instead of `--priority` (0-4)
- Entry types changed to: feature, bug_fix, refactor, chore, breaking_change, docs, default
- `create` outputs JSON (single line) instead of JSONL
- `ls` output format changed to show impact and type: `ID [I3][feature] Title`

### Added
- `--impact` flag (required, 1-5) for classifying change significance
- `--desc` flag for entry description (included in query JSONL output)
- `--dirs` flag for affected directories
- `--ap` flag for anchor point references (repeatable, key=value)
- `--note-id` flag for note ID references (repeatable, key=value)
- `created_iso` frontmatter field (explicit ISO8601 format)

### Removed
- All ticket commands: `start`, `close`, `reopen`, `status`, `dep`, `undep`, `link`, `unlink`, `ready`, `blocked`, `closed`
- Plugin system (`tk-*`/`ticket-*` external command dispatch, `super` command)
- Dependency tracking, status workflows, linking between entries
- `--priority`, `--design`, `--acceptance`, `--external-ref`, `--parent` create flags
- `--assignee` filter flag (replaced by `--author` on create only)
- `-T`/`--tag` filter flag on listing commands
- `--status` filter flag on `ls`
- Homebrew and AUR packaging (scripts, PKGBUILDs, CI workflows)
- GitHub Actions workflows

## [0.3.2] - 2026-02-03

### Fixed
- Ticket ID lookup now trims leading/trailing whitespace (fixes issue with AI agents passing extra spaces)

## [0.3.1] - 2026-01-28

### Added
- `list` command alias for `ls`
- `TICKET_PAGER` environment variable for `show` command (only when stdout is a TTY; falls back to `PAGER`)

### Changed
- Walk parent directories to find `.tickets/` directory, enabling commands from any subdirectory
- Ticket ID suffix now uses full alphanumeric (a-z0-9) instead of hex for increased entropy

### Fixed
- `dep` command now resolves partial IDs for the dependency argument
- `undep` command now resolves partial IDs and validates dependency exists
- `unlink` command now resolves partial IDs for both arguments
- `create --parent` now validates and resolves parent ticket ID
- `generate_id` now uses 3-char prefix for single-segment directory names (e.g., "plan" → "pla" instead of "p")

## [0.3.0] - 2026-01-18

### Added
- Support `TICKETS_DIR` environment variable for custom tickets directory location
- `dep cycle` command to detect dependency cycles in open tickets
- `add-note` command for appending timestamped notes to tickets
- `-a, --assignee` filter flag for `ls`, `ready`, `blocked`, and `closed` commands
- `--tags` flag for `create` command to add comma-separated tags
- `-T, --tag` filter flag for `ls`, `ready`, `blocked`, and `closed` commands

## [0.2.0] - 2026-01-04

### Added
- `--parent` flag for `create` command to set parent ticket
- `link`/`unlink` commands for symmetric ticket relationships
- `show` command displays parent title and linked tickets

## [0.1.1] - 2026-01-02

### Fixed
- `edit` command no longer hangs when run in non-TTY environments

## [0.1.0] - 2026-01-02

Initial release.
