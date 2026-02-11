# Exploration: Phase 01 Core Script Transformation

## Current Script: `ticket` (1593 lines)

### Key Functions to KEEP (modify)
- `generate_id()` - 25-char random ID (reuse as-is)
- `_grep()` - portable grep wrapper (reuse as-is)
- `_iso_date()` - ISO 8601 timestamp (reuse as-is)
- `_sed_i()` - portable sed (reuse as-is)
- `yaml_field()` / `update_yaml_field()` - YAML helpers (reuse as-is)
- `_file_to_jsonl()` - JSONL generator (needs significant update for new fields)
- `cmd_create()` - rewrite with new frontmatter
- `cmd_show()` - simplify (remove dep/link/blocking sections)
- `cmd_edit()` - update directory/ID resolution
- `cmd_ls()` - rewrite for most-recent-first, --limit
- `cmd_query()` - update for new fields
- `cmd_add_note()` - update directory/ID resolution
- `cmd_help()` - complete rewrite
- `ticket_path()` → `entry_path()` - ID resolution (update dir references)

### Functions to REMOVE
- `title_to_filename()` - replaced by timestamp filenames
- `init_tickets_dir()` - replaced by `find_change_log_dir()`
- `cmd_start()`, `cmd_close()`, `cmd_reopen()`, `cmd_status()` - status workflow
- `cmd_dep()`, `cmd_dep_tree()`, `cmd_dep_cycle()`, `cmd_undep()` - dependencies
- `cmd_link()`, `cmd_unlink()`, `cmd_add_link_to_file()`, `cmd_remove_link_from_file()` - links
- `cmd_ready()`, `cmd_blocked()`, `cmd_closed()` - status-based listings
- `cmd_super()` / plugin dispatch logic
- `_list_plugins()` - plugin listing

### Directory & Naming Changes
- `.tickets/` → `./change_log/`
- `TICKETS_DIR` → `CHANGE_LOG_DIR`
- `TICKET_PAGER` → `CHANGE_LOG_PAGER`
- `ticket_path()` → `entry_path()`
- `find_tickets_dir()` → `find_change_log_dir()` with auto-create at git root

### New Frontmatter Fields
```yaml
id: <25-char>
title: "..."
desc: "..." (optional)
created_iso: 2026-02-11T16:32:16Z
type: default (feature|bug_fix|refactor|chore|breaking_change|docs|default)
impact: 1-5 (REQUIRED)
author: <git user.name>
tags: [tag1, tag2] (optional)
dirs: [src/a, src/b] (optional)
ap: (optional, YAML map, omit if empty)
  handler: anchor_point.X
note_id: (optional, YAML map, omit if empty)
  design: resABC
```

### Removed Frontmatter Fields
- status, deps, links, priority, external-ref, parent

### Filename Format
- OLD: title-based slug (e.g., `my-task.md`)
- NEW: ISO8601 timestamp (e.g., `2026-02-11_16-32-16Z.md`)

### Dispatch (keep only)
- create, show, edit, ls/list, query, add-note, help

### Key Complexity: `_file_to_jsonl()` AWK
- Must handle new map types (`ap`, `note_id`) as JSON objects
- Must include `desc` field
- Must handle `dirs` as JSON array
- Most complex piece to update
