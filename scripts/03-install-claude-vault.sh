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

# --- Windows: patch watcher.py os.kill(pid,0) bug ---
# os.kill(pid, 0) raises OSError on Windows instead of ProcessLookupError.
# Patch _is_running() to use ctypes.windll on Windows.
if [ "$OS_DETECTED" = "windows" ]; then
  WATCHER_PY="$CLAUDE_VAULT_HOME/claude_vault/watcher.py"
  if ! grep -q "WATCHER-WIN-PATCH" "$WATCHER_PY" 2>/dev/null; then
    echo "Patching watcher.py for Windows process check..."
    python3 - "$WATCHER_PY" << 'PYEOF'
import re, sys
p = sys.argv[1]
with open(p, encoding='utf-8') as f:
    content = f.read()

old = '''    def _is_running(self) -> bool:
        """Check if watch is already running"""
        if not self.pid_file.exists():
            return False

        try:
            pid = int(self.pid_file.read_text().strip())
            # Check if process exists
            os.kill(pid, 0)
            return True
        except (ProcessLookupError, ValueError):
            # Stale PID file
            self.pid_file.unlink()
            return False
        except PermissionError:
            # Process exists but we can't access it
            return True'''

new = '''    def _is_running(self) -> bool:
        """Check if watch is already running (cross-platform). WATCHER-WIN-PATCH v1"""
        if not self.pid_file.exists():
            return False

        try:
            pid = int(self.pid_file.read_text().strip())
        except ValueError:
            self.pid_file.unlink(missing_ok=True)
            return False

        if os.name == "nt":
            import ctypes
            PROCESS_QUERY_INFORMATION = 0x0400
            STILL_ACTIVE = 259
            handle = ctypes.windll.kernel32.OpenProcess(PROCESS_QUERY_INFORMATION, False, pid)
            if not handle:
                self.pid_file.unlink(missing_ok=True)
                return False
            exit_code = ctypes.c_ulong()
            ctypes.windll.kernel32.GetExitCodeProcess(handle, ctypes.byref(exit_code))
            ctypes.windll.kernel32.CloseHandle(handle)
            alive = exit_code.value == STILL_ACTIVE
            if not alive:
                self.pid_file.unlink(missing_ok=True)
            return alive

        try:
            os.kill(pid, 0)
            return True
        except ProcessLookupError:
            self.pid_file.unlink(missing_ok=True)
            return False
        except PermissionError:
            return True'''

if old in content:
    content = content.replace(old, new)
    import os, tempfile
    tmp = p + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        f.write(content)
    os.replace(tmp, p)
    print("watcher.py patched")
else:
    print("watcher.py: pattern not found — may already be patched or upstream changed")
PYEOF
  else
    echo "watcher.py already patched — skipping."
  fi
fi
