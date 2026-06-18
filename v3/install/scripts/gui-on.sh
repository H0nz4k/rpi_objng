#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q set -Eeuo pipefail
if ! pgrep -u "$(id -u)" -x pcmanfm >/dev/null 2>&1; then
    nohup /usr/bin/lwrespawn /usr/bin/pcmanfm-pi >"/tmp/pcmanfm-pi.$(id -u).log" 2>&1 &
    echo "Plocha spuštěna."
else
    echo "Plocha už běží."
fi
if ! pgrep -u "$(id -u)" -x wf-panel-pi >/dev/null 2>&1; then
    nohup /usr/bin/lwrespawn /usr/bin/wf-panel-pi >"/tmp/wf-panel-pi.$(id -u).log" 2>&1 &
    echo "Panel spuštěn."
else
    echo "Panel už běží."
fi
echo "Boot režim se nezměnil; po rebootu zůstává nastavený kiosk/desktop podle kiosk-on nebo kiosk-off."
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
set -Eeuo pipefail
if ! pgrep -u "$(id -u)" -x pcmanfm >/dev/null 2>&1; then
    nohup /usr/bin/lwrespawn /usr/bin/pcmanfm-pi >"/tmp/pcmanfm-pi.$(id -u).log" 2>&1 &
    echo "Plocha spuštěna."
else
    echo "Plocha už běží."
fi
if ! pgrep -u "$(id -u)" -x wf-panel-pi >/dev/null 2>&1; then
    nohup /usr/bin/lwrespawn /usr/bin/wf-panel-pi >"/tmp/wf-panel-pi.$(id -u).log" 2>&1 &
    echo "Panel spuštěn."
else
    echo "Panel už běží."
fi
echo "Boot režim se nezměnil; po rebootu zůstává nastavený kiosk/desktop podle kiosk-on nebo kiosk-off."
