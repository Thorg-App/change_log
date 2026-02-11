# Exploration Report: Test Suite Transformation for `change_log`

This document provides a comprehensive analysis of the `change_log` script, the existing test infrastructure built for the old `ticket` script, and a gap analysis identifying what must change to create a test suite that exercises `change_log`.

---

## A. `change_log` Script Analysis

### A.1 Commands

| Command | Function | Description |
|---------|----------|-------------|
| `create [title] [options]` | `cmd_create` | Creates a changelog entry file, prints JSONL |
| `ls` / `list [--limit=N]` | `cmd_ls` | Lists entries most-recent-first (sorted by filename descending) |
| `show <id>` | `cmd_show` | Displays full entry content (uses pager if TTY + CHANGE_LOG_PAGER set) |
| `edit <id>` | `cmd_edit` | Opens entry in `$EDITOR` (non-TTY: prints file path) |
| `add-note <id> [text]` | `cmd_add_note` | Appends timestamped note to entry (text arg or stdin) |
| `query [jq-filter]` | `cmd_query` | Outputs entries as JSONL, optional jq filter |
| `help` / `--help` / `-h` | `cmd_help` | Prints usage |

### A.2 Create Command Flags

| Flag | Short | Argument | Default | Notes |
|------|-------|----------|---------|-------|
| `--impact` | - | N (1-5) | **none (required)** | Validation: must be integer 1-5 |
| `--type` | `-t` | TYPE | `default` | Validated against `VALID_TYPES` |
| `--desc` | - | TEXT | empty | Double-quoted in frontmatter |
| `--author` | `-a` | NAME | `git config user.name` | Optional |
| `--tags` | - | TAG,TAG,... | empty | Stored as YAML array `[tag1, tag2]` |
| `--dirs` | - | DIR,DIR,... | empty | Stored as YAML array `[dir1, dir2]` |
| `--ap` | - | KEY=VALUE | empty | Repeatable. Stored as YAML map. Omitted entirely when no pairs given |
| `--note-id` | - | KEY=VALUE | empty | Repeatable. Stored as YAML map. Omitted entirely when no pairs given |

### A.3 Valid Types

```
feature bug_fix refactor chore breaking_change docs default
```

Type validation: if not in this list, prints error and returns 1.

### A.4 Frontmatter Fields (create output)

Generated frontmatter for a fully-specified entry:

```yaml
---
id: <25-char random alphanumeric>
title: "<escaped title>"
desc: "<escaped description>"          # only if --desc provided
created_iso: 2024-01-01T00:00:00Z
type: <type>
impact: <1-5>
author: <author>                       # only if non-empty
tags: [tag1, tag2]                     # only if --tags provided
dirs: [dir1, dir2]                     # only if --dirs provided
ap:                                    # only if --ap provided
  key1: value1
note_id:                               # only if --note-id provided
  key1: value1
---
```

Key differences from old `ticket` script:
- **No `status` field** - entries are immutable records, not workflow items
- **No `deps` field** - no dependency tracking
- **No `links` field** - no link tracking
- **No `priority` field** - replaced by `impact` (1-5, required)
- **No `parent` field** - no hierarchy
- **No `assignee` field** - replaced by `author`
- **No `external-ref` field**
- **New `desc` field** - description in frontmatter
- **New `created_iso` field** - renamed from `created`
- **New `impact` field** - required, numeric 1-5
- **New `tags` field** - YAML array
- **New `dirs` field** - YAML array
- **New `ap` field** - YAML map (optional, omitted when empty)
- **New `note_id` field** - YAML map (optional, omitted when empty)

### A.5 Filename Generation

- Filenames are **timestamp-based**: `YYYY-MM-DD_HH-MM-SSZ.md` (from `timestamp_filename()`)
- **Not title-based** (unlike old `ticket` which used slug filenames like `my-ticket.md`)
- Collision handling: if file already exists, `sleep 1` and regenerate timestamp

### A.6 Listing Format

`cmd_ls` output format per entry:
```
<8-char-id> [I<impact>][<type>] <title>
```
Example: `abc12345 [I3][feature] My change`

- No `--status` filter (no status field exists)
- `--limit=N` flag supported
- Sorted by filename descending (most recent first)

### A.7 Directory Discovery

Function `find_change_log_dir()` precedence:
1. `CHANGE_LOG_DIR` env var (if set)
2. Walk parent directories looking for `change_log/` directory
3. Auto-create `change_log/` at git repo root
4. Error if not in a git repo

Key naming differences from old `ticket`:
- Directory: `change_log/` (not `.tickets/`)
- Env var: `CHANGE_LOG_DIR` (not `TICKETS_DIR`)
- Script name: `change_log` (not `ticket`)

### A.8 Validation Rules

1. **Impact is required**: `--impact` must be specified, error otherwise
2. **Impact range**: must be integer 1-5, error otherwise
3. **Type validation**: must be one of `VALID_TYPES`, error with helpful message otherwise
4. **`--ap` format**: requires `key=value` format
5. **`--note-id` format**: requires `key=value` format

### A.9 ID Resolution

`entry_path()` works identically to old `ticket_path()`:
- Exact match preferred
- Partial/substring match supported
- Ambiguous match returns error
- Not found returns error

Error messages say "entry" instead of "ticket":
- `Error: entry '<id>' not found`
- `Error: ambiguous ID '<id>' matches multiple entries`

### A.10 Query / JSONL Output

`_file_to_jsonl()` handles:
- Scalar string fields (double-quoted values stripped)
- Numeric field: `impact` emitted as JSON number
- Array fields: `[val1, val2]` emitted as JSON arrays
- Map fields: `ap:` / `note_id:` with indented children emitted as JSON objects
- `full_path` appended to every line

### A.11 Commands NOT in `change_log` (existed in old `ticket`)

These commands do NOT exist and must NOT be tested:
- `start`, `close`, `reopen`, `status` (no workflow states)
- `dep`, `undep`, `dep tree`, `dep cycle` (no dependencies)
- `link`, `unlink` (no links)
- `ready`, `blocked`, `closed` (no filtered listings)
- `super` (no plugin system)

---

## B. Current Test Infrastructure

### B.1 Feature Files and Scenario Counts

| Feature File | Scenarios | Status for `change_log` |
|---|---|---|
| `ticket_creation.feature` | 21 | REWRITE - fundamentally different fields |
| `ticket_listing.feature` | 19 | REWRITE - different format, no status/deps/ready/blocked/closed |
| `ticket_show.feature` | 9 | REWRITE - different fields, no blockers/children/links sections |
| `ticket_query.feature` | 7 | REWRITE - different fields |
| `ticket_directory.feature` | 10 | ADAPT - rename dir/env/commands, remove dep scenario |
| `ticket_notes.feature` | 7 | ADAPT - rename commands, adapt error messages |
| `ticket_edit.feature` | 3 | ADAPT - rename commands, adapt file paths |
| `id_resolution.feature` | 11 | ADAPT - rename commands, remove status/dep/link scenarios |
| `ticket_status.feature` | 9 | DELETE - no status management |
| `ticket_dependencies.feature` | 16 | DELETE - no dependencies |
| `ticket_links.feature` | 8 | DELETE - no links |
| `ticket_plugins.feature` | 11 | DELETE - no plugin system |

**Total existing scenarios: 131**

### B.2 Environment Setup (`environment.py`)

```python
before_all(context):
    context.project_dir = Path(__file__).parent.parent.resolve()

before_scenario(context, scenario):
    context.test_dir = tempfile.mkdtemp(prefix='ticket_test_')
    context.tickets = {}
    context.last_created_id = None
    context.stdout = ''
    context.stderr = ''
    context.returncode = None

after_scenario(context, scenario):
    shutil.rmtree(context.test_dir)      # always cleanup
    shutil.rmtree(context.plugin_dir)    # if exists
```

**What needs to change:**
- `tempfile.mkdtemp(prefix='ticket_test_')` -> `prefix='changelog_test_'`
- Remove `context.plugin_dir` cleanup (no plugins)
- Keep `context.tickets` dict (used for tracking created entries)

### B.3 Step Definitions (`ticket_steps.py`)

**Helper functions:**

| Function | Purpose | Change needed |
|----------|---------|---------------|
| `get_ticket_script()` | Returns script path, checks `TICKET_SCRIPT` env var | Rename to `get_script()`, use `CHANGE_LOG_SCRIPT` env var, default to `./change_log` |
| `title_to_slug()` | Converts title to filename slug | DELETE - `change_log` uses timestamp filenames |
| `create_ticket()` | Creates test fixture files in `.tickets/` | REWRITE - create in `change_log/`, use `change_log` frontmatter format, timestamp filenames |
| `find_ticket_file()` | Finds file by frontmatter id | ADAPT - search in `change_log/` instead of `.tickets/` |
| `extract_created_id()` | Extracts ID from JSON create output | KEEP as-is |
| `_track_created_ticket()` | Tracks created entries from command output | ADAPT - change `'ticket create'` to `'change_log create'` |

**Command execution pattern:**
- All commands run via `subprocess.run(shell=True)` with `capture_output=True`
- `stdin=subprocess.DEVNULL` for non-interactive tests
- Results stored in `context.stdout`, `context.stderr`, `context.returncode`
- Script name substitution: `command.replace('ticket ', f'{ticket_script} ', 1)`
- Working directory: `context.test_dir` or `context.working_dir` (for subdirectory scenarios)
- Environment: inherits `os.environ`, adds `TICKETS_DIR` when specified

**Step matcher: regex** (`use_step_matcher("re")`)

**Given steps that need changes:**

| Step | Change |
|------|--------|
| `a clean tickets directory` | Change `.tickets` to `change_log` |
| `the tickets directory does not exist` | Change `.tickets` to `change_log` |
| `a ticket exists with ID "X" and title "Y"` | Rewrite for `change_log` frontmatter format |
| `a ticket exists with ID "X" and title "Y" with priority N` | DELETE (no priority, use impact) |
| `a ticket exists with ID "X" and title "Y" with parent "Z"` | DELETE (no parent) |
| `ticket "X" has status "Y"` | DELETE (no status) |
| `ticket "X" depends on "Y"` | DELETE (no deps) |
| `ticket "X" is linked to "Y"` | DELETE (no links) |
| `a separate tickets directory exists at "X"...` | Adapt frontmatter format |
| `I am in subdirectory "X"` | KEEP as-is |
| `ticket "X" has a notes section` | ADAPT - change `find_ticket_file` path |
| All plugin steps | DELETE |

**When steps that need changes:**

| Step | Change |
|------|--------|
| `I run "..."` | Change `'ticket '` replacement to `'change_log '` |
| `I run "..." in non-TTY mode` | Same replacement |
| `I run "..." with no stdin` | Same replacement |
| `I run "..." with TICKETS_DIR set to "X"` | Rename to `CHANGE_LOG_DIR` |
| `I run "..." with plugins` | DELETE |

**Then steps that need changes:**

| Step | Change |
|------|--------|
| `the tickets directory should exist` | Change `.tickets` to `change_log` |
| `tickets directory should exist in current subdirectory` | Change `.tickets` to `change_log` |
| `a file named "X" should exist in tickets directory` | Change `.tickets` to `change_log` |
| All deps/links assertion steps | DELETE |
| `the JSONL deps field should be a JSON array` | DELETE |
| `the dep tree output should have X before Y` | DELETE |
| `the output should match box-drawing tree format` | DELETE |
| All other Then steps | KEEP (generic output/field assertions) |

### B.4 `create_ticket()` Helper (Current)

Creates fixture files with old `ticket` frontmatter format:
```python
def create_ticket(context, ticket_id, title, priority=2, parent=None):
    tickets_dir = Path(context.test_dir) / '.tickets'
    slug = title_to_slug(title)
    ticket_path = tickets_dir / f'{slug}.md'
    # ... collision handling ...
    content = f'''---
id: {ticket_id}
title: "{escaped_title}"
status: open
deps: []
links: []
created: 2024-01-01T00:00:00Z
type: task
priority: {priority}
---
'''
```

**Must be rewritten** to produce `change_log` format (see section C.3).

### B.5 Makefile

```makefile
test:
    uv run --with behave behave
```

No changes needed to the Makefile itself.

---

## C. What Needs to Change

### C.1 Feature Files to DELETE Entirely (4 files, 44 scenarios)

These test commands that do not exist in `change_log`:

| File | Scenarios | Reason |
|------|-----------|--------|
| `ticket_status.feature` | 9 | No `status`, `start`, `close`, `reopen` commands |
| `ticket_dependencies.feature` | 16 | No `dep`, `undep`, `dep tree`, `dep cycle` commands |
| `ticket_links.feature` | 8 | No `link`, `unlink` commands |
| `ticket_plugins.feature` | 11 | No plugin system, no `super` command |

### C.2 Feature Files to REWRITE (4 files, 56 scenarios -> new count TBD)

These files test commands that exist but with fundamentally different behavior:

**`ticket_creation.feature` -> `entry_creation.feature`**
- Every scenario references wrong command name, wrong flags, wrong fields
- Old: `ticket create 'title'` with `-p`, `-t bug`, `-d`, `--external-ref`, `--parent`, `--design`, `--acceptance`
- New: `change_log create 'title'` with `--impact N` (required), `-t feature`, `--desc`, `--tags`, `--dirs`, `--ap`, `--note-id`
- Old defaults: status=open, priority=2, type=task, deps=[], links=[]
- New defaults: type=default, no status/deps/links at all
- Old filenames: title-based slug (`my-ticket.md`)
- New filenames: timestamp-based (`2024-01-01_00-00-00Z.md`)

**`ticket_listing.feature` -> `entry_listing.feature`**
- Only `ls` / `list` with `--limit=N` exists
- No `--status` filter, no `ready`, no `blocked`, no `closed` commands
- Output format: `<8-char-id> [I<impact>][<type>] <title>` (not `<id> [status] - title`)
- No dependency display in listing

**`ticket_show.feature` -> `entry_show.feature`**
- Different frontmatter fields displayed
- No Blockers, Blocking, Children, Linked sections
- No parent field enhancement
- Just raw `cat` of file content (or paged)

**`ticket_query.feature` -> `entry_query.feature`**
- Different fields in JSONL output
- No `status`, `deps`, `links`, `priority` fields
- Has `impact` (numeric), `tags`/`dirs` (arrays), `ap`/`note_id` (maps)

### C.3 Feature Files to ADAPT (4 files, 31 scenarios)

These files test functionality that exists with minor naming/format differences:

**`ticket_directory.feature` -> `entry_directory.feature`**
- Change `.tickets` -> `change_log` in all references
- Change `TICKETS_DIR` -> `CHANGE_LOG_DIR`
- Change `ticket` command -> `change_log` command
- Change error message `no .tickets directory found` -> `no change_log directory found`
- REMOVE: "Dep command works from subdirectory" scenario (line 66-72)
- REMOVE: "Create ticket initializes in current directory" scenario needs adjustment (old uses `ticket create 'title'`, new needs `change_log create 'title' --impact 3`)
- ADAPT: "Help command works without tickets directory" - change expected text

**`ticket_notes.feature` -> `entry_notes.feature`**
- Change `ticket` -> `change_log` in all commands
- Change error messages from "ticket" to "entry"
- Change fixture creation to use `change_log` format
- `create_ticket` helper must produce `change_log`-format files

**`ticket_edit.feature` -> `entry_edit.feature`**
- Change `ticket` -> `change_log` in all commands
- Change error messages from "ticket" to "entry"
- Change `Edit ticket file:` -> `Edit entry file:` (matches `cmd_edit` output)
- Change `.tickets/editable-ticket.md` -> `change_log/<timestamp>.md` path format
- Fixture creation must use `change_log` format

**`id_resolution.feature` -> `entry_id_resolution.feature`**
- Change `ticket` -> `change_log` in all commands
- Change error messages: `"ticket 'X' not found"` -> `"entry 'X' not found"`, `"matches multiple tickets"` -> `"matches multiple entries"`
- REMOVE: "ID resolution works with status command" scenario (no status)
- REMOVE: "ID resolution works with dep command" scenario (no deps)
- REMOVE: "ID resolution works with link command" scenario (no links)

### C.4 Step Definition Changes Summary

The `ticket_steps.py` file needs significant refactoring:

1. **Rename** `get_ticket_script()` -> `get_script()`, env var `TICKET_SCRIPT` -> `CHANGE_LOG_SCRIPT`, default `./ticket` -> `./change_log`
2. **DELETE** `title_to_slug()` function entirely
3. **REWRITE** `create_ticket()` helper (see D.1 below)
4. **ADAPT** `find_ticket_file()` to search `change_log/` instead of `.tickets/`
5. **ADAPT** `_track_created_ticket()` to check for `'change_log create'` instead of `'ticket create'`
6. **ADAPT** all "When I run" steps to replace `'ticket '` with script path for `change_log`
7. **ADAPT** `TICKETS_DIR` env var step to use `CHANGE_LOG_DIR`
8. **ADAPT** directory assertion steps: `.tickets` -> `change_log`
9. **DELETE** all dependency-related Then steps (deps, links assertions)
10. **DELETE** all plugin-related Given/When steps
11. **DELETE** `step_ticket_has_status`, `step_ticket_depends_on`, `step_ticket_linked_to`, `step_ticket_exists_with_priority`, `step_ticket_exists_with_parent`
12. **ADD** new Given step for creating entries with impact: `a changelog entry exists with ID "X" and title "Y" with impact N`
13. **ADD** new assertion steps for JSONL map/array fields

---

## D. New Test Scenarios Needed

### D.1 New `create_entry()` Helper

Must produce files matching `change_log` frontmatter format:

```python
def create_entry(context, entry_id, title, impact=3, entry_type="default"):
    changelog_dir = Path(context.test_dir) / 'change_log'
    changelog_dir.mkdir(parents=True, exist_ok=True)

    # Use a deterministic but unique timestamp-like filename for fixtures
    filename = f"2024-01-01_00-00-{len(context.tickets):02d}Z.md"
    entry_path = changelog_dir / filename

    escaped_title = title.replace('"', '\\"')
    content = f'''---
id: {entry_id}
title: "{escaped_title}"
created_iso: 2024-01-01T00:00:00Z
type: {entry_type}
impact: {impact}
---

'''
    entry_path.write_text(content)
    context.tickets[entry_id] = entry_path
    return entry_path
```

### D.2 Impact Validation Scenarios (NEW)

```gherkin
Scenario: Create fails without --impact
    When I run "change_log create 'Test'"
    Then the command should fail
    And the output should contain "Error: --impact is required (1-5)"

Scenario: Create fails with impact 0
    When I run "change_log create 'Test' --impact 0"
    Then the command should fail
    And the output should contain "Error: --impact must be 1-5"

Scenario: Create fails with impact 6
    When I run "change_log create 'Test' --impact 6"
    Then the command should fail
    And the output should contain "Error: --impact must be 1-5"

Scenario: Create fails with non-numeric impact
    When I run "change_log create 'Test' --impact high"
    Then the command should fail
    And the output should contain "Error: --impact must be 1-5"

Scenario: Create succeeds with impact 1 (boundary)
    When I run "change_log create 'Test' --impact 1"
    Then the command should succeed

Scenario: Create succeeds with impact 5 (boundary)
    When I run "change_log create 'Test' --impact 5"
    Then the command should succeed

Scenario: Impact stored as numeric in frontmatter
    When I run "change_log create 'Test' --impact 3"
    Then the command should succeed
    And the created entry should have field "impact" with value "3"
```

### D.3 Type Validation Scenarios (NEW)

```gherkin
Scenario: Create with each valid type
    # One scenario per valid type: feature, bug_fix, refactor, chore, breaking_change, docs, default

Scenario: Create fails with invalid type
    When I run "change_log create 'Test' --impact 3 -t invalid_type"
    Then the command should fail
    And the output should contain "Error: invalid type"

Scenario: Default type is 'default'
    When I run "change_log create 'Test' --impact 3"
    Then the command should succeed
    And the created entry should have field "type" with value "default"
```

### D.4 Description Field Scenarios (NEW)

```gherkin
Scenario: Create with --desc
    When I run "change_log create 'Test' --impact 3 --desc 'A description'"
    Then the command should succeed
    And the created entry should have field "desc" with value "A description"

Scenario: Create without --desc omits desc field
    When I run "change_log create 'Test' --impact 3"
    Then the command should succeed
    And the created entry should not contain "desc:"
```

### D.5 Tags and Dirs as Arrays (NEW)

```gherkin
Scenario: Create with tags
    When I run "change_log create 'Test' --impact 3 --tags ui,backend"
    Then the command should succeed
    And the created entry should contain "tags: [ui, backend]"

Scenario: Create with dirs
    When I run "change_log create 'Test' --impact 3 --dirs src/api,src/ui"
    Then the command should succeed
    And the created entry should contain "dirs: [src/api, src/ui]"

Scenario: Tags appear as JSON array in query output
    When I run "change_log create 'Test' --impact 3 --tags ui,backend"
    And I run "change_log query"
    Then the command should succeed
    And the output should be valid JSONL
    # JSONL should contain "tags":["ui","backend"]
```

### D.6 `ap` and `note_id` as Maps (NEW)

```gherkin
Scenario: Create with --ap key=value
    When I run "change_log create 'Test' --impact 3 --ap anchor1=value1"
    Then the command should succeed
    And the created entry should contain "ap:"
    And the created entry should contain "  anchor1: value1"

Scenario: Create with multiple --ap pairs
    When I run "change_log create 'Test' --impact 3 --ap k1=v1 --ap k2=v2"
    Then the command should succeed
    And the created entry should contain "  k1: v1"
    And the created entry should contain "  k2: v2"

Scenario: Create without --ap omits ap field entirely
    When I run "change_log create 'Test' --impact 3"
    Then the command should succeed
    And the created entry should not contain "ap:"

Scenario: --ap rejects missing equals sign
    When I run "change_log create 'Test' --impact 3 --ap badformat"
    Then the command should fail
    And the output should contain "Error: --ap requires key=value format"

Scenario: Create with --note-id key=value
    When I run "change_log create 'Test' --impact 3 --note-id ref1=abc123"
    Then the command should succeed
    And the created entry should contain "note_id:"
    And the created entry should contain "  ref1: abc123"

Scenario: Create without --note-id omits note_id field entirely
    When I run "change_log create 'Test' --impact 3"
    Then the command should succeed
    And the created entry should not contain "note_id:"

Scenario: ap and note_id appear as JSON objects in query
    When I run "change_log create 'Test' --impact 3 --ap k1=v1 --note-id r1=x1"
    And I run "change_log query"
    Then the command should succeed
    And the output should be valid JSONL
    # JSONL should have "ap":{"k1":"v1"} and "note_id":{"r1":"x1"}
```

### D.7 Timestamp Filename Verification (NEW)

```gherkin
Scenario: Created entry has timestamp-based filename
    When I run "change_log create 'Test' --impact 3"
    Then the command should succeed
    # Verify full_path in JSON output matches YYYY-MM-DD_HH-MM-SSZ.md pattern
    And the output should match pattern "\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}Z\.md"
```

### D.8 Query JSONL Field Verification (NEW)

```gherkin
Scenario: Query includes all expected fields
    When I run "change_log create 'Test' --impact 3 --desc 'desc' --tags ui --dirs src --ap k=v --note-id r=x"
    And I run "change_log query"
    Then the command should succeed
    And the JSONL output should have field "id"
    And the JSONL output should have field "title"
    And the JSONL output should have field "desc"
    And the JSONL output should have field "created_iso"
    And the JSONL output should have field "type"
    And the JSONL output should have field "impact"
    And the JSONL output should have field "tags"
    And the JSONL output should have field "dirs"
    And the JSONL output should have field "ap"
    And the JSONL output should have field "note_id"
    And the JSONL output should have field "full_path"

Scenario: Query impact is numeric (not string)
    When I run "change_log create 'Test' --impact 4"
    And I run "change_log query"
    Then the command should succeed
    # Verify impact is a JSON number, not a string
```

### D.9 Listing Format Verification (NEW)

```gherkin
Scenario: List shows correct format
    # Given an entry exists
    When I run "change_log ls"
    Then the command should succeed
    And the output should match pattern "[a-z0-9]{8}\s+\[I\d\]\[[\w]+\]\s+.+"

Scenario: List with --limit
    # Given multiple entries
    When I run "change_log ls --limit=1"
    Then the command should succeed
    And the output line count should be 1
```

### D.10 New Step Definitions Needed

```python
# Given steps
@given(r'a changelog entry exists with ID "(?P<entry_id>[^"]+)" and title "(?P<title>[^"]+)" with impact (?P<impact>\d+)')
@given(r'a changelog entry exists with ID "(?P<entry_id>[^"]+)" and title "(?P<title>[^"]+)"')
@given(r'a clean changelog directory')
@given(r'the changelog directory does not exist')
@given(r'entry "(?P<entry_id>[^"]+)" has a notes section')

# Then steps
@then(r'the changelog directory should exist')
@then(r'the created entry should not contain "(?P<text>[^"]+)"')
@then(r'the created entry should have field "(?P<field>[^"]+)" with value "(?P<value>[^"]+)"')
```

---

## E. Summary: Scope of Work

### By the Numbers

| Category | Files | Scenarios |
|----------|-------|-----------|
| DELETE entirely | 4 feature files | 44 scenarios removed |
| REWRITE | 4 feature files | ~56 old scenarios -> ~45+ new scenarios |
| ADAPT | 4 feature files | ~31 scenarios (minor edits) |
| NEW scenarios | within rewritten files | ~30+ new scenarios for validation/fields |
| Step definitions | 1 file | Major refactor |
| Environment | 1 file | Minor rename |

### Risk Areas

1. **`create_entry()` helper is foundational** - Nearly every test depends on it. Getting the frontmatter format right is critical.
2. **Timestamp-based filenames in fixtures** - Unlike slug filenames, we need deterministic but unique filenames for test fixtures. Must avoid collisions when multiple entries are created in one scenario.
3. **JSONL map/array assertions** - The old tests had no map fields (`ap`, `note_id`). New assertion steps needed for verifying JSON objects within JSONL.
4. **Command name substitution** - Every "When I run" step replaces the command name. Must ensure `change_log` is substituted correctly (note: contains a space-like character issue? No, it does not -- `change_log` is one word with underscore).
5. **No git init in test_dir** - The `find_change_log_dir()` auto-create logic calls `git rev-parse --show-toplevel`. Test scenarios that rely on auto-creation at git root will need a `git init` in the test directory. The old tests likely worked because they pre-created `.tickets/` or used `TICKETS_DIR`. The directory discovery tests need careful attention.
