# IMPLEMENTATION_REVIEWER__PRIVATE: Fix Frontmatter Awk Toggle

## Review Status: COMPLETE - SHIP

## Verification Steps Performed

1. **Read all context files** (exploration, implementor summary, script, feature file, step defs)
2. **Ran full test suite**: `make test` -- 72 scenarios passed, 0 failed, 375 steps passed
3. **Verified git diff**: Only additions, no removals of existing tests or functionality
4. **Manual testing**:
   - Created entry with `---` in body, ran `query` -- body content excluded (fix works)
   - Ran `ls` with same entry -- correct title displayed
   - Tried `show fake_id_from_body` where `id: fake_id_from_body` was in body after `---` -- correctly returns "not found"
5. **Verified no old toggle patterns remain**: `grep 'in_front = !in_front'` returns empty
6. **Verified all 3 locations use identical counter pattern**: fm_delim init, reset, increment logic matches exactly
7. **Checked `$'...'` in BDD test**: `shell=True` in subprocess.run ensures ANSI-C quoting is interpreted by bash

## Edge Cases Checked

| Edge Case | Result |
|-----------|--------|
| Normal 2-delimiter file | Same as before, correct |
| Body with `---` (3+ delimiters) | Fixed -- in_front stays 0 |
| No frontmatter (0 delimiters) | in_front stays 0, no fields extracted |
| Malformed (1 delimiter) | Same as before -- treats rest as frontmatter |
| Multi-file awk pass | fm_delim resets on FNR==1, correct |

## Notes for Future

- `yaml_field()` has a related sed range issue (pre-existing, out of scope)
- `ticket` script in note-ticket submodule has same bug in 10 locations (noted in exploration, separate concern)
- Three awk blocks could be DRYed up in a future refactor but current duplication is acceptable (4 lines each)

## Risk Assessment: LOW
- Fix is mechanical and well-understood
- No behavioral change for well-formed files
- Only affects files with `---` in body (which was always broken before)
