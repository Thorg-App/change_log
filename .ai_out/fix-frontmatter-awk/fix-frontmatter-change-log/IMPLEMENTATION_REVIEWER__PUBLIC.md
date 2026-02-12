# Code Review: Fix Frontmatter Awk Toggle Bug

## Summary

This PR fixes a correctness bug where awk frontmatter parsers used `in_front = !in_front` to toggle frontmatter mode on/off at `---` delimiters. When markdown body content contained `---` (horizontal rule), the toggle would re-enter frontmatter mode, causing `key: value` lines after the rule to leak into JSONL output, corrupt `ls` display, and produce false ID matches in `entry_path`.

The fix replaces the boolean toggle with a counter (`fm_delim++`) at all 3 affected awk blocks. After the 2nd `---`, `in_front` stays 0 permanently for that file. The change is minimal, consistent across locations, and well-tested.

**Overall assessment: Clean, correct, minimal fix. SHIP.**

---

## Review Verdicts

| Area | Verdict | Notes |
|------|---------|-------|
| Correctness | PASS | Counter-based approach is sound. Edge cases verified. |
| Consistency | PASS | Identical pattern applied at all 3 locations. |
| Test coverage | PASS | New BDD scenario directly exercises the bug. |
| Regressions | PASS | No existing tests removed. All 72 scenarios pass (375 steps). |
| Code quality | PASS | Minimal diff, follows project conventions. |

---

## Correctness Analysis

The fix is correct for all edge cases:

- **Normal file (2 delimiters):** `fm_delim` goes 1 then 2. `in_front` goes 1 then 0. Identical to old behavior.
- **Body with `---` (3+ delimiters):** `fm_delim` goes 1, 2, 3+. After 2, `in_front` stays 0. Bug is fixed.
- **No frontmatter (0 delimiters):** `fm_delim` stays 0, `in_front` stays 0. No fields extracted. Correct.
- **Malformed frontmatter (1 delimiter):** `fm_delim` goes to 1, `in_front` goes to 1, never exits. Same as old behavior -- entire file treated as frontmatter. Acceptable for malformed input.
- **Multi-file processing:** `fm_delim` is reset to 0 in the `FNR==1` block. Each file starts fresh. Correct.

Manually verified that:
- `query` output excludes body `key: value` lines after `---` in body.
- `ls` displays correct title (not body content).
- `show fake_id_from_body` correctly returns "not found" when `id:` appears only in body after a `---`.

## Consistency Analysis

All 3 awk blocks (`_file_to_jsonl` at line ~147, `entry_path` at line ~102, `cmd_ls` at line ~471) use the identical pattern:

```awk
BEGIN { ...; fm_delim=0 }
FNR==1 { ...; fm_delim=0; ... }
/^---$/ {
    fm_delim++
    if (fm_delim == 1) in_front = 1
    else if (fm_delim == 2) in_front = 0
    next
}
```

No old `in_front = !in_front` patterns remain in the file.

## Test Coverage Analysis

The new scenario ("Query does not leak body content when details contain markdown horizontal rule") is well-constructed:
- Creates an entry with `---` in the body via `--details_in_md $'Some details\n\n---\n\nfake_field: leaked_value\nstatus: should_not_appear'`
- The `$'...'` ANSI-C quoting is correctly interpreted by bash since steps use `shell=True` in `subprocess.run`
- Asserts that `real desc` (from frontmatter) IS present in query output
- Asserts that `leaked_value`, `fake_field`, and `should_not_appear` (from body) are NOT present

This directly exercises the exact bug: body content after `---` with `key: value` patterns.

## No Issues Found

No CRITICAL or IMPORTANT issues identified.

## Suggestions

1. **Test coverage for `ls` and `show`**: The new BDD test only covers `query`. While the fix is identical across all 3 awk blocks, adding one scenario for `ls` (verifying body `key: value` after `---` doesn't corrupt the listing) would provide full coverage. Low priority since the awk logic is mechanically identical.

2. **`yaml_field()` has a related (pre-existing) issue**: The `sed -n '/^---$/,/^---$/p'` range can re-enter on a 3rd `---` in the body. This is out of scope for this PR but worth noting for a future cleanup pass. Risk is low since `yaml_field()` is only used by `id_from_file()` and `cmd_add_note()`, and the `_grep` pipe filters to exact field names.

3. **DRY opportunity (future)**: The three awk blocks share the same frontmatter parsing preamble. A future refactor could extract this into a shared awk include or a single function that handles all three use cases. Not blocking -- the current duplication is small (4 lines each) and the contexts are sufficiently different.

## Recommendation

**SHIP** -- The fix is correct, minimal, consistent, well-tested, and introduces no regressions.
