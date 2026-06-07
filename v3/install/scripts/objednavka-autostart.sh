#!/usr/bin/env bash
# Samostatné zapnutí/vypnutí spuštění aplikace po přihlášení; nemění viditelnost desktopu.
set -Eeuo pipefail
[[ "$EUID" -ne 0 ]] || { echo "Spusť jako běžný uživatel, bez sudo." >&2; exit 1; }
AUTO="${HOME}/.config/labwc/autostart"
STATE="${HOME}/.local/state/objednavka-ng"
MODE="${1:-status}"
mkdir -p "$(dirname "$AUTO")" "$STATE"
touch "$AUTO"
remove_block() {
python3 - "$AUTO" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); t=p.read_text(encoding='utf-8')
t=re.sub(r"\n?# >>> OBJEDNAVKA-NG-KIOSK >>>.*?# <<< OBJEDNAVKA-NG-KIOSK <<<\n?", "\n", t, flags=re.S)
p.write_text(t.lstrip('\n'), encoding='utf-8')
PY
}
case "$MODE" in
  on|enable)
    cp -a "$AUTO" "$STATE/autostart.before-app-on.$(date +%Y%m%d_%H%M%S)"
    remove_block
    cat >> "$AUTO" <<'BLOCK'

# >>> OBJEDNAVKA-NG-KIOSK >>>
/opt/objednavka-ng/scripts/kiosk-run.sh &
# <<< OBJEDNAVKA-NG-KIOSK <<<
BLOCK
    chmod +x "$AUTO"
    echo "Automatické spuštění ObjednávkaNG po startu: ZAPNUTO"
    ;;
  off|disable)
    cp -a "$AUTO" "$STATE/autostart.before-app-off.$(date +%Y%m%d_%H%M%S)"
    remove_block
    echo "Automatické spuštění ObjednávkaNG po startu: VYPNUTO"
    ;;
  status)
    if grep -Fq '# >>> OBJEDNAVKA-NG-KIOSK >>>' "$AUTO"; then echo "Automatické spuštění ObjednávkaNG: ZAPNUTO"; else echo "Automatické spuštění ObjednávkaNG: VYPNUTO"; fi
    ;;
  *) echo "Použití: objednavka-autostart {on|off|status}" >&2; exit 1 ;;
esac
