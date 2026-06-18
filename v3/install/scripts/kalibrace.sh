#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q # Univerzální servisní příkaz: automaticky zvolí kalibraci podle připojeného touch panelu.
set -Eeuo pipefail
[[ "$EUID" -ne 0 ]] || { echo "Spusť jako běžný uživatel bez sudo: kalibrace" >&2; exit 1; }
CALIBRATOR="/usr/local/bin/touch-calibrator"
APP="/opt/objednavka-ng/objednavka-ng.AppImage"
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
DISPLAY_VALUE="${DISPLAY:-:0}"
XAUTHORITY_VALUE="${XAUTHORITY:-$TARGET_HOME/.Xauthority}"

has_usb() { lsusb 2>/dev/null | grep -qi "$1"; }
force_reboot() {
  echo
  echo "Kalibrace/příprava dotyku vyžaduje restart zařízení."
  echo "Restartuji nyní..."
  sleep 3
  sudo reboot
}

HAS_EGALAX=0; HAS_3M=0
has_usb '0eef:0001' && HAS_EGALAX=1 || true
has_usb '0596:0001' && HAS_3M=1 || true

if [[ "$HAS_EGALAX" -eq 1 && "$HAS_3M" -eq 1 ]]; then
  echo "CHYBA: Současně je nalezen eGalax i 3M touch. Kalibraci spusť až s jedním připojeným panelem." >&2
  exit 1
fi

if [[ "$HAS_EGALAX" -eq 1 ]]; then
  echo "Detekován eGalax USB touchscreen 0eef:0001."
  command -v eCalib >/dev/null 2>&1 || {
    echo "Oficiální EETI eCalib není nainstalovaný." >&2
    echo "Spusť: sudo install-egalax-eeti --accept-license && sudo reboot" >&2
    exit 1
  }
  echo "Spouštím oficiální EETI kalibrátor. V nabídce zvol 1 = 4 points calibration."
  sudo env DISPLAY="$DISPLAY_VALUE" XAUTHORITY="$XAUTHORITY_VALUE" /usr/bin/eCalib
  force_reboot
fi

if [[ "$HAS_3M" -eq 1 ]]; then
  echo "Detekován 3M USB touchscreen 0596:0001."
  [[ -x "$CALIBRATOR" ]] || { echo "Kalibrátor není nainstalovaný: $CALIBRATOR" >&2; exit 1; }
  if pgrep -u "$(id -u)" -f "$APP" >/dev/null 2>&1; then
    echo "Aplikace ObjednávkaNG stále běží. Nejprve ji zavři křížkem." >&2
    exit 1
  fi
  export DISPLAY="$DISPLAY_VALUE" XAUTHORITY="$XAUTHORITY_VALUE"
  echo "Spouštím fullscreen kalibrátor pro 3M."
  echo "Nejdřív ověřuji sudo, aby kalibrátor po dokončení nezůstal čekat na heslo ve fullscreen režimu."
  sudo -v
  "$CALIBRATOR" "$@"
  force_reboot
fi

echo "Nebyl nalezen podporovaný touch panel."
echo "Podporováno: eGalax 0eef:0001 nebo 3M 0596:0001."
echo "Diagnostika: lsusb; grep -i -A8 -B2 -E 'eGalax|3M|Touch' /proc/bus/input/devices"
exit 1
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
# Univerzální servisní příkaz: automaticky zvolí kalibraci podle připojeného touch panelu.
set -Eeuo pipefail
[[ "$EUID" -ne 0 ]] || { echo "Spusť jako běžný uživatel bez sudo: kalibrace" >&2; exit 1; }
CALIBRATOR="/usr/local/bin/touch-calibrator"
APP="/opt/objednavka-ng/objednavka-ng.AppImage"
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
DISPLAY_VALUE="${DISPLAY:-:0}"
XAUTHORITY_VALUE="${XAUTHORITY:-$TARGET_HOME/.Xauthority}"

has_usb() { lsusb 2>/dev/null | grep -qi "$1"; }
force_reboot() {
  echo
  echo "Kalibrace/příprava dotyku vyžaduje restart zařízení."
  echo "Restartuji nyní..."
  sleep 3
  sudo reboot
}

HAS_EGALAX=0; HAS_3M=0
has_usb '0eef:0001' && HAS_EGALAX=1 || true
has_usb '0596:0001' && HAS_3M=1 || true

if [[ "$HAS_EGALAX" -eq 1 && "$HAS_3M" -eq 1 ]]; then
  echo "CHYBA: Současně je nalezen eGalax i 3M touch. Kalibraci spusť až s jedním připojeným panelem." >&2
  exit 1
fi

if [[ "$HAS_EGALAX" -eq 1 ]]; then
  echo "Detekován eGalax USB touchscreen 0eef:0001."
  command -v eCalib >/dev/null 2>&1 || {
    echo "Oficiální EETI eCalib není nainstalovaný." >&2
    echo "Spusť: sudo install-egalax-eeti --accept-license && sudo reboot" >&2
    exit 1
  }
  echo "Spouštím oficiální EETI kalibrátor. V nabídce zvol 1 = 4 points calibration."
  sudo env DISPLAY="$DISPLAY_VALUE" XAUTHORITY="$XAUTHORITY_VALUE" /usr/bin/eCalib
  force_reboot
fi

if [[ "$HAS_3M" -eq 1 ]]; then
  echo "Detekován 3M USB touchscreen 0596:0001."
  [[ -x "$CALIBRATOR" ]] || { echo "Kalibrátor není nainstalovaný: $CALIBRATOR" >&2; exit 1; }
  if pgrep -u "$(id -u)" -f "$APP" >/dev/null 2>&1; then
    echo "Aplikace ObjednávkaNG stále běží. Nejprve ji zavři křížkem." >&2
    exit 1
  fi
  export DISPLAY="$DISPLAY_VALUE" XAUTHORITY="$XAUTHORITY_VALUE"
  echo "Spouštím fullscreen kalibrátor pro 3M."
  echo "Nejdřív ověřuji sudo, aby kalibrátor po dokončení nezůstal čekat na heslo ve fullscreen režimu."
  sudo -v
  "$CALIBRATOR" "$@"
  force_reboot
fi

echo "Nebyl nalezen podporovaný touch panel."
echo "Podporováno: eGalax 0eef:0001 nebo 3M 0596:0001."
echo "Diagnostika: lsusb; grep -i -A8 -B2 -E 'eGalax|3M|Touch' /proc/bus/input/devices"
exit 1
