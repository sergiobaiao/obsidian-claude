#!/usr/bin/env bash
# 10-verify.sh — Post-install verification. Prints pass/fail for each check.

set +e
source "$(dirname "$0")/../config/settings.sh" 2>/dev/null || true
source "$(dirname "$0")/01-detect-os.sh"

: "${VAULT_PATH:?Set VAULT_PATH in config/settings.sh}"
: "${TOPICS_FOLDER:=Topics}"
: "${CLAUDE_VAULT_HOME:=$HOME/claude-vault}"

PASS=0; FAIL=0

check() {
  local name="$1" result="$2" detail="${3:-}"
  if [ "$result" = "pass" ]; then
    echo "  ✓ $name"
    PASS=$((PASS+1))
  else
    echo "  ✗ $name${detail:+ — $detail}"
    FAIL=$((FAIL+1))
  fi
}

echo ""
echo "=== Verification ==="

# Vault
check "Vault exists"       "$([ -d "$VAULT_PATH/.obsidian" ] && echo pass || echo fail)"
check "Sessions folder"    "$([ -d "$VAULT_PATH/Sessions" ] && echo pass || echo fail)"
check "Topics folder"      "$([ -d "$VAULT_PATH/$TOPICS_FOLDER" ] && echo pass || echo fail)"
check "Conversations folder" "$([ -d "$VAULT_PATH/Conversations" ] && echo pass || echo fail)"

# claude-vault
if [ "$OS_DETECTED" = "windows" ]; then
  CV_BIN="$CLAUDE_VAULT_HOME/venv/Scripts/claude-vault.exe"
  check "claude-vault binary (Windows)" "$([ -f "$CV_BIN" ] && echo pass || echo fail)" "$CV_BIN"
else
  CV_BIN="$CLAUDE_VAULT_HOME/venv/bin/claude-vault"
  check "claude-vault binary (macOS)" "$([ -x "$CV_BIN" ] && echo pass || echo fail)" "$CV_BIN"
fi
check "vault-state dir"    "$([ -d "$CLAUDE_VAULT_HOME/vault-state" ] && echo pass || echo fail)"

# Background services
if [ "$OS_DETECTED" = "windows" ]; then
  check "ClaudeVaultWatch task"       "$(schtasks //Query //TN "ClaudeVaultWatch" >/dev/null 2>&1 && echo pass || echo fail)"
  check "ObsidianTopicLinker task"    "$(schtasks //Query //TN "ObsidianTopicLinker" >/dev/null 2>&1 && echo pass || echo fail)"
  check "ClaudeVaultCoworkPeriodic"   "$(schtasks //Query //TN "ClaudeVaultCoworkPeriodic" >/dev/null 2>&1 && echo pass || echo fail)"
  check "Watcher .cmd shim"           "$([ -f "$CLAUDE_VAULT_HOME/run-claudevault-watch.cmd" ] && echo pass || echo fail)"
else
  check "ClaudeVault LaunchAgent"     "$(launchctl list 2>/dev/null | grep -q "com.claudevault.watch" && echo pass || echo fail)"
  check "TopicLinker LaunchAgent"     "$(launchctl list 2>/dev/null | grep -q "obsidian.topic-linker" && echo pass || echo fail)"
  check "Cowork Periodic LaunchAgent" "$(launchctl list 2>/dev/null | grep -q "cowork-periodic" && echo pass || echo fail)"
fi

# CLAUDE.md
check "Auto-archive protocol in CLAUDE.md" \
  "$(grep -q "OBSIDIAN AUTO-ARCHIVE PROTOCOL" "$HOME/.claude/CLAUDE.md" 2>/dev/null && echo pass || echo fail)"
check "Vault-read protocol in CLAUDE.md" \
  "$(grep -q "Vault Read — SEARCH BEFORE YOU WORK" "$HOME/.claude/CLAUDE.md" 2>/dev/null && echo pass || echo fail)"

# Plugins
check "Smart Connections plugin"   "$([ -d "$VAULT_PATH/.obsidian/plugins/smart-connections" ] && echo pass || echo fail)"
check "Auto Note Mover plugin"     "$([ -d "$VAULT_PATH/.obsidian/plugins/auto-note-mover" ] || \
  [ -d "$VAULT_PATH/.obsidian/plugins/obsidian-auto-note-mover" ] && echo pass || echo fail)"

# Topic linker
check "topic-linker.py installed"  "$([ -f "$CLAUDE_VAULT_HOME/topic-linker.py" ] && echo pass || echo fail)"
check "topic-linker config"        "$([ -f "$HOME/.config/topic-linker/config.json" ] && echo pass || echo fail)"

# Cowork Bridge
check "cli.py patched (sentinel)"  "$(grep -q "OCDVB-MANAGED" "$CLAUDE_VAULT_HOME/claude_vault/cli.py" 2>/dev/null && echo pass || echo fail)"
check "sync.py patched (sentinel)" "$(grep -q "OCDVB-MANAGED" "$CLAUDE_VAULT_HOME/claude_vault/sync.py" 2>/dev/null && echo pass || echo fail)"
check "Vault CLAUDE.md bridge block" "$(grep -q "OCDVB-MANAGED:START" "$VAULT_PATH/CLAUDE.md" 2>/dev/null && echo pass || echo fail)"

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
