#!/usr/bin/env bash
# Druha cast instalace po rebootu. Vychozi rezim je automaticky pro touch-only zarizeni.
set -Eeuo pipefail

[[ "$EUID" -ne 0 ]] || { echo "Spust jako uzivatel objng, bez sudo." >&2; exit 1; }

CONFIG="/opt/objednavka-ng/config.json"
STATE="$HOME/.local/state/objednavka-ng"
MARKER="$STATE/firstboot.pending"
AUTO="$HOME/.config/labwc/autostart"
INTERACTIVE="${OBJNG_INTERACTIVE:-0}"

mkdir -p "$STATE"

ask_yes() {
  if [[ "$INTERACTIVE" != "1" ]]; then
    [[ "${2:-N}" =~ ^[AaYy]$ ]]
    return
  fi
  local prompt="$1" default="${2:-N}" ans
  read -r -p "$prompt" ans
  ans="${ans:-$default}"
  [[ "$ans" =~ ^[AaYy]$ ]]
}

cleanup_firstboot_autostart() {
  rm -f "$MARKER"
  if [[ -f "$AUTO" ]]; then
    python3 - "$AUTO" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
t = p.read_text(encoding="utf-8")
t = re.sub(r"\n?# >>> OBJEDNAVKA-NG-FIRSTBOOT >>>.*?# <<< OBJEDNAVKA-NG-FIRSTBOOT <<<\n?", "\n", t, flags=re.S)
p.write_text(t.lstrip("\n"), encoding="utf-8")
PY
  fi
}

echo "============================================================"
echo " ObjednavkaNG - dokonceni instalace po rebootu"
echo "============================================================"
echo
[[ -f "$CONFIG" ]] || { echo "Chybi config: $CONFIG" >&2; exit 1; }

if command -v teamviewer >/dev/null 2>&1; then
  echo "1. TeamViewer - kontrola/dokonceni"
  teamviewer-dokoncit || echo "TeamViewer nebyl dokoncen; lze zopakovat pozdeji: teamviewer-dokoncit"
else
  echo "1. TeamViewer neni instalovany - krok preskocen."
fi

if [[ "$INTERACTIVE" == "1" ]]; then
  echo
  if ask_yes "2. Nastavit connection ObjednavkaNG nyni? [A/n] " A; then
    nastavit-connection || echo "Connection nebyla zmenena."
  fi
else
  echo
  echo "2. Connection ponechana podle pripraveneho config.json."
fi

echo
echo "3. Zapinam kiosk rezim a autostart aplikace."
kiosk-mode on || true
objednavka-autostart on || true

echo
echo "4. Klavesnice na obrazovce zustava zapnuta pro touch-only obsluhu."

cleanup_firstboot_autostart

echo
echo "Dokonceni instalace je ulozene. Restartuji za 5 sekund..."
sleep 5
sudo reboot
