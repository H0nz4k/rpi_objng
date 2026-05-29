#!/usr/bin/env bash
set -Eeuo pipefail
CALIBRATOR="/usr/local/bin/touch-calibrator"
APP="/opt/objednavka-ng/objednavka-ng.AppImage"
[[ -x "$CALIBRATOR" ]] || { echo "Kalibrátor není nainstalovaný: $CALIBRATOR" >&2; exit 1; }
if [[ -z "${WAYLAND_DISPLAY:-}" && -z "${DISPLAY:-}" ]]; then echo "Kalibraci spusť z terminálu v grafické relaci nebo přes TeamViewer, ne z čistého SSH." >&2; exit 1; fi
if pgrep -u "$(id -u)" -f "$APP" >/dev/null 2>&1; then echo "Aplikace ObjednávkaNG stále běží. Nejprve ji zavři křížkem." >&2; exit 1; fi
if libinput list-devices 2>/dev/null | grep -q 'eGalaxTouch Virtual Device for Single'; then
  echo "Detekován eGalaxTouch s EETI virtuálním vstupem."
  echo "Tento vstup byl hlášen s 'Calibration: n/a'; použij oficiální EETI kalibrátor."
  exit 2
fi
exec "$CALIBRATOR" "$@"
