#!/usr/bin/env bash
# 01-detect-os.sh — Detect and export OS_DETECTED. Source this before other scripts.

case "$(uname -s)" in
  Darwin*)              OS_DETECTED=mac ;;
  MINGW*|MSYS*|CYGWIN*) OS_DETECTED=windows ;;
  Linux*)               OS_DETECTED=linux ;;
  *)                    OS_DETECTED=unknown ;;
esac

export OS_DETECTED
echo "OS_DETECTED=$OS_DETECTED"

if [ "$OS_DETECTED" = "linux" ]; then
  echo "ERROR: Linux is not currently supported." >&2
  exit 1
fi
if [ "$OS_DETECTED" = "unknown" ]; then
  echo "ERROR: Could not detect OS (uname -s = $(uname -s))." >&2
  exit 1
fi
