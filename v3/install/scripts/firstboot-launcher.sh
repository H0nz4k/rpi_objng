#!/usr/bin/env bash
# Spustí dokončovací průvodce v lokálním terminálu pouze po první fázi instalace.
set -Eeuo pipefail
STATE="$HOME/.local/state/objednavka-ng"
MARKER="$STATE/firstboot.pending"
LOG="$STATE/firstboot-launcher.log"
mkdir -p "$STATE"
[[ -f "$MARKER" ]] || exit 0
sleep 4
{
  echo "$(date -Is) Spouštím dokončovací průvodce."
  if command -v lxterminal >/dev/null 2>&1; then
    lxterminal --title="ObjednavkaNG - dokonceni instalace" -e /usr/local/bin/objng-dokoncit &
  elif command -v x-terminal-emulator >/dev/null 2>&1; then
    x-terminal-emulator -T "ObjednavkaNG - dokonceni instalace" -e /usr/local/bin/objng-dokoncit &
  else
    echo "Nenalezen lxterminal ani x-terminal-emulator. Spusť ručně: objng-dokoncit" >&2
  fi
} >> "$LOG" 2>&1
