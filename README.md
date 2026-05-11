# Obsidian Second Brain + Cowork Bridge

A fully automated installer that turns an Obsidian vault into a living second brain synced with Claude Code sessions. Works on **Windows** (Git Bash) and **macOS**.

---

## What It Installs

| Component | What it does |
|---|---|
| **claude-vault** | Watches Claude Code conversation directories and syncs them as Markdown files into your Obsidian vault automatically |
| **Topic Linker** | Scans session logs every 10 minutes and adds `[[WikiLink]]` footers pointing at relevant topic notes |
| **Cowork Bridge** | Patches claude-vault so conversations from Claude Desktop's agent/co-work mode land in `Conversations/cowork-*.md` |
| **CLAUDE.md protocol** | Adds auto-archive and vault-search instructions to `~/.claude/CLAUDE.md` so Claude Code logs every session automatically |
| **Obsidian plugins** | Installs `Auto Note Mover` (and optionally `Smart Connections`) into your vault |
| **Background services** | Registers Scheduled Tasks (Windows) or LaunchAgents (macOS) so syncing happens automatically in the background |

### Vault folder structure created

```
<your-vault>/
├── Sessions/          ← Claude Code session logs (auto-created by Claude)
├── Conversations/     ← Raw conversation exports from claude-vault
├── Topics/            ← Topic notes with WikiLink cross-references
└── CLAUDE.md          ← Vault-root instructions for Claude Desktop
```

---

## Prerequisites

### Windows

| Requirement | How to get it |
|---|---|
| **Git Bash** | Included with [Git for Windows](https://git-scm.com/download/win). Run all install commands in Git Bash, not CMD or PowerShell |
| **Python 3.9+** | [python.org/downloads](https://www.python.org/downloads/) — check "Add to PATH" during install |
| **Git** | Included with Git for Windows |
| **Obsidian vault** | An existing vault (or create a new one in Obsidian first) |
| **Claude Code** | Installed and authenticated (`claude --version` works) |

> **Check your setup:** Open Git Bash and run:
> ```bash
> python3 --version && git --version && claude --version
> ```
> All three must succeed before proceeding.

### macOS

| Requirement | How to get it |
|---|---|
| **Python 3.9+** | `brew install python` or [python.org](https://www.python.org/downloads/) |
| **Git** | Xcode Command Line Tools: `xcode-select --install` |
| **Obsidian vault** | An existing vault |
| **Claude Code** | Installed and authenticated |

---

## Quick Start

### 1. Clone this repository

```bash
# Windows (Git Bash)
git clone https://github.com/YOUR_USERNAME/obsidian-claude.git /c/projects/obsidian-claude
cd /c/projects/obsidian-claude

# macOS
git clone https://github.com/YOUR_USERNAME/obsidian-claude.git ~/projects/obsidian-claude
cd ~/projects/obsidian-claude
```

### 2. Configure your vault path

```bash
cp config/settings.sh.example config/settings.sh
```

Open `config/settings.sh` in any text editor and set **at minimum**:

```bash
# REQUIRED — absolute path to your Obsidian vault
# Windows: use forward slashes from the drive root
VAULT_PATH="/c/Users/YOUR_NAME/path/to/YourVault"

# macOS example:
# VAULT_PATH="/Users/YOUR_NAME/Obsidian/MyVault"
```

All other settings have sensible defaults (see `config/settings.sh.example` for the full list).

### 3. Run the installer

```bash
bash install.sh
```

The installer runs steps 1–9 then prints a verification report. A fully successful install looks like:

```
=== Verification ===
  ✓ Vault exists
  ✓ Sessions folder
  ✓ Topics folder
  ✓ Conversations folder
  ✓ claude-vault binary (Windows)
  ✓ vault-state dir
  ✓ ClaudeVaultWatch task
  ✓ ObsidianTopicLinker task
  ✓ ClaudeVaultCoworkPeriodic task
  ✓ Watcher .cmd shim
  ✓ Auto-archive protocol in CLAUDE.md
  ✓ Vault-read protocol in CLAUDE.md
  ✓ Smart Connections plugin
  ✓ Auto Note Mover plugin
  ✓ topic-linker.py installed
  ✓ topic-linker config
  ✓ cli.py patched (sentinel)
  ✓ sync.py patched (sentinel)
  ✓ Vault CLAUDE.md bridge block

=== Result: 19 passed, 0 failed ===
```

### 4. Post-install steps

1. **Open Obsidian** → Settings → Community Plugins → enable **Auto Note Mover** (and Smart Connections if you installed it).
2. **Windows**: Log off and back on (or restart) so the Scheduled Tasks fire on logon.
3. **macOS**: The LaunchAgents are already loaded; no restart needed.
4. **Start a Claude Code session** — at the end, Claude will automatically write a session log to `Sessions/YYYY-MM-DD-<project>-<topic>.md`.

---

## Configuration Reference

Edit `config/settings.sh` before running the installer.

| Variable | Default | Description |
|---|---|---|
| `VAULT_PATH` | *(required)* | Absolute path to your Obsidian vault |
| `TOPICS_FOLDER` | `Topics` | Subfolder name for topic notes |
| `CLAUDE_VAULT_HOME` | `$HOME/claude-vault` | Where claude-vault is cloned and installed |
| `CLAUDE_VAULT_REPO` | MarioPadilla/claude-vault | GitHub repo for claude-vault |
| `WATCHER_TASK_NAME` | `ClaudeVaultWatch` | Windows Scheduled Task name for the watcher |
| `LINKER_TASK_NAME` | `ObsidianTopicLinker` | Windows Scheduled Task name for the topic linker |
| `COWORK_TASK_NAME` | `ClaudeVaultCoworkPeriodic` | Windows Scheduled Task name for Cowork sync |

---

## Running Individual Steps

Each script is idempotent (safe to re-run). You can run steps independently:

```bash
bash scripts/01-detect-os.sh          # Detect OS
bash scripts/02-vault-structure.sh    # Create vault folders
bash scripts/03-install-claude-vault.sh  # Clone and install claude-vault
bash scripts/04-init-and-sync.sh      # Init watcher + historical sync
bash scripts/05-install-shims-and-tasks.sh  # Background services
bash scripts/06-topic-linker.sh       # Topic linker + starter notes
bash scripts/07-patch-claude-md.sh    # Patch ~/.claude/CLAUDE.md
bash scripts/08-install-plugins.sh    # Obsidian plugins
bash scripts/09-cowork-bridge.sh      # Cowork Bridge patches
bash scripts/10-verify.sh             # Verification only
```

Or run verification at any time:

```bash
bash install.sh --verify-only
```

---

## Uninstalling

### Windows — remove Scheduled Tasks

```powershell
# In PowerShell (Admin or regular user scope):
powershell -ExecutionPolicy Bypass -File powershell/unregister-tasks.ps1
```

### macOS — unload LaunchAgents

```bash
launchctl unload ~/Library/LaunchAgents/com.claudevault.watch.plist
launchctl unload ~/Library/LaunchAgents/obsidian.topic-linker.plist
launchctl unload ~/Library/LaunchAgents/com.claudevault.cowork-periodic.plist
rm ~/Library/LaunchAgents/com.claudevault.watch.plist
rm ~/Library/LaunchAgents/obsidian.topic-linker.plist
rm ~/Library/LaunchAgents/com.claudevault.cowork-periodic.plist
```

### Remove claude-vault

```bash
rm -rf ~/claude-vault
```

### Revert CLAUDE.md

Open `~/.claude/CLAUDE.md` and remove the sections that start with `## OBSIDIAN AUTO-ARCHIVE PROTOCOL` and `## Vault Read`.

---

## How It Works

### Session auto-archiving

The `~/.claude/CLAUDE.md` patch instructs Claude Code (via its global instructions) to:

1. At the **end of every session**, write a log to `<vault>/Sessions/YYYY-MM-DD-<project>-<topic>.md`
2. **Before doing any research**, search the vault first (`Sessions/`, `Topics/`, `Conversations/`)

This is enforced by Claude's own instruction-following — no daemon needed.

### claude-vault watcher

`claude-vault watch` monitors `~/.claude/projects/` (where Claude Code stores conversation history) and syncs any new or updated conversations to `<vault>/Conversations/` as Markdown files.

On Windows, this runs as a Scheduled Task (`ClaudeVaultWatch`) that starts on logon.  
On macOS, it runs as a LaunchAgent (`com.claudevault.watch`).

### Topic linker

`topic-linker.py` runs every 10 minutes. It:

1. Reads all `.md` files in `Topics/`
2. Scans each session log in `Sessions/`
3. Adds or updates a `## See Also` footer with `[[WikiLinks]]` to any topic notes mentioned in the session

The footer is idempotent (managed by a `<!-- topic-linker managed -->` marker).

### Cowork Bridge

Two monkey-patches are applied to `claude_vault/sync.py` and `claude_vault/cli.py`:

- **`sync.py`**: Detects conversations coming from Claude Desktop's `local-agent-mode-sessions` directory and prefixes their filenames with `cowork-` (or `cowork-subagent-` for sub-agent conversations)
- **`cli.py`**: Adds a `--version` flag to the CLI

Patches are bounded by sentinel comments (`# OCDVB-MANAGED:START v1.0` … `# OCDVB-MANAGED:END`) and are stripped and reapplied on each run of `scripts/09-cowork-bridge.sh`, making them safe to re-run after claude-vault updates.

---

## Troubleshooting

### `UnicodeEncodeError` on Windows

If you see errors about cp1252 encoding, ensure all `claude-vault` commands are run with:

```bash
PYTHONUTF8=1 PYTHONIOENCODING=utf-8 claude-vault ...
```

The shims in `shims/` and the scripts in `scripts/` already set these variables.

### Scheduled Task not starting (Windows)

Run in Git Bash:
```bash
schtasks //Query //TN "ClaudeVaultWatch" //FO LIST //V
```

If the task exists but doesn't run, check the `.cmd` shim paths:
```bash
cat ~/claude-vault/run-claudevault-watch.cmd
```

The venv path must match where claude-vault was installed (`$CLAUDE_VAULT_HOME/venv/Scripts/`).

### `claude-vault watch` exits immediately

Run it manually to see errors:
```bash
cd ~/claude-vault
PYTHONUTF8=1 PYTHONIOENCODING=utf-8 venv/Scripts/claude-vault watch
# macOS:
# venv/bin/claude-vault watch
```

### Topic linker not linking

Check that `Topics/` contains `.md` files and `Sessions/` contains session logs. Run manually:
```bash
cd ~/claude-vault
PYTHONUTF8=1 python3 topic-linker.py --dry-run
```

### Cowork conversations not appearing

Verify the watcher knows about the Cowork sessions path:
```bash
~/claude-vault/venv/Scripts/claude-vault watch-list
```

You should see the `local-agent-mode-sessions` path listed. If not, re-run `scripts/09-cowork-bridge.sh`.

---

## Repository Structure

```
obsidian-claude/
├── config/
│   ├── settings.sh.example   ← Copy to settings.sh and configure
│   ├── settings.sh           ← Your local config (gitignored)
│   └── topic-linker.json     ← Template for topic-linker config
├── powershell/
│   ├── register-tasks.ps1    ← Register Windows Scheduled Tasks
│   └── unregister-tasks.ps1  ← Remove Windows Scheduled Tasks
├── python/
│   └── topic-linker.py       ← Cross-platform topic linker daemon
├── scripts/
│   ├── 01-detect-os.sh
│   ├── 02-vault-structure.sh
│   ├── 03-install-claude-vault.sh
│   ├── 04-init-and-sync.sh
│   ├── 05-install-shims-and-tasks.sh
│   ├── 06-topic-linker.sh
│   ├── 07-patch-claude-md.sh
│   ├── 08-install-plugins.sh
│   ├── 09-cowork-bridge.sh
│   └── 10-verify.sh
├── shims/
│   ├── run-claudevault-watch.cmd
│   ├── run-topic-linker.cmd
│   └── run-cowork-periodic-sync.cmd
└── install.sh                ← Main installer entry point
```

---

## Credits

- [claude-vault](https://github.com/MarioPadilla/claude-vault) by Mario Padilla — the core sync engine
- Obsidian Second Brain pattern inspired by the Building a Second Brain methodology
