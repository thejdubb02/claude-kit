#!/usr/bin/env bash
# claude-kit installer — symlinks kit items into ~/.claude/
# Idempotent. Safe to re-run.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

link_items() {
    local src_dir="$1"
    local dst_dir="$2"
    [ -d "$src_dir" ] || return 0
    mkdir -p "$dst_dir"
    for item in "$src_dir"/*; do
        [ -e "$item" ] || continue
        local name
        name="$(basename "$item")"
        local target="$dst_dir/$name"
        if [ -L "$target" ]; then
            rm -f "$target"
        elif [ -e "$target" ]; then
            echo "  skip (not a symlink, won't overwrite): $target"
            continue
        fi
        ln -s "$item" "$target"
        echo "  linked: $target -> $item"
    done
}

echo "Installing claude-kit from $KIT_DIR into $CLAUDE_DIR"

# Custom-built skills
link_items "$KIT_DIR/skills" "$CLAUDE_DIR/skills"

# Vendored third-party skills (submodules often nest SKILL.md one level deep — resolve)
if [ -d "$KIT_DIR/vendor" ]; then
    mkdir -p "$CLAUDE_DIR/skills"
    for vendor in "$KIT_DIR/vendor"/*; do
        [ -d "$vendor" ] || continue
        local_name="$(basename "$vendor")"
        # If the submodule root has SKILL.md, link directly
        if [ -f "$vendor/SKILL.md" ]; then
            target="$CLAUDE_DIR/skills/$local_name"
        # Else look for skills/<name>/SKILL.md inside the submodule
        elif [ -f "$vendor/skills/$local_name/SKILL.md" ]; then
            vendor="$vendor/skills/$local_name"
            target="$CLAUDE_DIR/skills/$local_name"
        else
            echo "  skip vendor (no SKILL.md found): $local_name"
            continue
        fi
        [ -L "$target" ] && rm -f "$target"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            echo "  skip (not a symlink): $target"
            continue
        fi
        ln -s "$vendor" "$target"
        echo "  linked: $target -> $vendor"
    done
fi

# Commands, agents, hooks
link_items "$KIT_DIR/commands" "$CLAUDE_DIR/commands"
link_items "$KIT_DIR/agents" "$CLAUDE_DIR/agents"
link_items "$KIT_DIR/hooks" "$CLAUDE_DIR/hooks"

echo "Done."
