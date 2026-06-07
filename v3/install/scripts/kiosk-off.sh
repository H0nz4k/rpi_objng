#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$EUID" -ne 0 ]] || { echo "Spusť jako běžný uživatel, bez sudo."; exit 1; }
AUTO="${HOME}/.config/labwc/autostart"
STATE="${HOME}/.local/state/objednavka-ng"
APP="/opt/objednavka-ng/objednavka-ng.AppImage"
mkdir -p "$STATE"
if [[ -f "$AUTO" ]]; then
    cp -a "$AUTO" "$STATE/autostart.before-kiosk-off.$(date +%Y%m%d_%H%M%S)"
    python3 - "$AUTO" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
t = p.read_text(encoding="utf-8")
t = re.sub(r"\n?# >>> OBJEDNAVKA-NG-KIOSK >>>.*?# <<< OBJEDNAVKA-NG-KIOSK <<<\n?", "\n", t, flags=re.S)
p.write_text(t.lstrip("\n"), encoding="utf-8")
PY
fi

echo "Nastavuji běžný desktop pro příští start; sudo může vyžádat heslo."
sudo /usr/local/sbin/objednavka-kiosk-system-mode desktop
echo "Kiosk po rebootu: VYPNUTÝ"
echo "Použij: sudo reboot"

if [[ "${1:-}" == "--now" || "${1:-}" == "--close-now" ]]; then
    pkill -u "$(id -u)" -f "$APP" 2>/dev/null || true
    gui-on
    echo "Aplikace byla zavřena a GUI bylo zobrazeno ihned."
fi
