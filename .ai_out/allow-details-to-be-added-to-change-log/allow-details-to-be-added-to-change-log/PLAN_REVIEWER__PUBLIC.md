# Plan Review: Strip Partial ID Matching + Add `--details_in_md` Flag

## Executive Summary

The plan is well-structured, correctly scoped, and aligns with PARETO/KISS principles. Both changes are localized and straightforward. I found a few inaccuracies in line number references and one minor gap in the `--details_in_md` handling of `\n` escape sequences that needs a design decision. Overall the plan is solid -- **APPROVED WITH MINOR REVISIONS** (inline below, no plan iteration needed).

## Critical Issues (BLOCKERS)

None.

## Major Concerns

### 1. `\n` in `--details_in_md` will NOT produce newlines with `printf '%s\n'`

- **Concern:** The plan's test scenario says: `--details_in_md "## Context\nDetailed explanation"`. With `printf '%s\n' "$details"`, the literal string `\n` will be written as-is (two characters: backslash + n), not as a newline. This is the correct/safe behavior as the plan acknowledges (Section 4, "Decision"). However, the test scenario then checks for `## Context` which implies the `\n` would be a newline separator. If the agent passes `"## Context\nDetailed explanation"` as a bash argument, the `\n` is literal -- so the file will contain `## Context\nDetailed explanation` on a single line, and `## Context` would still match (it is a substring). So the test technically passes, but it may be misleading.
- **Suggestion:** Make the test scenario clearer. Either:
  - (a) Use a simpler single-line test text: `--details_in_md "## Context and detailed explanation"`, OR
  - (b) Document explicitly that `\n` is NOT interpreted, and test with a `$'...\n...'` example for real newlines if that behavior is desired.
  - This is a **documentation/test clarity issue**, not a code issue. The `printf '%s\n'` approach is correct.

## Inaccuracies in the Plan (Corrections)

### 1. Line number references for `entry_path()` are off by 1

- **Plan says:** `entry_path()` function at lines 86-130, awk at lines 100-123.
- **Actual:** `entry_path()` starts at line 87 (the function declaration). Line 86 is the comment. The awk runs lines 102-123. This is minor but noting for implementer precision.

### 2. Help text line number references are wrong

- **Plan says:** "Update help text in `cmd_help()` (line 519)" and references L524 for "IDs stored in frontmatter; supports partial ID matching".
- **Actual:** `cmd_help()` starts at line 499. The `show <id>` line with "supports partial ID" is at line **516** (not 519). The line "IDs stored in frontmatter; supports partial ID matching" does **NOT exist** in the script's help text at all -- it only exists in `README.md` at line 59. The plan should update the README reference (L59) but NOT reference this line in `cmd_help()`.
- **Impact:** The implementer might search for a non-existent line in the script. Corrected guidance:
  - In `change_log` L516: Change `show <id>                 Display entry (supports partial ID)` to `show <id>                 Display entry`
  - In `README.md` L51: Same change as above
  - In `README.md` L59: Remove `IDs stored in frontmatter; supports partial ID matching`

### 3. Plan says to remove "IDs stored in frontmatter; supports partial ID matching" from help -- but it is not there

- **Plan step 4, Phase 1:** "Remove 'IDs stored in frontmatter; supports partial ID matching' line (near bottom of help, currently not present in exact form but check)."
- **Actual:** Correct -- this line is NOT in the help text. It IS in `README.md` L59. The plan already hedged with "(currently not present in exact form but check)" so this is fine, but the implementer should know: **only update README.md for this line**.

### 4. `entry_path()` comment is at line 86, not "the function comment on line 86"

- Trivial: The comment `# Get entry file path by searching frontmatter id: fields (supports partial ID matching)` is indeed at line 86. The function body starts at line 87. The plan says "Update the function comment on line 86" which is correct.

## Simplification Opportunities (PARETO)

### 1. The defensive `count > 1` exact match case in the simplified awk can be simplified further

The plan proposes keeping `if (count > 1) { ambiguous error }`. This is fine and cheap. No change needed.

### 2. Consider NOT renaming the flag if `--details` is simpler than `--details_in_md`

- The flag `--details_in_md` is somewhat verbose. A simpler `--details` flag name would be shorter and the "in md" part is implicit (the entire tool is markdown-based). However, the plan's rationale is to be explicit about the content type, which aligns with the "Be Explicit" principle. This is a judgment call. If the human engineer prefers brevity, `--details` is sufficient.
- **Not blocking.** Current name is fine.

## Minor Suggestions

### 1. Test scenario for "Create without --details_in_md has no body"

- The plan describes: "Verify by checking entry file has expected line count or structure." This is vague. The simplest approach: check that the file content after the closing `---` is just a blank line (which is the current behavior). The existing `the created entry should not contain` step could check for absence of a marker. But since the current entries already end with `---\n\n`, there is nothing specifically "wrong" to check. Consider just checking `the created entry should not contain "## "` or similar. Or skip this test -- the existing creation tests already implicitly verify this.
- **Suggestion:** Keep it simple. The absence of body content is already the default behavior covered by all existing creation tests. A dedicated test adds little value.

### 2. The `AFTER_COMPLETION` help text already hints at details

- Line 526: `"AFTER_COMPLETION_OF_ITEM: Add change log entry for the completed item with clear title. Concise description and more detailed explanation within the markdown."`
- The plan mentions updating this. After the `--details_in_md` flag is added, this guidance naturally maps: `title` = clear title, `--desc` = concise description, `--details_in_md` = detailed explanation. The plan could explicitly note this mapping for the help text update.

### 3. The `entry_path()` function comment at L86 mentions "supports partial ID matching"

- The plan correctly identifies this for update. Confirmed present at L86 in source.

## Strengths

- **Correct identification of `_file_to_jsonl()` not needing changes.** The awk's `in_front` toggle means body content after frontmatter is automatically excluded from JSONL output. This is the key insight that makes the `--details_in_md` feature cheap.
- **Complete test coverage plan.** All affected feature files are identified. The new "substring does NOT match" negative test is a good addition.
- **Correct analysis of `printf` vs `echo`.** Using `printf '%s\n'` for safety is the right call.
- **Clean separation into phases.** Phase 1 (remove partial ID) and Phase 2 (add details) are independent and well-scoped.
- **All affected files are identified.** The Files Changed Summary table is complete and accurate.
- **Defensive awk kept.** The `count > 1` exact match case costs nothing and prevents undefined behavior.

## Files Referenced

| File | Path |
|------|------|
| Main script | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/change_log` |
| ID resolution tests | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/id_resolution.feature` |
| Show tests | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_show.feature` |
| Edit tests | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_edit.feature` |
| Notes tests | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_notes.feature` |
| Creation tests | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_creation.feature` |
| Query tests | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/changelog_query.feature` |
| Step definitions | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/features/steps/changelog_steps.py` |
| README | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/README.md` |
| CHANGELOG | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/CHANGELOG.md` |
| CLAUDE.md | `/usr/local/workplace/mirror/thorg-root-mirror-2/submodules/change_log/CLAUDE.md` |

## Verdict

- [ ] APPROVED
- [x] APPROVED WITH MINOR REVISIONS
- [ ] NEEDS REVISION
- [ ] REJECTED

**Rationale:** The plan is correct in its approach and covers all the right files. The inaccuracies are limited to line number references and one non-existent help text line -- these are minor and corrected inline above. The `\n` test scenario is a clarity issue, not a correctness issue. **PLAN_ITERATION can be skipped** -- the implementer can use this review's corrections directly during implementation.
