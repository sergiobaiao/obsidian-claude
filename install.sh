#!/usr/bin/env bash
# install.sh — Obsidian Second Brain + Cowork Bridge
# Main orchestrator. Runs scripts 01–09 in sequence, then 10 to verify.
#
# Usage:
#   bash install.sh               # full install
#   bash install.sh --verify-only # skip install, just run verification
#   bash install.sh --dry-run     # show steps without executing (NYI)
#
# Prerequisites: Git Bash (Windows) or bash (macOS). See README.md.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

banner() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  printf  "║  %-56s  ║\n" "$1"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
}

step() {
  local num="$1" desc="$2"
  echo "──────────────────────────────────────────────────────────"
  echo "  Step $num: $desc"
  echo "──────────────────────────────────────────────────────────"
}

die() {
  echo ""
  echo "ERROR: $*" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

if [ ! -f "$REPO_DIR/config/settings.sh" ]; then
  die "config/settings.sh not found. Copy config/settings.sh.example and fill in your values."
fi

source "$REPO_DIR/config/settings.sh" 2>/dev/null || true

if [ -z "${VAULT_PATH:-}" ]; then
  die "VAULT_PATH is not set. Edit config/settings.sh first."
fi

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

VERIFY_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --verify-only) VERIFY_ONLY=1 ;;
    --help|-h)
      echo "Usage: bash install.sh [--verify-only]"
      echo ""
      echo "  --verify-only   Skip installation, only run the verification suite (script 10)."
      echo ""
      echo "Edit config/settings.sh before running."
      exit 0
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

banner "Obsidian Second Brain + Cowork Bridge Installer"

echo "  Vault:           $VAULT_PATH"
echo "  Topics folder:   ${TOPICS_FOLDER:-Topics}"
echo "  claude-vault:    ${CLAUDE_VAULT_HOME:-$HOME/claude-vault}"
echo ""

if [ "$VERIFY_ONLY" -eq 1 ]; then
  echo "  Mode: VERIFY ONLY"
  echo ""
  bash "$SCRIPTS_DIR/10-verify.sh"
  exit $?
fi

# Step 1 — Detect OS
step 1 "Detect OS"
source "$SCRIPTS_DIR/01-detect-os.sh"
echo "  Detected: $OS_DETECTED"

# Step 2 — Vault structure
step 2 "Create vault folder structure"
bash "$SCRIPTS_DIR/02-vault-structure.sh"

# Step 3 — Install claude-vault
step 3 "Install claude-vault"
bash "$SCRIPTS_DIR/03-install-claude-vault.sh"

# Step 4 — Initialise and sync
step 4 "Initialise claude-vault and run historical sync"
bash "$SCRIPTS_DIR/04-init-and-sync.sh"

# Step 5 — Background services
step 5 "Install shims and background services"
bash "$SCRIPTS_DIR/05-install-shims-and-tasks.sh"

# Step 6 — Topic linker
step 6 "Install topic linker"
bash "$SCRIPTS_DIR/06-topic-linker.sh"

# Step 7 — Patch ~/.claude/CLAUDE.md
step 7 "Patch ~/.claude/CLAUDE.md"
bash "$SCRIPTS_DIR/07-patch-claude-md.sh"

# Step 8 — Obsidian plugins
step 8 "Install Obsidian plugins"
bash "$SCRIPTS_DIR/08-install-plugins.sh"

# Step 9 — Cowork Bridge
step 9 "Install Cowork Bridge patches"
bash "$SCRIPTS_DIR/09-cowork-bridge.sh"

# Step 10 — Verify
banner "Verification"
bash "$SCRIPTS_DIR/10-verify.sh"
EXIT_CODE=$?

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "✓ Installation complete. All checks passed."
  echo ""
  echo "Next steps:"
  echo "  1. Open Obsidian and enable newly installed community plugins."
  echo "     Settings → Community Plugins → enable Auto Note Mover (and Smart Connections if installed)."
  echo "  2. Restart your session (log off/on on Windows) so the scheduled tasks fire."
  echo "  3. Start Claude Code — it will auto-archive sessions to $VAULT_PATH/Sessions/"
else
  echo "✗ Some checks failed. See output above."
  echo "  Run  bash install.sh --verify-only  after fixing issues to re-check."
fi
echo ""

exit $EXIT_CODE
