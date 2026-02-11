# Phase 03: Repo Cleanup and Documentation -- Implementation Plan

## 1. Problem Understanding

The `ticket` CLI has been fully transformed into `change_log` (Phase 01) and all BDD tests rewritten (Phase 02). The repo still contains dead files from the old ticketing system (the `ticket` script, plugin infrastructure, packaging configs, CI workflows, stale AI files) and all three documentation files (README.md, CLAUDE.md, CHANGELOG.md) still describe the old system. This phase deletes the dead files and rewrites documentation.

### Constraints
- `make test` must pass after all changes (76 scenarios, 394 steps)
- Do NOT delete: `doc/ralph/`, `.idea/`, `.ai_out/`, `LICENSE`, `features/`, `change_log`
- No "ticket" references should remain in documentation (CLAUDE.md, README.md)
- The `features/steps/ticket_steps.py` was already removed in Phase 02 -- confirmed absent

### Assumptions
- The `change_log` script (548 lines) is the complete, final implementation
- The Makefile (`uv run --with behave behave`) requires no changes
- The `features/environment.py` is already correct (references `change_log`, not `ticket`)

## 2. Implementation Phases

### Phase A: Delete Dead Files

**Goal:** Remove all files and directories that belong to the old ticketing system.

**Delete these files (all confirmed to exist on disk):**

| Path | What it is |
|------|-----------|
| `ticket` | Old 50KB ticketing script (1592 lines) |
| `.tickets/` | Old ticket storage directory (contains `test-ticket-1.md`) |
| `plugins/` | Plugin directory (contains only `README.md`) |
| `pkg/` | Packaging configs (AUR PKGBUILDs, `extras.txt`) |
| `scripts/` | CI publishing scripts (`publish-aur.sh`, `publish-homebrew.sh`) |
| `.github/` | GitHub workflows (`release.yml`, `test.yml`) |
| `test.sh` | Old 9-line test wrapper (superseded by `Makefile`) |
| `ask.dnc.md` | Stale AI interaction file (34KB) |
| `formatted_request.dnc.md` | Stale AI interaction file (34KB) |

**Commands:**
```bash
git rm -r ticket .tickets/ plugins/ pkg/ scripts/ .github/ test.sh ask.dnc.md formatted_request.dnc.md
```

**Verification:**
- None of the above paths exist
- `make test` still passes (tests do not depend on any of these files)

### Phase B: Rewrite README.md

**Goal:** Replace the old ticket-system README with documentation for the `change_log` CLI.

**Structure and content specification:**

```markdown
# change_log

<introductory paragraph -- see below>

## Install

<from-source instructions only -- see below>

## Requirements

<requirements paragraph -- see below>

## Agent Setup

<agent setup block -- see below>

## Usage

<help output verbatim from change_log help -- see below>

## Testing

<testing section -- see below>

## License

MIT
```

**Section-by-section content:**

#### Title and Introduction

```
# change_log

A git-backed changelog for AI agents. Entries are markdown files with YAML
frontmatter in `./change_log/`. Filenames are ISO8601 timestamps
(`2026-02-11_16-32-16Z.md`). A random 25-character ID in the YAML frontmatter
serves as the stable identifier for lookups.
```

Rationale: Mirrors the style of the old README intro but describes the new system accurately. Mentions the three key architectural facts: storage format, filename convention, ID scheme.

#### Install

Only the "from source" method remains. Remove Homebrew and AUR sections (no packaging infrastructure exists anymore).

```
## Install

**From source:**
```bash
git clone <REPO_URL>
cd <REPO_NAME> && ln -s "$PWD/change_log" ~/.local/bin/change_log
```

**Or** just copy `change_log` to somewhere in your PATH.
```

Note: The implementor should use the actual GitHub repo URL from the git remote (`git remote get-url origin`). If no public remote is configured, use a placeholder like `https://github.com/OWNER/REPO.git`.

#### Requirements

```
## Requirements

`change_log` is a portable bash script requiring only coreutils, so it works
out of the box on any POSIX system with bash installed. The `query` command
requires `jq` for filtering. Uses `rg` (ripgrep) if available, falls back to
`grep`.
```

#### Agent Setup

```
## Agent Setup

Add this line to your `CLAUDE.md` or `AGENTS.md`:

```
This project uses a changelog system for tracking changes. Run `change_log help` when you need to use it.
```
```

#### Usage

Paste the **exact output** of `change_log help` (lines 501-525 of the script) inside a fenced code block. Do NOT paraphrase or reformat -- copy verbatim:

```
## Usage

```bash
change_log - git-backed changelog for AI agents

Usage: change_log <command> [args]

Commands:
  create [title] [options]  Create changelog entry (prints JSON)
    --impact N              Impact level 1-5 (required)
    -t, --type TYPE         Type (feature|bug_fix|refactor|chore|breaking_change|docs|default) [default: default]
    --desc TEXT             Description text
    -a, --author NAME       Author [default: git user.name]
    --tags TAG,TAG,...      Comma-separated tags
    --dirs DIR,DIR,...      Comma-separated affected directories
    --ap KEY=VALUE          Anchor point (repeatable)
    --note-id KEY=VALUE     Note ID reference (repeatable)
  ls|list [--limit=N]       List entries (most recent first)
  show <id>                 Display entry (supports partial ID)
  edit <id>                 Open entry in $EDITOR
  add-note <id> [text]      Append timestamped note (text or stdin)
  query [jq-filter]         Output entries as JSONL (requires jq for filter)
  help                      Show this help

Entries stored as markdown in ./change_log/ (auto-created at git repo root)
Override directory with CHANGE_LOG_DIR env var
IDs stored in frontmatter; supports partial ID matching
```
```

#### Testing

```
## Testing

The tests are written in [Behave](https://behave.readthedocs.io/) (BDD) and require Python.

With [uv](https://docs.astral.sh/uv/getting-started/installation/) installed:

```sh
make test
```
```

#### License

```
## License

MIT
```

**Sections explicitly REMOVED from old README (do NOT carry forward):**
- Plugins section (entire thing)
- Homebrew/AUR install methods
- Plugin environment variables
- Plugin calling conventions

### Phase C: Rewrite CLAUDE.md

**Goal:** Replace the old ticket-system CLAUDE.md with guidance for working with the `change_log` codebase.

**Structure and content specification:**

```markdown
# CLAUDE.md

<preamble -- see below>

## Architecture

<architecture section -- see below>

## Testing

<testing section -- see below>

## Changelog

<changelog conventions -- see below>
```

**Section-by-section content:**

#### Preamble

```
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See @README.md for usage documentation. Run `change_log help` for command reference. Always update the README.md usage content when adding/changing commands and flags.
```

#### Architecture

```
## Architecture

**Core script:** Single-file bash implementation (`change_log`, ~550 lines). Uses awk for performant bulk operations.

Key functions:
- `find_change_log_dir()` - Directory discovery: walks parents for `change_log/`, auto-creates at git root
- `generate_id()` - Creates 25-char random `[a-z0-9]` IDs (decoupled from filename)
- `timestamp_filename()` - Generates ISO8601 UTC filename stem (`YYYY-MM-DD_HH-MM-SSZ`)
- `entry_path()` - Resolves partial IDs by searching frontmatter `id:` fields (single awk pass)
- `id_from_file()` - Extracts `id:` from a file's YAML frontmatter
- `_file_to_jsonl()` - Shared awk-based JSONL generator (used by create and query)
- `yaml_field()` - YAML frontmatter field extraction via sed
- `_sorted_entries()` - Lists entry files most-recent-first (reverse filename sort)
- `cmd_*()` - Command handlers (create, show, edit, add_note, ls, query, help)

Data model: Filenames are ISO8601 timestamps (e.g., `2026-02-11_16-32-16Z.md`). The `id` field in frontmatter is the stable identifier. `title` is stored in frontmatter (double-quoted). Frontmatter fields: `id`, `title`, `desc`, `created_iso`, `type`, `impact`, `author`, `tags`, `dirs`, `ap`, `note_id`.

Dependencies: bash, sed, awk, find. Optional: ripgrep (faster grep), jq (for query filtering).
```

#### Testing

```
## Testing

BDD tests using [Behave](https://behave.readthedocs.io/). Run with `make test` (requires `uv`).

- Feature files: `features/*.feature` - Gherkin scenarios covering all commands
- Step definitions: `features/steps/changelog_steps.py`

When adding new commands or flags, add corresponding scenarios to the appropriate feature file.
```

Note: Remove the CI reference ("CI runs tests on push to master and all PRs") since `.github/` is being deleted.

#### Changelog

```
## Changelog

Update CHANGELOG.md when committing notable changes:

- New commands, flags, bug fixes, behavior changes
- Add under appropriate heading (Added, Fixed, Changed, Removed)

### What Doesn't Need Logging
- Documentation-only changes
- Test-only changes (unless they reveal a bug fix)
```

**Sections explicitly REMOVED from old CLAUDE.md (do NOT carry forward):**
- Plugins section (entire thing: directory structure, conventions, extracting, creating)
- Plugin Changes subsection in Changelog
- Releases & Packaging section (entire thing: package structure, release flow, CI publishing, package managers)

### Phase D: Update CHANGELOG.md

**Goal:** Add an entry documenting the complete transformation from ticketing system to changelog system.

**What to add:** Replace the current `## [Unreleased]` section with a new one that documents the transformation. The old `[Unreleased]` content (plugin system additions, filename changes, etc.) is superseded by the transformation -- those intermediate changes never shipped as a release, so they fold into this entry.

**New `[Unreleased]` section:**

```markdown
## [Unreleased]

### Changed
- **BREAKING**: Complete transformation from ticket system (`tk`) to changelog system (`change_log`)
- Storage directory changed from `.tickets/` to `./change_log/`
- Environment variable changed from `TICKETS_DIR` to `CHANGE_LOG_DIR`
- Pager variable changed from `TICKET_PAGER` to `CHANGE_LOG_PAGER`
- Filenames changed from title-based slugs to ISO8601 timestamps (`YYYY-MM-DD_HH-MM-SSZ.md`)
- `create` command now requires `--impact` (1-5) instead of `--priority` (0-4)
- Entry types changed to: feature, bug_fix, refactor, chore, breaking_change, docs, default
- `create` outputs JSON (single line) instead of JSONL
- `ls` output format changed to show impact and type: `ID [I3][feature] Title`

### Added
- `--impact` flag (required, 1-5) for classifying change significance
- `--desc` flag for entry description (included in query JSONL output)
- `--dirs` flag for affected directories
- `--ap` flag for anchor point references (repeatable, key=value)
- `--note-id` flag for note ID references (repeatable, key=value)
- `created_iso` frontmatter field (explicit ISO8601 format)

### Removed
- All ticket commands: `start`, `close`, `reopen`, `status`, `dep`, `undep`, `link`, `unlink`, `ready`, `blocked`, `closed`
- Plugin system (`tk-*`/`ticket-*` external command dispatch, `super` command)
- Dependency tracking, status workflows, linking between entries
- `--priority`, `--design`, `--acceptance`, `--external-ref`, `--parent` create flags
- `--assignee` filter flag (replaced by `--author` on create only)
- `-T`/`--tag` filter flag on listing commands
- `--status` filter flag on `ls`
- Homebrew and AUR packaging (scripts, PKGBUILDs, CI workflows)
- GitHub Actions workflows
```

**Keep all existing released version entries** (`[0.3.2]` through `[0.1.0]`) unchanged below the new `[Unreleased]` section.

### Phase E: Verification

**Goal:** Confirm the cleanup is complete and nothing is broken.

**Steps (in order):**

1. **Run `make test`** -- all 76 scenarios, 394 steps must pass
2. **Verify deleted paths do not exist:**
   ```bash
   for path in ticket .tickets plugins pkg scripts .github test.sh ask.dnc.md formatted_request.dnc.md; do
     [ -e "$path" ] && echo "FAIL: $path still exists" && exit 1
   done
   echo "All dead files removed"
   ```
3. **Grep for stale "ticket" references in documentation:**
   ```bash
   grep -ri "ticket" README.md CLAUDE.md 2>/dev/null && echo "FAIL: stale ticket references" && exit 1
   echo "No stale references"
   ```
   Note: CHANGELOG.md is expected to contain "ticket" references in the historical entries and in the transformation description (describing what was removed). That is correct and intentional.
4. **Verify key files exist and are non-empty:**
   ```bash
   for f in change_log README.md CLAUDE.md CHANGELOG.md Makefile LICENSE; do
     [ -s "$f" ] || { echo "FAIL: $f missing or empty"; exit 1; }
   done
   ```
5. **Verify `change_log help` runs successfully:**
   ```bash
   ./change_log help > /dev/null
   ```

## 3. Acceptance Criteria (Automated)

These are machine-verifiable checks the implementor must run after completion:

| # | Check | Command | Expected |
|---|-------|---------|----------|
| AC1 | Tests pass | `make test` | Exit 0, 76 scenarios passed |
| AC2 | Dead files gone | `! test -e ticket && ! test -d .tickets && ! test -d plugins && ! test -d pkg && ! test -d scripts && ! test -d .github && ! test -e test.sh && ! test -e ask.dnc.md && ! test -e formatted_request.dnc.md` | Exit 0 |
| AC3 | No "ticket" in README | `! grep -qi ticket README.md` | Exit 0 |
| AC4 | No "ticket" in CLAUDE.md | `! grep -qi ticket CLAUDE.md` | Exit 0 |
| AC5 | README mentions change_log | `grep -q "change_log" README.md` | Exit 0 |
| AC6 | CLAUDE.md mentions change_log | `grep -q "change_log" CLAUDE.md` | Exit 0 |
| AC7 | CHANGELOG.md has transformation entry | `grep -q "BREAKING.*transformation\|transformation.*changelog" CHANGELOG.md` | Exit 0 |
| AC8 | change_log help works | `./change_log help > /dev/null` | Exit 0 |
| AC9 | No ticket_steps.py | `! test -e features/steps/ticket_steps.py` | Exit 0 |
| AC10 | Essential files exist | `test -s change_log && test -s README.md && test -s CLAUDE.md && test -s CHANGELOG.md && test -s Makefile && test -s LICENSE` | Exit 0 |

## 4. Commit Strategy

This phase is straightforward enough for a single commit:

```
Phase 03: remove dead files, rewrite docs for change_log

Delete old ticket script, plugin/packaging/CI infrastructure, and
stale AI files. Rewrite README.md and CLAUDE.md for the change_log
system. Update CHANGELOG.md with transformation entry.
```

Alternatively, two commits if the implementor prefers separation of concerns:
1. `Delete dead files from ticket system` (file deletions only)
2. `Rewrite docs for change_log system` (README.md, CLAUDE.md, CHANGELOG.md)

## 5. Task Completion

After all acceptance criteria pass, move the task file:
```bash
mv doc/ralph/changelog_transformation/tasks/todo/03_repo_cleanup_and_docs.md \
   doc/ralph/changelog_transformation/tasks/done/03_repo_cleanup_and_docs.md
```

Add a callout to the high-level plan if anything noteworthy was discovered during implementation.
