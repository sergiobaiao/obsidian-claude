#!/usr/bin/env bash
# 05-install-shims-and-tasks.sh
# Windows: copies .cmd shims to ~/claude-vault/ and registers scheduled tasks.
# macOS:   installs LaunchAgents instead.

set -euo pipefail
source "$(dirname "$0")/../config/settings.sh" 2>/dev/null || true
source "$(dirname "$0")/01-detect-os.sh"

: "${VAULT_PATH:?Set VAULT_PATH in config/settings.sh}"
: "${CLAUDE_VAULT_HOME:=$HOME/claude-vault}"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ============================================================
# WINDOWS
# ============================================================
if [ "$OS_DETECTED" = "windows" ]; then

  VAULT_WIN="$(cygpath -w "$VAULT_PATH")"
  APPDATA_WIN="$APPDATA"

  echo "Installing Windows .cmd shims..."

  # --- Vault watcher shim ---
  # Note: uses --vault-path (vault root, not Conversations subfolder)
  #       and calls the .exe directly to avoid activate.bat quoting issues.
  cat > "$CLAUDE_VAULT_HOME/run-claudevault-watch.cmd" << EOF
@echo off
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
"%USERPROFILE%\\claude-vault\\venv\\Scripts\\claude-vault.exe" watch --vault-path "$VAULT_WIN"
EOF

  # --- Topic linker shim ---
  cat > "$CLAUDE_VAULT_HOME/run-topic-linker.cmd" << 'EOF'
@echo off
cd /d "%USERPROFILE%\claude-vault"
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
call "%USERPROFILE%\claude-vault\venv\Scripts\activate.bat"
python "%USERPROFILE%\claude-vault\topic-linker.py"
EOF

  # --- Cowork periodic sync shim ---
  cat > "$CLAUDE_VAULT_HOME/run-cowork-periodic-sync.cmd" << EOF
@echo off
cd /d "%USERPROFILE%\\claude-vault"
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
call "%USERPROFILE%\\claude-vault\\venv\\Scripts\\activate.bat"
claude-vault sync "%APPDATA%\\Claude\\local-agent-mode-sessions" --vault-path "$VAULT_WIN" --source code >> "%USERPROFILE%\\claude-vault\\cowork-periodic.log" 2>&1
EOF

  echo "Shims written. Registering scheduled tasks..."

  PS_SCRIPT="$(cygpath -w "$REPO_DIR/powershell/register-tasks.ps1")"
  VAULT_WIN_ARG="$(cygpath -w "$VAULT_PATH")"
  CV_WIN="$(cygpath -w "$CLAUDE_VAULT_HOME")"

  powershell -ExecutionPolicy Bypass \
    -File "$PS_SCRIPT" \
    -VaultPath "$VAULT_WIN_ARG" \
    -ClaudeVaultHome "$CV_WIN"

# ============================================================
# macOS
# ============================================================
elif [ "$OS_DETECTED" = "mac" ]; then

  PLIST_DIR="$HOME/Library/LaunchAgents"
  mkdir -p "$PLIST_DIR"

  CV_BIN="$CLAUDE_VAULT_HOME/venv/bin/claude-vault"

  # --- Vault watcher plist ---
  cat > "$PLIST_DIR/com.claudevault.watch.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.claudevault.watch</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string><string>-lc</string>
        <string>source $CLAUDE_VAULT_HOME/venv/bin/activate &amp;&amp; claude-vault watch --vault-path "$VAULT_PATH"</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>/tmp/claudevault.watch.log</string>
    <key>StandardErrorPath</key><string>/tmp/claudevault.watch.err.log</string>
</dict>
</plist>
EOF

  # --- Topic linker plist ---
  cat > "$PLIST_DIR/com.obsidian.topic-linker.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.obsidian.topic-linker</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string><string>-lc</string>
        <string>python3 $CLAUDE_VAULT_HOME/topic-linker.py</string>
    </array>
    <key>StartInterval</key><integer>600</integer>
    <key>RunAtLoad</key><true/>
    <key>StandardOutPath</key><string>/tmp/topic-linker.log</string>
    <key>StandardErrorPath</key><string>/tmp/topic-linker.err.log</string>
</dict>
</plist>
EOF

  # --- Cowork periodic plist ---
  cat > "$PLIST_DIR/com.claudevault.cowork-periodic.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.claudevault.cowork-periodic</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string><string>-lc</string>
        <string>source $CLAUDE_VAULT_HOME/venv/bin/activate &amp;&amp; claude-vault sync "$HOME/Library/Application Support/Claude/local-agent-mode-sessions" --vault-path "$VAULT_PATH" --source code</string>
    </array>
    <key>StartInterval</key><integer>300</integer>
    <key>RunAtLoad</key><true/>
    <key>StandardErrorPath</key><string>/tmp/cowork-periodic.err.log</string>
</dict>
</plist>
EOF

  # Bootstrap all three
  for label in com.claudevault.watch com.obsidian.topic-linker com.claudevault.cowork-periodic; do
    launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST_DIR/$label.plist"
    echo "Loaded: $label"
  done
fi

echo "TASKS_DONE=1"
