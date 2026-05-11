#!/usr/bin/env bash
# 06-topic-linker.sh
# Copies topic-linker.py to ~/claude-vault/ and writes the config file.

set -euo pipefail
source "$(dirname "$0")/../config/settings.sh" 2>/dev/null || true

: "${VAULT_PATH:?Set VAULT_PATH in config/settings.sh}"
: "${TOPICS_FOLDER:=Topics}"
: "${CLAUDE_VAULT_HOME:=$HOME/claude-vault}"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Installing topic-linker..."

# Copy script
cp "$REPO_DIR/python/topic-linker.py" "$CLAUDE_VAULT_HOME/topic-linker.py"
chmod +x "$CLAUDE_VAULT_HOME/topic-linker.py" 2>/dev/null || true

# Write config
mkdir -p "$HOME/.config/topic-linker"
sed "s|VAULT_PATH_PLACEHOLDER|$VAULT_PATH|g; s|\"Topics\"|\"$TOPICS_FOLDER\"|g" \
  "$REPO_DIR/config/topic-linker.json" \
  > "$HOME/.config/topic-linker/config.json"

# Seed starter topic notes
TOPICS_DIR="$VAULT_PATH/$TOPICS_FOLDER"
mkdir -p "$TOPICS_DIR"

seed_note() {
  local name="$1" type="$2" blurb="$3"
  local target="$TOPICS_DIR/$name.md"
  if [ -f "$target" ]; then
    echo "  Skipped (exists): $name"
    return
  fi
  cat > "$target" << MD
---
type: $type
created: $(date -u +%Y-%m-%d)
tags: [topic-note, starter]
---

# $name

$blurb

## Related Sessions

<!-- Session logs that reference $name will be linked here by the topic-linker. -->
MD
  echo "  Created: $name"
}

echo "Seeding starter topic notes..."
seed_note "Claude Code" "tool"    "Claude Code — the CLI/terminal interface for Claude."
seed_note "Obsidian"   "tool"    "Obsidian — the local markdown knowledge base this vault lives in."
seed_note "Second Brain" "concept" "Second Brain — the broader idea this vault is built around."

echo "TOPIC_LINKER_DONE=1"
