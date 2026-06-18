#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Spusť přes sudo." >&2; exit 1; }
TARGET_USER="${SUDO_USER:-objng}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
AUTO="$TARGET_HOME/.config/labwc/autostart"
if [[ -f "$AUTO" ]]; then
    cp -a "$AUTO" "${AUTO}.emergency-backup.$(date +%Y%m%d_%H%M%S)"
    python3 - "$AUTO" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
t = p.read_text(encoding="utf-8")
t = re.sub(r"\n?# >>> OBJEDNAVKA-NG-KIOSK >>>.*?# <<< OBJEDNAVKA-NG-KIOSK <<<\n?", "\n", t, flags=re.S)
p.write_text(t.lstrip("\n"), encoding="utf-8")
PY
fi
/usr/local/sbin/objednavka-kiosk-system-mode desktop
echo "Obnoven běžný desktop pro příští start a odstraněn autostart aplikace."
echo "Dokonči příkazem: sudo reboot"
