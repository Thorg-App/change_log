# Plan: Fix `find_change_log_dir()` to Respect Submodule Boundaries

## 1. Problem Understanding

**Goal:** Make `find_change_log_dir()` stop at the nearest `.git` boundary (file or directory) instead of using `git rev-parse --show-toplevel`, which incorrectly resolves to the parent repo root for submodules.

**Key insight:** Git submodules have a `.git` **file** (containing `gitdir: ../path`), while regular repos have a `.git` **directory**. Both indicate "this is a repo root." The parent-walk should treat either form as a boundary.

**Constraints:**
- Maintain backward compatibility for all existing scenarios
- Keep the function simple (no git commands needed at all)
- The env var `CHANGE_LOG_DIR` override remains unchanged

**Assumptions:**
- Every repo (submodule or regular) has `.git` at its root
- Users always run `change_log` from within a git repo (or use `CHANGE_LOG_DIR`)

## 2. High-Level Architecture

No architectural change. This is a single-function modification in the `change_log` bash script, plus new BDD test scenarios.

**Data flow (after change):**
```
find_change_log_dir():
  1. CHANGE_LOG_DIR env var? -> return it (unchanged)
  2. Walk parents from $PWD upward:
     a. Found .change_log/ ? -> return it (unchanged)
     b. Found .git (file OR dir)? -> mkdir .change_log/ here, return it (NEW)
  3. Not found -> error (unchanged, but now triggers when not in any repo)
```

The `git rev-parse --show-toplevel` fallback is entirely removed. The walk itself now detects `.git`, making the git command redundant.

## 3. Implementation Phases

### Phase 1: Modify `find_change_log_dir()` in `change_log` script

**Goal:** Add `.git` detection to the parent walk, remove the `git rev-parse` fallback.

**File:** `/usr/local/workplace/mirror/thorg-root-mirror-5/submodules/change_log/change_log` (lines 8-39)

**Key Steps:**

1. In the `while` loop body (after the `.change_log/` check), add a check for `.git`:
   - Check `-e "$dir/.git"` (covers both file and directory with a single test)
   - If found, `mkdir -p "$dir/.change_log"`, echo it, and return 0

2. After the loop, also check root `/` for `.git` (mirrors the existing `.change_log` root check). This is for completeness, though unlikely in practice.

3. Remove the `git rev-parse --show-toplevel` block entirely (lines 28-34). It is now redundant.

4. Keep the error message on line 37 but update the comment to reflect the new logic.

**Resulting function structure:**
```bash
find_change_log_dir() {
    # 1. Env var override
    if [[ -n "${CHANGE_LOG_DIR:-}" ]]; then
        echo "$CHANGE_LOG_DIR"
        return 0
    fi

    # 2. Walk parents looking for .change_log/ or .git boundary
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.change_log" ]]; then
            echo "$dir/.change_log"
            return 0
        fi
        if [[ -e "$dir/.git" ]]; then
            mkdir -p "$dir/.change_log"
            echo "$dir/.change_log"
            return 0
        fi
        dir=$(dirname "$dir")
    done

    # Check root too
    [[ -d "/.change_log" ]] && { echo "/.change_log"; return 0; }
    [[ -e "/.git" ]] && { mkdir -p "/.change_log"; echo "/.change_log"; return 0; }

    # 3. Not in a git repository
    echo "Error: no .change_log directory found and not in a git repository" >&2
    return 1
}
```

**Why `-e` instead of `-d` or `-f`:** `-e` returns true for both files and directories. This is the simplest single check that covers both regular repos (`.git` directory) and submodules (`.git` file).

**Verification:** Run `make test` -- all existing tests must pass.

---

### Phase 2: Add BDD Test Scenarios

**Goal:** Cover the three key behaviors with explicit test scenarios.

**Files to modify:**
- `features/changelog_directory.feature` -- add new scenarios
- `features/steps/changelog_steps.py` -- add new step definitions

#### 2a. New Scenarios in `changelog_directory.feature`

Add these scenarios (place them after the existing "Create auto-creates changelog directory at git root" scenario):

**Scenario 1: Auto-creates changelog in regular repo (`.git` directory)**

This is essentially the existing "Create auto-creates changelog directory at git root" scenario, but let's make it explicit about verifying `.change_log/` is created at the `.git` boundary. The existing scenario already covers this, so no new scenario needed here -- just verify it still passes.

**Scenario 2: Auto-creates changelog in submodule (`.git` file)**

```gherkin
Scenario: Auto-creates changelog in submodule with .git file
  Given the changelog directory does not exist
  And the test directory has a .git file (simulating a submodule)
  When I run "change_log create 'Submodule entry' --impact 1"
  Then the command should succeed
  And the changelog directory should exist
```

**Scenario 3: Existing `.change_log/` takes priority over `.git`**

```gherkin
Scenario: Existing changelog directory takes priority over .git boundary
  Given a clean changelog directory
  And the test directory is a git repository
  And a changelog entry exists with ID "priority-001" and title "Priority entry"
  And I am in subdirectory "src/deep"
  When I run "change_log ls"
  Then the command should succeed
  And the output should contain "priority-0"
```

This scenario is actually already covered by the existing "Find changelog in parent directory" scenario structure. But it's good to have one that explicitly combines `.git` presence with `.change_log/` to confirm `.change_log/` wins.

**Scenario 4: Subdirectory of submodule finds changelog at submodule root**

```gherkin
Scenario: Finds changelog at submodule root from subdirectory
  Given the changelog directory does not exist
  And the test directory has a .git file (simulating a submodule)
  When I run "change_log create 'Deep entry' --impact 2" from subdirectory "src/components"
  Then the command should succeed
  And the changelog directory should exist
```

Wait -- running `create` from a subdirectory. Let me reconsider. The `_run_command` uses `context.working_dir`. The `I am in subdirectory` step creates the dir and sets `context.working_dir`. Let me simplify:

```gherkin
Scenario: Finds changelog at submodule root from subdirectory
  Given the changelog directory does not exist
  And the test directory has a .git file (simulating a submodule)
  And I am in subdirectory "src/components"
  When I run "change_log create 'Deep entry' --impact 2"
  Then the command should succeed
  And the changelog directory should exist
```

#### 2b. New Step Definition

One new `Given` step is needed:

```python
@given(r'the test directory has a \.git file \(simulating a submodule\)')
def step_test_dir_has_git_file(context):
    """Create a .git file (not directory) to simulate a submodule root."""
    git_file = Path(context.test_dir) / '.git'
    # Remove .git directory if git init was run
    if git_file.is_dir():
        import shutil
        shutil.rmtree(git_file)
    git_file.write_text('gitdir: ../../../.git/modules/my-submodule\n')
```

This creates a `.git` file with the format git uses for submodules. The actual `gitdir` path doesn't need to resolve -- `change_log` only checks for the existence of `.git`, not its contents.

**Verification:** Run `make test` -- all tests (old and new) must pass.

---

### Phase 3: Update Documentation

**Goal:** Keep README.md and CLAUDE.md accurate.

**Key Steps:**
1. In `CLAUDE.md`, update the `find_change_log_dir()` description to mention `.git` boundary detection instead of `git rev-parse --show-toplevel`.
2. In `README.md`, the description already says "auto-created at git repo root" which is still accurate. No change needed unless we want to mention submodule support explicitly.

---

## 4. Technical Considerations

**Edge case -- nested `.change_log/` directories:** The walk finds the NEAREST `.change_log/` first (closest to `$PWD`), then the nearest `.git`. This is correct: if someone manually placed a `.change_log/` in a subdirectory, it would be used. This matches existing behavior.

**Edge case -- `.git` at root `/`:** Extremely unlikely but handled by the root check after the loop.

**Edge case -- no `.git` and no `.change_log/`:** The function falls through to the error, same as before. The error message remains accurate ("not in a git repository").

**Performance:** No change. The walk is O(depth) and only does `stat` calls. Removing the `git rev-parse` subprocess is actually a micro-improvement.

**Error message:** The existing error message "no .change_log directory found and not in a git repository" remains accurate because if the walk found no `.git`, the user is indeed not in a git repository.

## 5. Testing Strategy

### Scenarios to verify (existing + new):

| # | Scenario | Expected Behavior | Status |
|---|----------|--------------------|--------|
| 1 | Find changelog in current directory | Returns existing `.change_log/` | Existing test |
| 2 | Find changelog in parent directory | Walks up, finds `.change_log/` | Existing test |
| 3 | Find changelog in grandparent directory | Walks up, finds `.change_log/` | Existing test |
| 4 | CHANGE_LOG_DIR env var override | Uses env var | Existing test |
| 5 | Create auto-creates at git root (`.git` dir) | Creates `.change_log/` next to `.git/` | Existing test |
| 6 | Create auto-creates at submodule root (`.git` file) | Creates `.change_log/` next to `.git` file | **NEW** |
| 7 | `.change_log/` found before `.git` | `.change_log/` wins | Implicitly covered, explicit test recommended |
| 8 | Subdirectory of submodule | Walk finds `.git` file at submodule root | **NEW** |
| 9 | No `.change_log/`, no `.git` | Error message | Existing test |
| 10 | Help without changelog dir | Works (no dir needed) | Existing test |

### Acceptance Criteria:

1. `make test` passes with zero failures
2. Running `change_log create` inside a simulated submodule (`.git` file) creates `.change_log/` at the submodule root, NOT the parent repo root
3. Running `change_log create` inside a regular repo (`.git` directory) creates `.change_log/` at the repo root (unchanged behavior)
4. Existing `.change_log/` directories are still discovered before `.git` boundaries
5. The `git rev-parse --show-toplevel` call is completely removed from the script

## 6. Open Questions / Decisions Needed

None. The change is straightforward and well-defined.
