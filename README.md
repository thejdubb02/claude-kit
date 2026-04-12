# claude-kit

Personal Claude Code kit — portable skills, agents, custom commands, hooks, and reusable snippets. Works across any project, any machine.

## Layout

```
claude-kit/
├── skills/       # Custom-built skills (live here, symlinked into ~/.claude/skills/)
├── vendor/       # Third-party skills (git submodules)
├── commands/     # Custom /slash commands
├── agents/       # Custom subagent configs
├── hooks/        # Shared hooks
├── snippets/     # Reusable code/CSS/prompts (WSG theme tokens, etc)
└── install.sh    # Idempotent installer — symlinks everything into ~/.claude/
```

## Install on a new machine

```bash
git clone --recurse-submodules git@github.com:thejdubb02/claude-kit.git ~/claude-kit
cd ~/claude-kit && ./install.sh
```

`install.sh` creates symlinks from `~/.claude/skills/*`, `~/.claude/commands/*`, etc. into the corresponding kit directories. Re-run anytime you pull updates or add new items.

## Add a third-party skill

```bash
git submodule add https://github.com/<owner>/<skill>.git vendor/<skill>
./install.sh              # wires it into ~/.claude/skills/
git commit -am "Add <skill>"
```

Upstream updates: `git submodule update --remote vendor/<skill>` then commit the new pointer.

## Add a custom skill / command / agent

Create it under `skills/`, `commands/`, or `agents/` directly. Run `./install.sh`. Commit.

## What belongs here vs. in a project repo

**Here**: anything reusable across projects — favicon generators, diagram renderers, plan review agents, personal WSG theme tokens, etc.

**In project repo**: project-specific configs, business logic, secrets, client deliverables.
