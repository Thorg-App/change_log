# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See @README.md for usage documentation. Run `change_log help` for command reference. Always update the README.md usage content when adding/changing commands and flags.

## Architecture

**Core script:** Single-file bash implementation (`change_log`, ~550 lines). Uses awk for performant bulk operations.

Key functions:
- `find_change_log_dir()` - Directory discovery: walks parents for `change_log/`, auto-creates at git root
- `generate_id()` - Creates 25-char random `[a-z0-9]` IDs (decoupled from filename)
- `timestamp_filename()` - Generates ISO8601 UTC filename stem (`YYYY-MM-DD_HH-MM-SSZ`)
- `entry_path()` - Resolves partial IDs by searching frontmatter `id:` fields (single awk pass)
- `id_from_file()` - Extracts `id:` from a file's YAML frontmatter
- `_file_to_jsonl()` - Shared awk-based JSONL generator (used by create and query)
- `yaml_field()` - YAML frontmatter field extraction via sed
- `_sorted_entries()` - Lists entry files most-recent-first (reverse filename sort)
- `cmd_*()` - Command handlers (create, show, edit, add_note, ls, query, help)

Data model: Filenames are ISO8601 timestamps (e.g., `2026-02-11_16-32-16Z.md`). The `id` field in frontmatter is the stable identifier. `title` is stored in frontmatter (double-quoted). Frontmatter fields: `id`, `title`, `desc`, `created_iso`, `type`, `impact`, `author`, `tags`, `dirs`, `ap`, `note_id`.

Dependencies: bash, sed, awk, find. Optional: ripgrep (faster grep), jq (for query filtering).

## Testing

BDD tests using [Behave](https://behave.readthedocs.io/). Run with `make test` (requires `uv`).

- Feature files: `features/*.feature` - Gherkin scenarios covering all commands
- Step definitions: `features/steps/changelog_steps.py`

When adding new commands or flags, add corresponding scenarios to the appropriate feature file.

## Changelog

Update CHANGELOG.md when committing notable changes:

- New commands, flags, bug fixes, behavior changes
- Add under appropriate heading (Added, Fixed, Changed, Removed)

### What Doesn't Need Logging
- Documentation-only changes
- Test-only changes (unless they reveal a bug fix)
