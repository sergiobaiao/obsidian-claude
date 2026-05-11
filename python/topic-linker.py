#!/usr/bin/env python3
"""
topic-linker.py — Obsidian Second Brain / Cowork Bridge
Scans session logs in Sessions/ and adds "See Also" [[WikiLinks]] footers
pointing at matching topic notes in Topics/ (or configured TOPICS_FOLDER).

Cross-platform: works on macOS, Linux, and Windows.
Run every 10 minutes via LaunchAgent (macOS) or Scheduled Task (Windows).
"""

import json
import os
import re
import sys
import time
import logging
from pathlib import Path
from datetime import datetime

# ---------------------------------------------------------------------------
# Platform-safe file locking
# ---------------------------------------------------------------------------
try:
    import fcntl  # macOS / Linux

    def _lock(fh):
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def _unlock(fh):
        fcntl.flock(fh, fcntl.LOCK_UN)

except ImportError:
    import msvcrt  # Windows

    def _lock(fh):
        fh.seek(0)
        msvcrt.locking(fh.fileno(), msvcrt.LK_NBLCK, 1)

    def _unlock(fh):
        fh.seek(0)
        try:
            msvcrt.locking(fh.fileno(), msvcrt.LK_UNLCK, 1)
        except OSError:
            pass


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------
CONFIG_PATHS = [
    Path.home() / ".config" / "topic-linker" / "config.json",
    Path(__file__).parent / "topic-linker-config.json",
]


def load_config() -> dict:
    for path in CONFIG_PATHS:
        if path.exists():
            with open(path, encoding="utf-8") as f:
                return json.load(f)
    raise FileNotFoundError(
        "topic-linker config not found. Looked in:\n"
        + "\n".join(str(p) for p in CONFIG_PATHS)
    )


# ---------------------------------------------------------------------------
# Topic extraction
# ---------------------------------------------------------------------------

def get_topic_names(topics_dir: Path) -> list[str]:
    """Return stem names of all .md files in the topics directory."""
    if not topics_dir.exists():
        return []
    return [p.stem for p in topics_dir.glob("*.md") if p.is_file()]


def find_matching_topics(text: str, topic_names: list[str]) -> list[str]:
    """Return topic names mentioned (case-insensitive word boundary match) in text."""
    matches = []
    for name in topic_names:
        # Escape special regex chars in topic name
        escaped = re.escape(name)
        if re.search(rf"\b{escaped}\b", text, re.IGNORECASE):
            matches.append(name)
    return matches


# ---------------------------------------------------------------------------
# See Also footer management
# ---------------------------------------------------------------------------

SEE_ALSO_HEADER = "## See Also"
MANAGED_MARKER = "<!-- topic-linker managed -->"


def build_see_also_block(topics: list[str]) -> str:
    lines = [SEE_ALSO_HEADER, MANAGED_MARKER]
    for t in sorted(topics):
        lines.append(f"- [[{t}]]")
    return "\n".join(lines) + "\n"


def update_see_also(content: str, new_topics: list[str]) -> tuple[str, bool]:
    """
    Insert or replace the managed See Also block at the end of content.
    Returns (new_content, changed).
    """
    # Strip existing managed block
    pattern = re.compile(
        rf"{re.escape(SEE_ALSO_HEADER)}\n{re.escape(MANAGED_MARKER)}.*",
        re.DOTALL,
    )
    stripped = pattern.sub("", content).rstrip()

    if not new_topics:
        changed = stripped != content.rstrip()
        return stripped + "\n", changed

    block = build_see_also_block(new_topics)
    new_content = stripped + "\n\n---\n" + block
    changed = new_content != content
    return new_content, changed


# ---------------------------------------------------------------------------
# Atomic write (cross-platform)
# ---------------------------------------------------------------------------

def atomic_write(path: Path, content: str):
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(content)
    os.replace(tmp, path)  # atomic on POSIX; replace() works on Windows too


# ---------------------------------------------------------------------------
# Process a single session file
# ---------------------------------------------------------------------------

def process_session(session_path: Path, topic_names: list[str], dry_run: bool = False) -> bool:
    """
    Returns True if the file was (or would be) modified.
    """
    try:
        with open(session_path, encoding="utf-8") as f:
            content = f.read()
    except (OSError, UnicodeDecodeError) as e:
        logging.warning("Could not read %s: %s", session_path, e)
        return False

    matched = find_matching_topics(content, topic_names)
    new_content, changed = update_see_also(content, matched)

    if changed:
        logging.info("Updating %s → topics: %s", session_path.name, matched or "(none)")
        if not dry_run:
            atomic_write(session_path, new_content)

    return changed


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def run_once(vault_path: Path, topics_folder: str, dry_run: bool = False) -> int:
    sessions_dir = vault_path / "Sessions"
    topics_dir = vault_path / topics_folder

    topic_names = get_topic_names(topics_dir)
    if not topic_names:
        logging.warning("No topic notes found in %s", topics_dir)

    session_files = list(sessions_dir.glob("*.md")) if sessions_dir.exists() else []
    updated = 0
    for sf in session_files:
        if process_session(sf, topic_names, dry_run=dry_run):
            updated += 1

    logging.info(
        "Scan complete: %d session(s) checked, %d updated. Topics available: %d",
        len(session_files),
        updated,
        len(topic_names),
    )
    return updated


def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [topic-linker] %(levelname)s %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
        stream=sys.stdout,
    )

    dry_run = "--dry-run" in sys.argv

    try:
        cfg = load_config()
    except FileNotFoundError as e:
        logging.error(str(e))
        sys.exit(1)

    vault_path = Path(cfg.get("vault_path", "")).expanduser()
    topics_folder = cfg.get("topics_folder", "Topics")

    if not vault_path.exists():
        logging.error("Vault path does not exist: %s", vault_path)
        sys.exit(1)

    logging.info("Starting topic-linker. Vault: %s | Topics: %s", vault_path, topics_folder)

    if dry_run:
        logging.info("DRY RUN — no files will be written.")
        run_once(vault_path, topics_folder, dry_run=True)
        return

    # Daemon mode: run once, then exit (scheduled externally every 10 min)
    run_once(vault_path, topics_folder)


if __name__ == "__main__":
    main()
