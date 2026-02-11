# Phase 02 Implementation Plan: BDD Test Suite Rewrite

## Problem Understanding

Rewrite the entire BDD test suite from `ticket`-centric tests to `change_log`-centric tests. The `change_log` script (Phase 01 output) is a fundamentally different tool -- it is a changelog system, not an issue tracker. There is no status, no dependencies, no links, no plugins. There are new fields (`impact`, `desc`, `tags`, `dirs`, `ap`, `note_id`), new filename format (timestamp-based), and a new directory name (`change_log/` instead of `.tickets/`).

**Constraint**: Only test code changes. The `change_log` script itself is NOT modified.

**Goal**: `make test` passes with all new scenarios green, zero references to "ticket" in test code.

---

## High-Level Architecture

```
features/
  environment.py                   # ADAPT (minor renames)
  steps/
    changelog_steps.py             # NEW (replaces ticket_steps.py)
  changelog_creation.feature       # NEW (replaces ticket_creation.feature)
  changelog_listing.feature        # NEW (replaces ticket_listing.feature)
  changelog_show.feature           # NEW (replaces ticket_show.feature)
  changelog_query.feature          # NEW (replaces ticket_query.feature)
  changelog_directory.feature      # NEW (replaces ticket_directory.feature)
  changelog_notes.feature          # NEW (replaces ticket_notes.feature)
  changelog_edit.feature           # NEW (replaces ticket_edit.feature)
  id_resolution.feature            # REWRITE in-place (same filename)
```

Files to DELETE (no replacement):
- `ticket_status.feature`
- `ticket_dependencies.feature`
- `ticket_links.feature`
- `ticket_plugins.feature`

---

## Implementation Phases

The phases are ordered so that after each phase, `make test` can be run (possibly with some failures) to validate progress incrementally. The key insight is: we do step definitions first (since all feature files depend on them), then build feature files command-by-command.

---

### Phase 1: Foundation -- Step Definitions and Environment

**Goal**: Create `changelog_steps.py` with all helper functions and step definitions needed. Update `environment.py`. Delete `ticket_steps.py`.

**Files touched**:
- `features/steps/changelog_steps.py` (NEW)
- `features/steps/ticket_steps.py` (DELETE)
- `features/environment.py` (EDIT)

#### Step 1.1: Create `changelog_steps.py` with helpers

Create `features/steps/changelog_steps.py` with these sections:

**A) Helper functions**:

1. `get_script(context)` -- Returns script path. Checks `CHANGE_LOG_SCRIPT` env var, defaults to `<project_dir>/change_log`.

2. `create_entry(context, entry_id, title, impact=3, entry_type="default")` -- Creates a fixture file in `<test_dir>/change_log/` with changelog frontmatter format. Uses deterministic timestamp filenames: `2024-01-01_00-00-{counter:02d}Z.md` where counter is `len(context.tickets)`. Tracks in `context.tickets[entry_id]`.

   Frontmatter template:
   ```yaml
   ---
   id: {entry_id}
   title: "{escaped_title}"
   created_iso: 2024-01-01T00:00:00Z
   type: {entry_type}
   impact: {impact}
   ---
   ```

3. `find_entry_file(context, entry_id)` -- Checks `context.tickets` dict first, then scans `change_log/` directory for matching `id:` field. Same logic as old `find_ticket_file` but searches `change_log/` instead of `.tickets/`.

4. `extract_created_id(stdout)` -- KEEP as-is from old code. Parses JSON output to extract `id` field.

5. `_track_created_entry(context, command, result)` -- Adapts `_track_created_ticket`. Checks for `'change_log create'` in command. Stores to `context.tickets` and `context.last_created_id`.

6. `_run_command(context, command, env_override=None, cwd_override=None)` -- DRY helper that consolidates the common subprocess pattern. Replaces `'change_log '` prefix with actual script path. Stores stdout/stderr/returncode on context. Calls `_track_created_entry`. This avoids duplicating the subprocess logic across 4+ When steps.

**B) Given steps** (regex matcher):

| Step pattern | Behavior |
|---|---|
| `a clean changelog directory` | Create `<test_dir>/change_log/` (clean) |
| `the changelog directory does not exist` | Ensure `<test_dir>/change_log/` does not exist |
| `a changelog entry exists with ID "X" and title "Y" with impact N` | `create_entry(context, X, Y, impact=N)` |
| `a changelog entry exists with ID "X" and title "Y" with type "T"` | `create_entry(context, X, Y, entry_type=T)` |
| `a changelog entry exists with ID "X" and title "Y"` | `create_entry(context, X, Y)` (most generic, defined LAST to avoid regex precedence issues) |
| `entry "X" has a notes section` | Append `\n## Notes\n` to the entry file |
| `I am in subdirectory "X"` | KEEP as-is (creates subdir, sets `context.working_dir`) |
| `a separate changelog directory exists at "X" with entry "Y" titled "Z"` | Create directory at `<test_dir>/X/`, write a fixture entry there |

**C) When steps**:

| Step pattern | Behavior |
|---|---|
| `I run "X" in non-TTY mode` | `_run_command(context, X)` -- all subprocess calls already use `stdin=subprocess.DEVNULL` so non-TTY behavior is the same |
| `I run "X" with no stdin` | Same as above |
| `I run "X" with CHANGE_LOG_DIR set to "Y"` | `_run_command(context, X, env_override={'CHANGE_LOG_DIR': resolved_path})` |
| `I run "X"` | `_run_command(context, X)` -- generic catch-all, defined LAST |
| `I pipe "X" to "Y"` | For stdin piping scenarios (notes via stdin). Use `subprocess.PIPE` with input. |

NOTE on ordering: Behave regex matchers try steps in definition order. More specific patterns (with env var, non-TTY, etc.) MUST be defined BEFORE the generic `I run "X"`.

**D) Then steps -- keep all generic ones, add changelog-specific**:

KEEP as-is (generic, not ticket-specific):
- `the command should succeed`
- `the command should fail`
- `the output should be "X"`
- `the output should be empty`
- `the output should contain "X"`
- `the output should not contain "X"`
- `the output should be valid JSON with an id field`
- `the output should match pattern "X"`
- `the output should be valid JSONL`
- `the JSONL output should have field "X"`
- `every JSONL line should have field "X"`
- `the output line N should contain "X"`
- `the output line count should be N`
- `the output should match a ticket ID pattern` -- RENAME pattern text to `the output should match an entry ID pattern` but same logic

ADD changelog-specific:
- `the changelog directory should exist` -- Checks `<test_dir>/change_log/` exists
- `changelog directory should exist in current subdirectory` -- Checks `<working_dir>/change_log/`
- `a file named "X" should exist in changelog directory` -- Checks `<test_dir>/change_log/X`
- `the created entry should contain "X"` -- Reads last created entry file, asserts text
- `the created entry should not contain "X"` -- Reads last created entry file, asserts NOT contains
- `the created entry should have field "X" with value "Y"` -- Reads last created entry YAML field
- `the created entry should have a valid created_iso timestamp` -- Checks `created_iso:` with ISO pattern
- `a entry file should exist with title "X"` -- Finds last created entry, checks title in frontmatter
- `entry "X" should contain "Y"` -- Find entry by ID, assert content contains text
- `entry "X" should contain a timestamp in notes` -- Same pattern as old but uses `find_entry_file`
- `the JSONL output should have numeric field "X"` -- Parses first JSONL line, checks field value is number

DELETE (not needed):
- All dep/link assertion steps
- All plugin steps
- `the output should match box-drawing tree format`
- `the dep tree output should have X before Y`
- `the JSONL deps field should be a JSON array`

#### Step 1.2: Update `environment.py`

Changes:
1. `tempfile.mkdtemp(prefix='ticket_test_')` --> `prefix='changelog_test_'`
2. Remove `context.plugin_dir` cleanup from `after_scenario` (no plugins)
3. Keep everything else (context.tickets, context.last_created_id, etc.)

#### Step 1.3: Delete `ticket_steps.py`

Remove `features/steps/ticket_steps.py`.

**Acceptance criteria for Phase 1**:
- `features/steps/changelog_steps.py` exists with all helper functions and step definitions
- `features/steps/ticket_steps.py` is deleted
- `features/environment.py` updated
- Python syntax is valid: `python -c "import py_compile; py_compile.compile('features/steps/changelog_steps.py', doraise=True)"`

---

### Phase 2: Delete Obsolete Feature Files

**Goal**: Remove feature files for commands that do not exist in `change_log`.

Delete these 4 files:
- `features/ticket_status.feature`
- `features/ticket_dependencies.feature`
- `features/ticket_links.feature`
- `features/ticket_plugins.feature`

Also delete these old files that will be replaced with new names:
- `features/ticket_creation.feature`
- `features/ticket_listing.feature`
- `features/ticket_show.feature`
- `features/ticket_query.feature`
- `features/ticket_directory.feature`
- `features/ticket_notes.feature`
- `features/ticket_edit.feature`

**Acceptance criteria**: All `ticket_*.feature` files are gone. Only `id_resolution.feature` remains (will be rewritten in-place).

---

### Phase 3: `changelog_creation.feature`

**Goal**: Test the `create` command with all its flags, validation, and output format.

**File**: `features/changelog_creation.feature`

**Background**:
```gherkin
Background:
  Given a clean changelog directory
```

**Scenarios** (21 total):

| # | Scenario name | Key assertions |
|---|---|---|
| 1 | Create a basic entry with title | succeed, valid JSON with id, entry has title in frontmatter |
| 2 | Create an entry with default title | succeed, title is "Untitled" |
| 3 | Create fails without --impact | fail, stderr contains "Error: --impact is required (1-5)" |
| 4 | Create fails with impact 0 | fail, stderr contains "Error: --impact must be 1-5" |
| 5 | Create fails with impact 6 | fail, stderr contains "Error: --impact must be 1-5" |
| 6 | Create fails with non-numeric impact | fail, stderr contains "Error: --impact must be 1-5" |
| 7 | Create succeeds with impact 1 (boundary) | succeed |
| 8 | Create succeeds with impact 5 (boundary) | succeed |
| 9 | Impact stored as numeric in frontmatter | succeed, field "impact" has value "3" |
| 10 | Default type is default | succeed, field "type" has value "default" |
| 11 | Create with valid type feature | succeed, field "type" has value "feature" |
| 12 | Create fails with invalid type | fail, stderr contains "Error: invalid type" |
| 13 | Create with --desc | succeed, entry contains `desc: "A description"` |
| 14 | Create without --desc omits desc field | succeed, entry does NOT contain "desc:" |
| 15 | Create with --tags | succeed, entry contains `tags: [ui, backend]` |
| 16 | Create with --dirs | succeed, entry contains `dirs: [src/api, src/ui]` |
| 17 | Create with --ap key=value | succeed, entry contains `ap:` and `  anchor1: value1` |
| 18 | Create without --ap omits ap field | succeed, entry does NOT contain "ap:" |
| 19 | --ap rejects missing equals sign | fail, stderr contains "Error: --ap requires key=value format" |
| 20 | Create with --note-id | succeed, entry contains `note_id:` and `  ref1: abc123` |
| 21 | Created entry has timestamp-based filename | succeed, output JSON full_path matches `\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}Z\.md` |
| 22 | Created entry has valid created_iso timestamp | succeed, entry has `created_iso: YYYY-MM-DDTHH:MM:SSZ` |
| 23 | Create outputs JSONL with expected fields | succeed, valid JSONL, has fields: id, title, type, impact, full_path |
| 24 | Title stored in frontmatter | succeed, field "title" has value "Frontmatter Title" |

**Acceptance criteria**: `make test` runs this file with all scenarios passing.

---

### Phase 4: `changelog_listing.feature`

**Goal**: Test the `ls` / `list` command with the new output format.

**File**: `features/changelog_listing.feature`

**Background**:
```gherkin
Background:
  Given a clean changelog directory
```

**Scenarios** (7 total):

| # | Scenario name | Key assertions |
|---|---|---|
| 1 | List all entries | Create 2 entries, `change_log ls`, output contains both 8-char ID prefixes |
| 2 | List command alias works | Create 1 entry, `change_log list`, output contains ID |
| 3 | List shows correct format | Create entry with known impact+type, assert pattern `[a-z0-9]{8}\s+\[I\d\]\[\w+\]\s+.+` |
| 4 | List with no entries returns nothing | `change_log ls`, output should be empty |
| 5 | List with --limit | Create 3 entries, `change_log ls --limit=2`, output line count is 2 |
| 6 | List shows most recent first | Create entries with filenames that sort chronologically, verify ordering |
| 7 | List shows impact level in output | Create entry with impact 4, output contains `[I4]` |

NOTE on scenario 6 (ordering): The `create_entry` helper uses deterministic filenames `2024-01-01_00-00-{NN}Z.md`. Since `ls` sorts by filename descending, the last-created entry (highest NN) appears first. Create entry A (NN=00) then entry B (NN=01), run `change_log ls`, assert output line 1 contains B's ID and line 2 contains A's ID.

**Acceptance criteria**: `make test` runs this file with all scenarios passing.

---

### Phase 5: `changelog_show.feature`

**Goal**: Test the `show` command. The `change_log show` command simply `cat`s the file content (or uses pager in TTY mode, but tests are non-TTY).

**File**: `features/changelog_show.feature`

**Background**:
```gherkin
Background:
  Given a clean changelog directory
```

**Scenarios** (5 total):

| # | Scenario name | Key assertions |
|---|---|---|
| 1 | Show displays entry content | Create entry, `change_log show <id>`, output contains `id:`, `title:`, title text |
| 2 | Show displays frontmatter fields | Create entry, show it, output contains `type:`, `impact:`, `created_iso:` |
| 3 | Show non-existent entry | `change_log show nonexistent`, fail, stderr contains `Error: entry 'nonexistent' not found` |
| 4 | Show with partial ID | Create entry with ID "show-001", `change_log show 001`, succeed, output contains `id: show-001` |
| 5 | Show with no arguments | `change_log show`, fail, output contains "Usage:" |

**Acceptance criteria**: `make test` runs this file with all scenarios passing.

---

### Phase 6: `changelog_edit.feature`

**Goal**: Test the `edit` command in non-TTY mode (which prints the file path).

**File**: `features/changelog_edit.feature`

**Background**:
```gherkin
Background:
  Given a clean changelog directory
  And a changelog entry exists with ID "edit-0001" and title "Editable entry"
```

**Scenarios** (3 total):

| # | Scenario name | Key assertions |
|---|---|---|
| 1 | Edit in non-TTY mode shows file path | `change_log edit edit-0001` in non-TTY mode, succeed, output contains "Edit entry file:", output contains `change_log/` |
| 2 | Edit non-existent entry | `change_log edit nonexistent`, fail, output contains `Error: entry 'nonexistent' not found` |
| 3 | Edit with partial ID | `change_log edit 0001` in non-TTY mode, succeed, output contains file path with `.md` |

**Acceptance criteria**: `make test` runs this file with all scenarios passing.

---

### Phase 7: `changelog_notes.feature`

**Goal**: Test the `add-note` command.

**File**: `features/changelog_notes.feature`

**Background**:
```gherkin
Background:
  Given a clean changelog directory
  And a changelog entry exists with ID "note-0001" and title "Test entry"
```

**Scenarios** (7 total):

| # | Scenario name | Key assertions |
|---|---|---|
| 1 | Add a note to entry | `change_log add-note note-0001 'This is my note'`, succeed, output is `Note added to note-0001`, entry contains `## Notes`, entry contains "This is my note" |
| 2 | Note has timestamp | `change_log add-note note-0001 'Timestamped note'`, entry contains timestamp pattern `**YYYY-MM-DDTHH:MM:SSZ**` |
| 3 | Add multiple notes | Add two notes, entry contains both |
| 4 | Add note to entry that already has notes section | Given entry has notes section, add note, succeed |
| 5 | Add note with empty string adds timestamp-only note | `change_log add-note note-0001 ''`, succeed |
| 6 | Add note to non-existent entry | `change_log add-note nonexistent 'My note'`, fail, output contains `Error: entry 'nonexistent' not found` |
| 7 | Add note with partial ID | `change_log add-note 0001 'Partial ID note'`, succeed, output is `Note added to note-0001` |

**Acceptance criteria**: `make test` runs this file with all scenarios passing.

---

### Phase 8: `changelog_query.feature`

**Goal**: Test the `query` command (JSONL output, jq filter, field presence).

**File**: `features/changelog_query.feature`

**Background**:
```gherkin
Background:
  Given a clean changelog directory
```

**Scenarios** (8 total):

| # | Scenario name | Key assertions |
|---|---|---|
| 1 | Query all entries as JSONL | Create 2 entries, `change_log query`, succeed, valid JSONL, contains both IDs |
| 2 | Query with jq filter by type | Create entry with type feature and another with type default, `change_log query '.type == "feature"'`, output contains feature entry, not default |
| 3 | Query includes core fields | Create entry, query, JSONL has fields: id, title, created_iso, type, impact |
| 4 | Query with no entries | `change_log query`, output is empty |
| 5 | Query always includes full_path | Create entry, query, every JSONL line has field "full_path" |
| 6 | Query includes title field | Create entry with specific title, query, output contains that title |
| 7 | Query impact is numeric | Create entry with impact 4, query, parse JSONL, assert `impact` field is `int` not `str` |
| 8 | Query includes desc field when present | Create entry with --desc via the CLI, query, JSONL has "desc" field |

For scenario 7 (numeric check), add a Then step: `the JSONL impact field should be numeric`. Implementation: parse first JSONL line, assert `isinstance(data['impact'], (int, float))`.

For scenario 2 (jq filter): this requires `jq` on the test system. If `jq` is not present, the scenario will fail at the script level (not a test issue). The old test suite assumed `jq` presence and so can we.

**Acceptance criteria**: `make test` runs this file with all scenarios passing.

---

### Phase 9: `changelog_directory.feature`

**Goal**: Test directory discovery, parent walking, auto-create at git root, and `CHANGE_LOG_DIR` env var override.

**File**: `features/changelog_directory.feature`

**Background**:
```gherkin
Background:
  Given a clean changelog directory
```

**Scenarios** (8 total):

| # | Scenario name | Key assertions |
|---|---|---|
| 1 | Find changelog in current directory | Create entry, `change_log ls`, succeed, output contains ID |
| 2 | Find changelog in parent directory | Create entry, `cd src/components`, `change_log ls`, succeed |
| 3 | Find changelog in grandparent directory | Create entry, `cd src/components/ui`, `change_log ls`, succeed |
| 4 | CHANGE_LOG_DIR env var takes priority | Create entries in two dirs, run ls with env var pointing at second dir, only second dir's entry appears |
| 5 | Show command works from subdirectory | Create entry, `cd src`, `change_log show <id>`, succeed |
| 6 | Help command works without changelog directory | No changelog dir, `change_log help`, succeed, output contains "git-backed changelog" |
| 7 | Error when no changelog directory for read command | No changelog dir, `change_log ls`, fail, output contains "no change_log directory found" |
| 8 | Error when no changelog directory in any parent | No changelog dir, cd deep subdir, `change_log ls`, fail |

IMPORTANT: Scenarios 7 and 8 test error behavior when `change_log/` does not exist AND the test directory is not a git repo. The test temp dir is NOT a git repository, so `find_change_log_dir()` will fail with the expected error. This is the same pattern as the old tests.

Scenario 6 note: The help command does NOT require a changelog directory (skipped in the dispatch). The output should contain "git-backed changelog" which appears in the help text.

**Acceptance criteria**: `make test` runs this file with all scenarios passing.

---

### Phase 10: `id_resolution.feature` Rewrite

**Goal**: Rewrite the ID resolution feature file in-place for changelog context.

**File**: `features/id_resolution.feature` (REWRITE contents)

**Background**:
```gherkin
Background:
  Given a clean changelog directory
```

**Scenarios** (8 total -- removed status/dep/link scenarios):

| # | Scenario name | Key assertions |
|---|---|---|
| 1 | Exact ID match | Create entry with ID "abc1234...", `change_log show abc1234...`, succeed, output contains `id: abc1234...` |
| 2 | Partial ID match by suffix | `change_log show 1234`, succeed |
| 3 | Partial ID match by prefix | `change_log show abc`, succeed |
| 4 | Partial ID match by substring | `change_log show c-12`, succeed |
| 5 | Ambiguous ID error | Create two entries with IDs starting with "abc", `change_log show abc`, fail, output contains `Error: ambiguous ID 'abc' matches multiple entries` |
| 6 | Non-existent ID error | `change_log show nonexistent`, fail, output contains `Error: entry 'nonexistent' not found` |
| 7 | Exact match takes precedence | Create entry with ID "abc" and entry with ID "abc-1234", `change_log show abc`, succeed, output contains "id: abc", output contains short ID entry's title |
| 8 | ID resolution works with add-note command | Create entry, `change_log add-note <partial-id> 'test'`, succeed |

Key error message changes from old tests:
- `"Error: ticket 'X' not found"` --> `"Error: entry 'X' not found"`
- `"matches multiple tickets"` --> `"matches multiple entries"`

**Acceptance criteria**: `make test` runs this file with all scenarios passing.

---

### Phase 11: Final Verification

**Goal**: Ensure the complete test suite passes and no "ticket" references remain.

Steps:
1. Run `make test` -- all scenarios should pass.
2. Grep for "ticket" in all feature files and step definitions: `grep -ri ticket features/` -- should return zero results.
3. Verify scenario count is reasonable (expected ~67 scenarios total).

**Acceptance criteria**:
- `make test` exits 0
- `grep -ri 'ticket' features/` returns empty
- No `ticket_*.feature` files exist
- `features/steps/ticket_steps.py` does not exist

---

## Technical Considerations

### DRY: `_run_command()` helper

The old `ticket_steps.py` has 4 near-identical subprocess invocations (run, run non-TTY, run no-stdin, run with env). Consolidate into a single `_run_command(context, command, env_override=None, cwd_override=None)` helper. Each When step becomes a thin wrapper:

```python
def _run_command(context, command, env_override=None):
    command = command.replace('\\"', '"')
    script = get_script(context)
    cmd = command.replace('change_log ', f'{script} ', 1)
    cwd = getattr(context, 'working_dir', context.test_dir)
    env = os.environ.copy()
    if env_override:
        env.update(env_override)
    result = subprocess.run(cmd, shell=True, cwd=cwd,
                           capture_output=True, text=True,
                           stdin=subprocess.DEVNULL, env=env)
    context.result = result
    context.stdout = result.stdout.strip()
    context.stderr = result.stderr.strip()
    context.returncode = result.returncode
    context.last_command = command
    _track_created_entry(context, command, result)
```

### Fixture filename determinism

The `create_entry()` helper uses a counter-based filename: `2024-01-01_00-00-{NN}Z.md`. This means:
- Multiple entries in one scenario get unique filenames
- The sort order is deterministic (higher NN = "more recent")
- No real clock dependency

### Command name substitution

The old code does `command.replace('ticket ', ...)`. The new code does `command.replace('change_log ', ...)`. Since `change_log` contains an underscore (not a space), there is no ambiguity risk with argument parsing.

### JSONL vs JSON output from create

The `cmd_create()` function calls `_file_to_jsonl()` which outputs a single JSONL line. This IS valid JSON (a single-line JSON object). So assertions like `output should be valid JSON with an id field` AND `output should be valid JSONL` both work.

### Pre-existing quirks documented in Phase 01 callouts

Two known pre-existing issues are NOT tested (intentionally):
1. `json_escape()` double-escaping of embedded quotes -- inherited from original script, not a regression
2. Missing flag argument error (`$2: unbound variable`) -- fails correctly but message is confusing

These are explicitly out of scope for testing.

---

## Testing Strategy

Each phase produces a working feature file that can be validated independently:
- After Phase 3: `uv run --with behave behave features/changelog_creation.feature`
- After Phase 4: `uv run --with behave behave features/changelog_listing.feature`
- ...and so on

Final validation: `make test` runs all feature files together.

Edge cases covered:
- Impact boundary values (1, 5, 0, 6, non-numeric)
- Empty changelog directory
- Partial/ambiguous/non-existent ID resolution
- Optional fields omitted from frontmatter when not provided
- Map fields (`ap`, `note_id`) with YAML formatting
- Array fields (`tags`, `dirs`) with YAML formatting
- Timestamp-based filename format verification

---

## Open Questions / Decisions

1. **Piped stdin for notes**: The old test suite had a step `I run "..." with no stdin` but no explicit stdin-piping step. The `add-note` command supports piped stdin. We should add one scenario testing piped input: `echo "piped note" | change_log add-note <id>`. This requires a new When step or using shell piping in the command string.

   **Recommendation**: Skip the dedicated piping step for now. The existing "with no stdin" step (which uses `subprocess.DEVNULL`) is sufficient. The piped stdin behavior is an implementation detail that can be tested via direct command string: `I run "echo 'piped note' | change_log add-note <id>"` which works since commands run in shell mode. If the implementor finds this cleaner, they may add it.

2. **Author field**: The `create` command defaults author to `git config user.name`. In test temp dirs (which are not git repos but have `CHANGE_LOG_DIR` set), `git config user.name` may or may not be set from the global git config. We should NOT test the default author value since it depends on the test runner's git config. We CAN test explicit `--author` flag.

   **Recommendation**: Add one scenario `Create with --author` that passes `-a 'Test Author'` and verifies the field. Do not test the default.

3. **Scenario count**: The plan targets ~67 scenarios (down from 131). This is intentional per 80/20 principle -- the removed commands (status, deps, links, plugins) accounted for 44 scenarios, and the simplified data model means fewer permutations to test.
