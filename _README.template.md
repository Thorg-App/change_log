> GENERATED: This file is generated from `./_README.template.md`. Using README.generate.sh. Do not edit directly. Instead, edit the template and regenerate.

# change_log

A git-backed changelog for AI agents. Entries are markdown files with YAML
frontmatter in `./_change_log/`. Filenames are ISO8601 timestamps
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
{{$(change_log --help)}}
```

## Testing

The tests are written in [Behave](https://behave.readthedocs.io/) (BDD) and require Python.

With [uv](https://docs.astral.sh/uv/getting-started/installation/) installed:

```sh
make test
```

## License

MIT
