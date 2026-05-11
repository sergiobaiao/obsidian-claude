#!/usr/bin/env bash
# 04-init-and-sync.sh
# Initialises claude-vault against the vault, then backfills historical conversations.

set -euo pipefail
source "$(dirname "$0")/../config/settings.sh" 2>/dev/null || true
source "$(dirname "$0")/01-detect-os.sh"

: "${VAULT_PATH:?Set VAULT_PATH in config/settings.sh}"
: "${CLAUDE_VAULT_HOME:=$HOME/claude-vault}"

# Pick the right binary
if [ "$OS_DETECTED" = "windows" ]; then
  CV_BIN="$CLAUDE_VAULT_HOME/venv/Scripts/claude-vault.exe"
else
  CV_BIN="$CLAUDE_VAULT_HOME/venv/bin/claude-vault"
fi

# Always export UTF-8 on Windows to avoid charmap errors
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

# --- Init ---
echo "Initialising claude-vault against vault: $VAULT_PATH"
"$CV_BIN" init --vault-path "$VAULT_PATH" 2>/dev/null \
  || grep -qi "already initialized" <<< "$(cat /tmp/cv-init.log 2>/dev/null)" \
  && echo "CV_INIT=success (or already initialised)"

# --- Historical sync ---
JSONL_COUNT=$(find "$HOME/.claude/projects" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
echo "HISTORICAL_JSONL_COUNT=$JSONL_COUNT"

if [ "$JSONL_COUNT" -gt 0 ]; then
  echo "Syncing $JSONL_COUNT conversation files..."
  "$CV_BIN" sync "$HOME/.claude/projects" \
    --vault-path "$VAULT_PATH" --source code
  echo "HISTORICAL_SYNC_DONE=1"
else
  echo "HISTORICAL_SYNC_SKIPPED=no-history"
fi
