#!/usr/bin/env bash
set -Eeuo pipefail
U="$(id -u)"
pkill -u "$U" -f '/usr/bin/lwrespawn /usr/bin/pcmanfm-pi' 2>/dev/null || true
pkill -u "$U" -f '/usr/bin/lwrespawn /usr/bin/wf-panel-pi' 2>/dev/null || true
pkill -u "$U" -f '/usr/bin/pcmanfm-pi' 2>/dev/null || true
pkill -u "$U" -x pcmanfm 2>/dev/null || true
pkill -u "$U" -x wf-panel-pi 2>/dev/null || true
echo "Plocha a panel byly v aktuální relaci skryty."
echo "Boot režim se nezměnil."
