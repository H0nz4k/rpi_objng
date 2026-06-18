#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q set -Eeuo pipefail
[[ "$EUID" -ne 0 ]] || { echo "Spusť jako běžný uživatel, bez sudo."; exit 1; }
AUTO="${HOME}/.config/labwc/autostart"
STATE="${HOME}/.local/state/objednavka-ng"
mkdir -p "$(dirname "$AUTO")" "$STATE"
touch "$AUTO"
cp -a "$AUTO" "$STATE/autostart.before-kiosk-on.$(date +%Y%m%d_%H%M%S)"

python3 - "$AUTO" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
t = p.read_text(encoding="utf-8")
t = re.sub(r"\n?# >>> OBJEDNAVKA-NG-KIOSK >>>.*?# <<< OBJEDNAVKA-NG-KIOSK <<<\n?", "\n", t, flags=re.S)
t = t.rstrip() + "\n\n# >>> OBJEDNAVKA-NG-KIOSK >>>\n/opt/objednavka-ng/scripts/kiosk-run.sh &\n# <<< OBJEDNAVKA-NG-KIOSK <<<\n"
p.write_text(t, encoding="utf-8")
PY
chmod +x "$AUTO"

echo "Nastavuji čistý kiosk pro příští start; sudo může vyžádat heslo."
sudo /usr/local/sbin/objednavka-kiosk-system-mode clean
echo "Kiosk po rebootu: ZAPNUTÝ"
echo "Použij: sudo reboot"

if [[ "${1:-}" == "--now" ]]; then
    gui-off
    /opt/objednavka-ng/scripts/kiosk-run.sh &
    echo "Kiosk byl spuštěn také ihned."
fi
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
set -Eeuo pipefail
[[ "$EUID" -ne 0 ]] || { echo "Spusť jako běžný uživatel, bez sudo."; exit 1; }
AUTO="${HOME}/.config/labwc/autostart"
STATE="${HOME}/.local/state/objednavka-ng"
mkdir -p "$(dirname "$AUTO")" "$STATE"
touch "$AUTO"
cp -a "$AUTO" "$STATE/autostart.before-kiosk-on.$(date +%Y%m%d_%H%M%S)"

python3 - "$AUTO" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
t = p.read_text(encoding="utf-8")
t = re.sub(r"\n?# >>> OBJEDNAVKA-NG-KIOSK >>>.*?# <<< OBJEDNAVKA-NG-KIOSK <<<\n?", "\n", t, flags=re.S)
t = t.rstrip() + "\n\n# >>> OBJEDNAVKA-NG-KIOSK >>>\n/opt/objednavka-ng/scripts/kiosk-run.sh &\n# <<< OBJEDNAVKA-NG-KIOSK <<<\n"
p.write_text(t, encoding="utf-8")
PY
chmod +x "$AUTO"

echo "Nastavuji čistý kiosk pro příští start; sudo může vyžádat heslo."
sudo /usr/local/sbin/objednavka-kiosk-system-mode clean
echo "Kiosk po rebootu: ZAPNUTÝ"
echo "Použij: sudo reboot"

if [[ "${1:-}" == "--now" ]]; then
    gui-off
    /opt/objednavka-ng/scripts/kiosk-run.sh &
    echo "Kiosk byl spuštěn také ihned."
fi
