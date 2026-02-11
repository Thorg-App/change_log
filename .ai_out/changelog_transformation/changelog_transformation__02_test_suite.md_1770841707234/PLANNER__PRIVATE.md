# PLANNER Private Context: Phase 02 Test Suite

## Key Decisions Made

1. **Consolidated `_run_command()` helper** - DRYs up 4 near-identical subprocess invocations into one helper. This is the most impactful refactoring in the step definitions.

2. **Counter-based fixture filenames** - `2024-01-01_00-00-{NN}Z.md` pattern. Simple, deterministic, sortable. No real clock dependency. Higher NN = more recent (for testing ls ordering).

3. **~67 scenarios total** - Down from 131. The reduction is entirely due to removed commands (status, deps, links, plugins = 44 scenarios) plus simplification of listing/show scenarios that tested features no longer present.

4. **Feature file naming**: `changelog_*.feature` (not `entry_*.feature`). This matches the tool name `change_log` and the directory name `change_log/`.

5. **`id_resolution.feature` kept as same filename** - No reason to rename since it doesn't have `ticket_` prefix.

## Gotchas to Watch For

1. **Regex step ordering** - Behave regex matcher tries steps in definition order. The more specific patterns (`entry exists with impact`, `entry exists with type`) MUST be defined BEFORE the generic `entry exists with ID and title`. Same for When steps: `I run "X" with CHANGE_LOG_DIR` must come before `I run "X"`.

2. **Git init in test dirs** - The test temp dirs are NOT git repos. The `find_change_log_dir()` auto-create path needs a git repo. For directory discovery tests, most scenarios pre-create `change_log/` via Background. The "auto-create at git root" behavior would need `git init` in the test dir, but the current test suite does NOT test this behavior directly (old suite didn't either -- it used `TICKETS_DIR` env var or pre-created `.tickets/`). Skip this test.

3. **Error when no changelog dir** - Tests that expect the "no change_log directory found" error rely on the temp dir NOT being a git repo AND not having a `change_log/` dir. The `before_scenario` creates a temp dir without git init, so this works. BUT if Background says "a clean changelog directory" it CREATES the dir. The error scenarios must NOT use this Background -- they should use a different Background or standalone Given steps.

4. **Non-TTY mode** - All subprocess calls use `stdin=subprocess.DEVNULL`. The `change_log edit` command checks `[ -t 0 ] && [ -t 1 ]` for TTY detection. Since test subprocess has no TTY, it falls through to `echo "Edit entry file: $file"`. This is correct.

5. **`change_log` command substitution** - The When step does `command.replace('change_log ', f'{script} ', 1)`. This replaces only the FIRST occurrence. If a command string contains "change_log" elsewhere (unlikely but possible in jq filter strings), it won't be affected. This is correct behavior.

6. **Fixture frontmatter does NOT include author** - The `create_entry()` helper omits `author:` from the fixture. The `change_log` script defaults to `git config user.name` which may be empty in test environments. This is fine since most tests don't care about author.

7. **Phase 1 callouts to preserve**: The `json_escape()` double-escaping quirk and the missing-flag-argument error are explicitly NOT tested. They are documented as known pre-existing issues in the high-level design.

## Scenario Count by File

| File | Scenarios |
|---|---|
| changelog_creation.feature | 24 |
| changelog_listing.feature | 7 |
| changelog_show.feature | 5 |
| changelog_edit.feature | 3 |
| changelog_notes.feature | 7 |
| changelog_query.feature | 8 |
| changelog_directory.feature | 8 |
| id_resolution.feature | 8 |
| **Total** | **70** |

## Implementation Risk Assessment

- **LOW RISK**: Feature files are straightforward Gherkin translations
- **MEDIUM RISK**: Step definitions -- the `_run_command()` consolidation and `create_entry()` helper are foundational. Getting these wrong breaks everything.
- **LOW RISK**: Environment.py changes are trivial renames
- **MEDIUM RISK**: Directory discovery tests -- edge cases around git repo detection in temp dirs

## Files to Touch Summary

### DELETE
- features/ticket_status.feature
- features/ticket_dependencies.feature
- features/ticket_links.feature
- features/ticket_plugins.feature
- features/ticket_creation.feature
- features/ticket_listing.feature
- features/ticket_show.feature
- features/ticket_query.feature
- features/ticket_directory.feature
- features/ticket_notes.feature
- features/ticket_edit.feature
- features/steps/ticket_steps.py

### CREATE
- features/steps/changelog_steps.py
- features/changelog_creation.feature
- features/changelog_listing.feature
- features/changelog_show.feature
- features/changelog_edit.feature
- features/changelog_notes.feature
- features/changelog_query.feature
- features/changelog_directory.feature

### REWRITE IN-PLACE
- features/id_resolution.feature

### EDIT
- features/environment.py
