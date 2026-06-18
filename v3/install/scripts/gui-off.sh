#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q set -Eeuo pipefail
U="$(id -u)"
pkill -u "$U" -f '/usr/bin/lwrespawn /usr/bin/pcmanfm-pi' 2>/dev/null || true
pkill -u "$U" -f '/usr/bin/lwrespawn /usr/bin/wf-panel-pi' 2>/dev/null || true
pkill -u "$U" -f '/usr/bin/pcmanfm-pi' 2>/dev/null || true
pkill -u "$U" -x pcmanfm 2>/dev/null || true
pkill -u "$U" -x wf-panel-pi 2>/dev/null || true
echo "Plocha a panel byly v aktuální relaci skryty."
echo "Boot režim se nezměnil."
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
set -Eeuo pipefail
U="$(id -u)"
pkill -u "$U" -f '/usr/bin/lwrespawn /usr/bin/pcmanfm-pi' 2>/dev/null || true
pkill -u "$U" -f '/usr/bin/lwrespawn /usr/bin/wf-panel-pi' 2>/dev/null || true
pkill -u "$U" -f '/usr/bin/pcmanfm-pi' 2>/dev/null || true
pkill -u "$U" -x pcmanfm 2>/dev/null || true
pkill -u "$U" -x wf-panel-pi 2>/dev/null || true
echo "Plocha a panel byly v aktuální relaci skryty."
echo "Boot režim se nezměnil."
