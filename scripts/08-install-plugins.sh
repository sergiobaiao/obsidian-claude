#!/usr/bin/env bash
# 08-install-plugins.sh
# Installs missing Obsidian community plugins into the vault.
# Currently installs: obsidian-auto-note-mover
# Smart Connections is skipped if already present.

set -euo pipefail
source "$(dirname "$0")/../config/settings.sh" 2>/dev/null || true

: "${VAULT_PATH:?Set VAULT_PATH in config/settings.sh}"

PLUGINS_DIR="$VAULT_PATH/.obsidian/plugins"
mkdir -p "$PLUGINS_DIR"

install_plugin() {
  local name="$1" repo="$2"
  if [ -d "$PLUGINS_DIR/$name" ]; then
    echo "  Already installed: $name"
  else
    echo "  Installing: $name"
    git clone "https://github.com/$repo.git" "$PLUGINS_DIR/$name" --quiet
    echo "  Done: $name"
  fi
}

echo "Checking Obsidian plugins..."
install_plugin "auto-note-mover" "farux/obsidian-auto-note-mover"

# Smart Connections — uncomment if not already installed
# install_plugin "smart-connections" "brainlid/obsidian-smart-connections"

echo "PLUGINS_DONE=1"
echo ""
echo "NOTE: Reload Obsidian and enable new plugins under Settings > Community Plugins."
