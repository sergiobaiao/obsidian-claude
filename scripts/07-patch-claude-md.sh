#!/usr/bin/env bash
# 07-patch-claude-md.sh
# Appends the OBSIDIAN AUTO-ARCHIVE PROTOCOL and Vault Read sections
# to ~/.claude/CLAUDE.md. Safe to re-run — checks for existing sections first.

set -euo pipefail
source "$(dirname "$0")/../config/settings.sh" 2>/dev/null || true

: "${VAULT_PATH:?Set VAULT_PATH in config/settings.sh}"
: "${TOPICS_FOLDER:=Topics}"

CLAUDE_MD="$HOME/.claude/CLAUDE.md"
mkdir -p "$HOME/.claude"
touch "$CLAUDE_MD"

# Skip if already patched
if grep -q "OBSIDIAN AUTO-ARCHIVE PROTOCOL" "$CLAUDE_MD" 2>/dev/null; then
  echo "CLAUDE_MD already patched — skipping."
  exit 0
fi

echo "Patching ~/.claude/CLAUDE.md..."

cat >> "$CLAUDE_MD" << MDEOF

---

## OBSIDIAN AUTO-ARCHIVE PROTOCOL (MANDATORY)

**This applies to EVERY Claude Code session, regardless of project.**

### Session Logging (Automatic)

At the END of every session, automatically create a session log at:
\`\`\`
$VAULT_PATH/Sessions/YYYY-MM-DD-<project>-<brief-topic>.md
\`\`\`

Use this template:

\`\`\`markdown
---
date: YYYY-MM-DD
project: <project-name>
tags: [session-log]
---

# Session: <Brief Topic>

## Summary
<2-3 sentences about what was accomplished>

## Key Decisions
- <decision 1>

## Changes Made
- <change 1>

## Topics Referenced
- [[Topic 1]]

## Next Steps
- <step 1>

---
## See Also
- [[Related Topic 1]]
\`\`\`

**Important rules:**
- Add a \`## See Also\` footer with [[WikiLinks]] to relevant topic notes
- **NEVER ask permission to save session logs** — just do it automatically
- **NEVER skip logging, even for short sessions**
- Use ABSOLUTE PATHS everywhere. The vault lives at $VAULT_PATH.

**Topic note types:** People, Projects, Tools/Services, Concepts, Organizations.

## Vault Read — SEARCH BEFORE YOU WORK (MANDATORY)

**This applies to EVERY Claude Code session, regardless of project.**

### ⚠️ CRITICAL RULE: VAULT FIRST, EVERYTHING ELSE SECOND

**BEFORE you clone a repo, run a web search, or do any research — SEARCH THE OBSIDIAN VAULT FIRST.**

\`\`\`bash
grep -rl "<keyword>" "$VAULT_PATH/Sessions/" "$VAULT_PATH/$TOPICS_FOLDER/" "$VAULT_PATH/Conversations/"
\`\`\`

### Search Order

1. Check \`$VAULT_PATH/$TOPICS_FOLDER/\` for a matching topic note
2. Check \`$VAULT_PATH/Sessions/\` for session logs
3. Check \`$VAULT_PATH/Conversations/\` for raw conversation exports
4. **ONLY THEN** go external

MDEOF

echo "CLAUDE_MD_PATCHED=1"
