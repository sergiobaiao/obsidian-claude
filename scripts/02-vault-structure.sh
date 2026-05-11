#!/usr/bin/env bash
# 02-vault-structure.sh — Create required folders inside the Obsidian vault.
# Usage: VAULT_PATH=/path/to/vault TOPICS_FOLDER=Topics bash 02-vault-structure.sh

set -euo pipefail
source "$(dirname "$0")/../config/settings.sh" 2>/dev/null || true

: "${VAULT_PATH:?Set VAULT_PATH in config/settings.sh}"
: "${TOPICS_FOLDER:=Topics}"

echo "Creating vault structure in: $VAULT_PATH"

mkdir -p "$VAULT_PATH/Sessions"
mkdir -p "$VAULT_PATH/$TOPICS_FOLDER"
mkdir -p "$VAULT_PATH/Conversations"
mkdir -p "$VAULT_PATH/conversations"
mkdir -p "$VAULT_PATH/OpenClaw/Memory"
mkdir -p "$VAULT_PATH/OpenClaw/DailyNotes"
mkdir -p "$VAULT_PATH/OpenClaw/ActiveTasks"
mkdir -p "$VAULT_PATH/Archive/Imports"
mkdir -p "$VAULT_PATH/Resources"
mkdir -p "$VAULT_PATH/Templates"
mkdir -p "$VAULT_PATH/System/backups"

echo "STRUCTURE_DONE=1"
