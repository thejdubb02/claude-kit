# claude-kit

Personal Claude Code kit: portable skills, custom commands, hooks, and reusable snippets, kept in one repo and symlinked into `~/.claude/` so the same setup follows me to any project or machine.

## Layout

```
claude-kit/
├── claude-config/       # The pieces that get symlinked into ~/.claude/
│   ├── skills/          #   Custom-built skills
│   ├── commands/        #   Custom /slash commands
│   ├── hooks/           #   Shared hooks
│   ├── scripts/         #   Setup helper scripts (bw unlock, workspace gen)
│   ├── settings.json    #   Reference Claude Code settings
│   └── statusline.sh    #   Status line script
├── vendor/              # Third-party skills (git submodules)
├── snippets/            # Reusable CSS / prompt snippets (WSG theme tokens, etc.)
├── workspaces/          # VS Code .code-workspace files
└── install.sh           # Idempotent installer: symlinks everything into ~/.claude/
```

## Install on a new machine

```bash
git clone --recurse-submodules git@github.com:thejdubb02/claude-kit.git ~/claude-kit
cd ~/claude-kit && ./install.sh
```

`install.sh` symlinks the skills, commands, and hooks under `claude-config/`, plus the vendored skills under `vendor/`, into the matching directories in `~/.claude/`. It is idempotent, so re-run it any time you pull updates or add new items. It never overwrites a file that is not already a symlink.

`SETUP-NEW-MACHINE.md` covers the wider machine setup around the kit.

## Add a third-party skill

```bash
git submodule add https://github.com/<owner>/<skill>.git vendor/<skill>
./install.sh              # wires it into ~/.claude/skills/
git commit -am "Add <skill>"
```

Pull upstream updates with `git submodule update --remote vendor/<skill>`, then commit the new pointer.

## Add a custom skill / command / hook

Create it under `claude-config/skills/`, `claude-config/commands/`, or `claude-config/hooks/`, then run `./install.sh` and commit.

## What belongs here vs. in a project repo

**Here**: anything reusable across projects, such as skills, slash commands, hooks, and shared snippets like the WSG theme tokens.

**In a project repo**: project-specific config, business logic, secrets, and client deliverables.
