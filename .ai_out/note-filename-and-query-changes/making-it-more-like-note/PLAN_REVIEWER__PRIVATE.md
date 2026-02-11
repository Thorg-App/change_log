# Plan Reviewer Private Notes

## Review Session: 2026-02-11

### Key Observations

1. **ticket_path() rewrite is the riskiest change** -- plan proposes a single awk pass. The pseudocode in the plan is incomplete/inconsistent (it shows stderr redirection but then says "actually, the simplest approach"). The implementor needs a clean, final specification, not a thinking-out-loud narrative.

2. **The awk `FS=": "` convention interacts badly with quoted titles.** When frontmatter has `title: "My Title: Subtitle"`, the `FS=": "` will split on the colon in the title value. The plan acknowledges quoting but doesn't address the FS interaction. All 7 awk scripts use `FS=": "` and extract `$2`, which will truncate at the first `: ` in the value. The proposed `title = substr($0, 8)` approach in Phase 5 is correct and avoids this problem -- but the plan should be explicit that FS-based extraction (`$2`) MUST NOT be used for title.

3. **`_file_to_jsonl()` DRY approach is sound** but there's a subtlety: when called from `cmd_create()` it operates on a single file, while `cmd_query()` uses a glob. The awk script's `FNR==1` logic only triggers on file boundaries. For a single file, the `END` block handles the last file. This will work correctly.

4. **Test step `step_run_command()` line 324-325**: The `last_created_id` extraction currently does `context.last_created_id = result.stdout.strip()`. After the change, create outputs JSON. The plan correctly identifies this at Phase 8 Step 5 but the extraction logic needs to handle the case where stdout might have trailing newlines or multiple JSON lines (it shouldn't, but defensively).

5. **Missed: `cmd_edit()` output change.** The `cmd_edit()` function at line 1317 outputs `echo "Edit ticket file: $file"`. The filename will change, so the test at `ticket_edit.feature:14` checking for `.tickets/edit-0001.md` will fail. The plan mentions this at Phase 9 Step 6 but doesn't address it in the implementation phases. The fix is trivial -- the output naturally changes since it uses `$file` which is already the resolved path.

6. **Missed: `cmd_dep()` dedup check at line 636.** `echo "$current_deps" | _grep -q "$dep_id"` -- with 25-char IDs, substring matching could cause false positives (e.g., if one ID is a substring of another). With 25-char random IDs this is astronomically unlikely, so this is a non-issue in practice. Not a blocker.

7. **Missed: The `cmd_link()` awk script at line 1024** extracts IDs via `basename "$file" .md`. The plan's Phase 4 Step 7 covers `cmd_link()` but only mentions `ids+=("$(id_from_file "$file")")`. There's also the awk script within cmd_link itself that uses `self` and `others` variables -- these are already passed as shell variables derived from `ids[]`, so Phase 4's fix propagates correctly. No issue.

8. **Missed: `migrate-beads` writes old-format files.** The plan doesn't mention updating `cmd_migrate_beads()`. Since this is a "clean break," the migration command should probably be left as-is OR updated to produce new-format files. The plan should explicitly state whether migrate-beads is in-scope or not.

9. **Potential issue: `update_yaml_field()` with quoted title values.** The function uses sed `s/^${field}:.*/${field}: ${value}/`. If the title contains special sed characters (/, &, etc.), this will break. Since the title is always written during create and not updated via `update_yaml_field()`, this is likely a non-issue for the title field specifically. But worth noting.

10. **Phase ordering concern:** Phases 1-7 (script changes) before 8-9 (test changes) means the implementor will break ALL tests for a sustained period. An alternative would be to update tests alongside each phase. But the plan's approach allows manual smoke testing between phases, which is pragmatic.

### Verdict Assessment

The plan is thorough and well-structured. The issues I found are mostly minor clarifications. There are two items that need explicit resolution before implementation:
- The `ticket_path()` pseudocode needs to be finalized (not left as "actually, the simplest approach is...")
- The `migrate-beads` question needs to be explicitly scoped out
