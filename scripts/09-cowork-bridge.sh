#!/usr/bin/env bash
# 09-cowork-bridge.sh
# Patches claude-vault's cli.py and sync.py with the Cowork Bridge sentinel blocks,
# registers the Cowork sessions path with the watcher, and writes the vault CLAUDE.md
# managed block.
#
# IMPORTANT: Run AFTER 03-install-claude-vault.sh so the venv and source files exist.

set -euo pipefail
source "$(dirname "$0")/../config/settings.sh" 2>/dev/null || true
source "$(dirname "$0")/01-detect-os.sh"

: "${VAULT_PATH:?Set VAULT_PATH in config/settings.sh}"
: "${TOPICS_FOLDER:=Topics}"
: "${CLAUDE_VAULT_HOME:=$HOME/claude-vault}"

export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

if [ "$OS_DETECTED" = "windows" ]; then
  CV_BIN="$CLAUDE_VAULT_HOME/venv/Scripts/claude-vault.exe"
  COWORK_ROOT="$APPDATA/Claude/local-agent-mode-sessions"
else
  CV_BIN="$CLAUDE_VAULT_HOME/venv/bin/claude-vault"
  COWORK_ROOT="$HOME/Library/Application Support/Claude/local-agent-mode-sessions"
fi

mkdir -p "$COWORK_ROOT"

# -----------------------------------------------------------------------
# 1. Patch cli.py — adds --version surface
# -----------------------------------------------------------------------
CLI_PY="$CLAUDE_VAULT_HOME/claude_vault/cli.py"
echo "Patching cli.py..."

python3 - "$CLI_PY" << 'PYEOF'
import re, sys
p = sys.argv[1]
with open(p, encoding='utf-8') as f:
    content = f.read()
# Strip existing block if present
pattern = re.compile(r'\n*# OCDVB-MANAGED:START v1\.0.*?# OCDVB-MANAGED:END\n*', re.DOTALL)
content, _ = pattern.subn('\n', content)
content = content.rstrip() + '\n'

block = """
# OCDVB-MANAGED:START v1.0 --- Cowork Bridge: --version wire-up. Do not edit manually.
import typer as _ocdvb_typer
from claude_vault import __version__ as _ocdvb_version

def _ocdvb_version_callback(value: bool):
    if value:
        print(_ocdvb_version)
        raise _ocdvb_typer.Exit(0)

@app.callback()
def _ocdvb_root(
    version: bool = _ocdvb_typer.Option(
        False, "--version",
        callback=_ocdvb_version_callback,
        is_eager=True,
        help="Show the claude-vault version and exit.",
    ),
):
    \"\"\"Claude Vault - Sync Claude conversations to Obsidian\"\"\"
    pass
# OCDVB-MANAGED:END
"""
with open(p, 'a', encoding='utf-8') as f:
    f.write(block)
print("cli.py patched")
PYEOF

# -----------------------------------------------------------------------
# 2. Patch sync.py — adds cowork-* filename prefix
# -----------------------------------------------------------------------
SYNC_PY="$CLAUDE_VAULT_HOME/claude_vault/sync.py"
echo "Patching sync.py..."

python3 - "$SYNC_PY" << 'PYEOF'
import re, sys
p = sys.argv[1]
with open(p, encoding='utf-8') as f:
    content = f.read()
pattern = re.compile(r'\n*# OCDVB-MANAGED:START v1\.0.*?# OCDVB-MANAGED:END\n*', re.DOTALL)
content, _ = pattern.subn('\n', content)
content = content.rstrip() + '\n'

block = """
# OCDVB-MANAGED:START v1.0 --- Cowork Bridge: cowork-* filename prefix. Do not edit manually.
def _ocdvb_cowork_prefix(path, source):
    s = str(source or "")
    if "local-agent-mode-sessions" not in s:
        return path
    prefix = "cowork-subagent-" if "/subagents/" in s else "cowork-"
    if path.name.startswith(prefix):
        return path
    return path.with_name(prefix + path.name)

_ocdvb_original_sync = SyncEngine.sync
_ocdvb_original_generate_path = SyncEngine._generate_path

def _ocdvb_sync(self, export_path, *args, **kwargs):
    self._ocdvb_source = str(export_path)
    try:
        return _ocdvb_original_sync(self, export_path, *args, **kwargs)
    finally:
        self._ocdvb_source = None

def _ocdvb_generate_path(self, conversation):
    base = _ocdvb_original_generate_path(self, conversation)
    return _ocdvb_cowork_prefix(base, getattr(self, "_ocdvb_source", None))

SyncEngine.sync = _ocdvb_sync
SyncEngine._generate_path = _ocdvb_generate_path
# OCDVB-MANAGED:END
"""
with open(p, 'a', encoding='utf-8') as f:
    f.write(block)
print("sync.py patched")
PYEOF

# -----------------------------------------------------------------------
# 3. Register Cowork sessions path with claude-vault watcher
# -----------------------------------------------------------------------
echo "Registering Cowork sessions path..."
"$CV_BIN" watch-add "$COWORK_ROOT" --source code --vault-path "$VAULT_PATH" \
  || echo "  (may already be registered — continuing)"

# -----------------------------------------------------------------------
# 4. Write vault-root CLAUDE.md managed block
# -----------------------------------------------------------------------
VAULT_CMD="$VAULT_PATH/CLAUDE.md"
if grep -q "OCDVB-MANAGED:START" "$VAULT_CMD" 2>/dev/null; then
  echo "Vault CLAUDE.md already has bridge block — skipping."
else
  echo "Writing vault-root CLAUDE.md bridge block..."
  python3 - "$VAULT_CMD" "$VAULT_PATH" "$TOPICS_FOLDER" << 'PYEOF'
import sys, os, re

src, vault, topics = sys.argv[1], sys.argv[2], sys.argv[3]

block = f"""<!-- OCDVB-MANAGED:START v1.0 -->
# Vault-Root CLAUDE.md — Claude Desktop + Cowork Bridge

## Vault-First Search Protocol

**Search this vault BEFORE going external.**

1. {topics}/ — topic notes
2. Sessions/ — session logs
3. conversations/ — raw exports (cowork-*.md files)

## What the Bridge Auto-Handles
- Cowork conversations → conversations/cowork-*.md
- Sub-agent conversations → conversations/cowork-subagent-*.md
- Topic linker adds See Also footers every 10 minutes

## Session logs
Path: Sessions/YYYY-MM-DD-cowork-{{topic}}.md

## Do Not
- Delete files recursively
- Modify other bots' files (e.g. OpenClaw/Memory/)
<!-- OCDVB-MANAGED:END -->"""

existing = ""
if os.path.exists(src):
    with open(src, encoding='utf-8') as f:
        existing = f.read()

new_content = existing.rstrip('\n') + '\n\n' + block + '\n'
tmp = src + '.tmp'
with open(tmp, 'w', encoding='utf-8') as f:
    f.write(new_content)
os.replace(tmp, src)
print("Vault CLAUDE.md written")
PYEOF
fi

echo "COWORK_BRIDGE_DONE=1"
