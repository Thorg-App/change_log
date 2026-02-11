# DRY Analysis: Phase 02 BDD Test Suite

## Result

3 knowledge duplication violations found and fixed. 2 dead code items removed. All 76 scenarios pass after changes.

## Violations Found and Fixed

### FIX-01: `step_pipe_to_command` duplicated `_run_command` subprocess logic

**Knowledge duplicated**: "How to execute a change_log command and capture results on context."

`step_pipe_to_command` (old lines 271-295) contained a full copy of the subprocess execution pattern from `_run_command` -- command substitution, cwd resolution, subprocess.run, storing results on context, and calling `_track_created_entry`. The only difference was `input=input_text` vs `stdin=subprocess.DEVNULL`.

**Change test**: If the execution pattern changes (e.g., adding timeout, changing env handling), both would need to change together. Same knowledge.

**Fix**: Added `input_text=None` parameter to `_run_command`. When provided, passes `input=input_text` to subprocess; otherwise passes `stdin=subprocess.DEVNULL`. Reduced `step_pipe_to_command` to a single delegation call.

**Lines removed**: ~20

### FIX-02: `step_separate_changelog_dir` duplicated entry creation knowledge from `create_entry`

**Knowledge duplicated**: "How to create a changelog entry fixture file with YAML frontmatter."

`step_separate_changelog_dir` (old lines 206-225) contained an inline copy of the YAML frontmatter template, title escaping, and file-writing logic that already existed in `create_entry()`. If the frontmatter format changes (e.g., adding a new required field), both would need to change together.

**Fix**: Added `target_dir=None` parameter to `create_entry`. When provided, uses that directory instead of `<test_dir>/change_log/`. Reduced `step_separate_changelog_dir` to two lines: resolve the path and delegate to `create_entry`.

**Lines removed**: ~15

### FIX-03: JSONL parsing repeated across 4 step definitions

**Knowledge duplicated**: "How to parse JSONL output from command stdout."

Four step definitions (`step_output_valid_jsonl`, `step_jsonl_has_field`, `step_every_jsonl_line_has_field`, `step_jsonl_has_numeric_field`) all independently parsed JSONL with the same pattern:
```python
lines = context.stdout.strip().split('\n')
for line in lines:
    if line.strip():
        data = json.loads(line)
```

If JSONL parsing needs to change, all four would change together. Same knowledge.

**Fix**: Extracted `_parse_jsonl(stdout)` helper that returns a `list[dict]`. All four steps now delegate parsing to this single function and operate on the returned list.

**Lines removed**: ~15

## Dead Code Removed

### DEAD-01: `step_output_matches_entry_id_pattern` -- unused step definition

Not referenced by any feature file. Nearly identical to `step_output_valid_json_with_id` (which IS used), with only a non-empty string check added. Removed entirely.

### DEAD-02: `step_run_command_no_stdin` -- unused step definition

Not referenced by any feature file. Identical implementation to `step_run_command` (both delegate to `_run_command` with no extra args). Removed entirely.

## Items Analyzed but NOT Violations

### `step_run_command_non_tty` vs `step_run_command` -- NOT a violation

Both delegate identically to `_run_command`, but they represent **different semantic knowledge** in the Gherkin layer: "running in non-TTY mode" vs "running normally". Today their implementation is the same, but the non-TTY concept could diverge (e.g., setting `TERM=dumb`). Different knowledge, same code -- acceptable.

### `step_clean_changelog_directory` vs `step_changelog_dir_not_exist` -- NOT a violation

Both interact with the changelog directory path, but they represent different knowledge: "ensure a clean directory exists" vs "ensure no directory exists." They would not change together. Different knowledge.

### Feature file Background sections -- no violations

All 8 feature files already use `Background:` sections appropriately. No duplicated Given patterns that should be consolidated into Background blocks.

### `environment.py` empty hooks -- NOT a violation

`before_feature` and `after_feature` are empty pass-through hooks. While they could be removed, they serve as documented extension points and do not represent duplicated knowledge.

## Test Results After Fixes

```
8 features passed, 0 failed, 0 skipped
76 scenarios passed, 0 failed, 0 skipped
394 steps passed, 0 failed, 0 skipped
Took 0min 0.694s
```

## Files Modified

- `features/steps/changelog_steps.py` -- 3 DRY fixes applied, 2 dead code items removed (~50 lines net reduction)
