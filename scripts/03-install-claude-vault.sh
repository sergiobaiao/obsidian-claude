#!/usr/bin/env bash
# 03-install-claude-vault.sh
# Clones the claude-vault repo, creates a Python venv, and installs the package.
# Cross-platform: works on both Windows (Git Bash) and macOS.

set -euo pipefail
source "$(dirname "$0")/../config/settings.sh" 2>/dev/null || true
source "$(dirname "$0")/01-detect-os.sh"

: "${CLAUDE_VAULT_HOME:=$HOME/claude-vault}"

# --- Clone ---
if [ ! -d "$CLAUDE_VAULT_HOME" ]; then
  echo "Cloning claude-vault..."
  git clone https://github.com/MarioPadilla/claude-vault.git "$CLAUDE_VAULT_HOME"
  echo "CV_CLONED=true"
else
  echo "CV_CLONED=already-present (pulling latest)"
  git -C "$CLAUDE_VAULT_HOME" pull --ff-only || true
fi

# --- Create venv ---
cd "$CLAUDE_VAULT_HOME"
if [ ! -d venv ]; then
  echo "Creating Python venv..."
  if command -v python3 >/dev/null 2>&1; then
    python3 -m venv venv
  else
    python -m venv venv
  fi
  echo "VENV_CREATED=true"
else
  echo "VENV_CREATED=already-present"
fi

# --- Activate & install ---
if [ "$OS_DETECTED" = "windows" ]; then
  ACTIVATE="venv/Scripts/activate"
else
  ACTIVATE="venv/bin/activate"
fi

# shellcheck disable=SC1090
source "$ACTIVATE"
pip install --upgrade pip --quiet
pip install -e . --quiet
echo "CV_INSTALLED=true"

# --- State dir ---
mkdir -p "$CLAUDE_VAULT_HOME/vault-state"
echo "STATE_DIR=$CLAUDE_VAULT_HOME/vault-state"
