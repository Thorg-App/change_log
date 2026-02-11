# change_log

A git-backed changelog for AI agents. Entries are markdown files with YAML
frontmatter in `./change_log/`. Filenames are ISO8601 timestamps
(`2026-02-11_16-32-16Z.md`). A random 25-character ID in the YAML frontmatter
serves as the stable identifier for lookups.

## Install

**From source:**
```bash
git clone https://github.com/Thorg-App/change_log.git
cd change_log && ln -s "$PWD/change_log" ~/.local/bin/change_log
```

**Or** just copy `change_log` to somewhere in your PATH.

## Requirements

`change_log` is a portable bash script requiring only coreutils, so it works
out of the box on any POSIX system with bash installed. The `query` command
requires `jq` for filtering. Uses `rg` (ripgrep) if available, falls back to
`grep`.

## Agent Setup

Add this line to your `CLAUDE.md` or `AGENTS.md`:

```
This project uses a changelog system for tracking changes. Run `change_log help` when you need to use it.
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

## Testing

The tests are written in [Behave](https://behave.readthedocs.io/) (BDD) and require Python.

With [uv](https://docs.astral.sh/uv/getting-started/installation/) installed:

```sh
make test
```

## License

MIT
