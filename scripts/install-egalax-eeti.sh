#!/usr/bin/env bash
# Instalace oficiálního EETI eGTouch driveru pro eGalax USB 0eef:0001 / Raspberry Pi OS arm64.
set -Eeuo pipefail

[[ "$EUID" -eq 0 ]] || { echo "Spusť přes sudo: sudo install-egalax-eeti" >&2; exit 1; }

ARCHIVE_NAME="eGTouch_v2.5.13219.L-ma.7z"
OFFICIAL_URL="https://www.eeti.com/touch_driver/Linux/20240510/${ARCHIVE_NAME}"
VENDOR_DIR="/opt/objednavka-ng/vendor/eeti"
ARCHIVE="$VENDOR_DIR/$ARCHIVE_NAME"
WORK="$VENDOR_DIR/extracted"
ACCEPT_LICENSE=0
ALLOW_DOWNLOAD=1
AUTO_REBOOT=1

usage() {
  cat <<USAGE
Použití: sudo install-egalax-eeti [--accept-license] [--no-download] [--no-reboot]

Instaluje ověřený oficiální EETI driver pro eGalax USB 0eef:0001:
  AARCH64 withX + eGTouchD + eCalib.
Archiv může být předem vložen v:
  $ARCHIVE
USAGE
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --accept-license) ACCEPT_LICENSE=1; shift ;;
    --no-download) ALLOW_DOWNLOAD=0; shift ;;
    --no-reboot) AUTO_REBOOT=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Neznámá volba: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$(dpkg --print-architecture 2>/dev/null || true)" != "arm64" ]]; then
  echo "CHYBA: EETI automatická instalace je připravená pouze pro Raspberry Pi OS arm64." >&2
  exit 1
fi

if command -v eCalib >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q '^eGTouchD.service'; then
  echo "EETI eGTouch je již nainstalovaný: $(command -v eCalib)"
  systemctl enable --now eGTouchD.service >/dev/null 2>&1 || true
  exit 0
fi

if [[ "$ACCEPT_LICENSE" -ne 1 ]]; then
  cat <<'MSG'
Oficiální EETI instalátor před instalací zobrazuje vlastní licenční prohlášení.
Automatizovaná instalace může pokračovat jen po tvém výslovném souhlasu.
MSG
  read -r -p "Souhlasíš s licenčním prohlášením EETI a chceš driver nainstalovat? [a/N] " answer
  [[ "${answer:-N}" =~ ^[AaYy]$ ]] || { echo "Instalace EETI zrušena."; exit 1; }
fi

mkdir -p "$VENDOR_DIR"
if [[ ! -s "$ARCHIVE" ]]; then
  if [[ "$ALLOW_DOWNLOAD" -eq 1 ]]; then
    echo "Lokální EETI archiv nenalezen. Stahuji oficiální balík EETI..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates wget p7zip-full
    wget -O "$ARCHIVE" "$OFFICIAL_URL"
  else
    echo "CHYBA: chybí $ARCHIVE" >&2
    echo "Pro offline instalaci vlož ${ARCHIVE_NAME} do files/drivers/ instalačního balíku." >&2
    exit 1
  fi
fi

DEBIAN_FRONTEND=noninteractive apt-get install -y p7zip-full
rm -rf "$WORK"
mkdir -p "$WORK"
7z x -y "$ARCHIVE" -o"$WORK" >/dev/null
SETUP="$(find "$WORK" -type f -name setup.sh -print -quit)"
[[ -n "$SETUP" ]] || { echo "CHYBA: V archivu nebyl nalezen setup.sh." >&2; exit 1; }
chmod +x "$SETUP"

echo "Instaluji EETI AARCH64 withX pro USB controller, blacklist usbtouchscreen a 1 controller..."
# Odpovědi ověřené na čistém Raspberry Pi OS arm64:
# license=yes, interface=USB, zařízení připojeno, rotation/multimonitor=no,
# blacklist usbtouchscreen=yes, počet controllerů=1.
printf 'y\n2\n\nn\ny\n1\n' | bash "$SETUP"

[[ -x /usr/bin/eGTouchD || -L /usr/bin/eGTouchD ]] || { echo "CHYBA: instalace nevytvořila /usr/bin/eGTouchD." >&2; exit 1; }
[[ -x /usr/bin/eCalib || -L /usr/bin/eCalib ]] || { echo "CHYBA: instalace nevytvořila /usr/bin/eCalib; nebyla zvolena withX varianta." >&2; exit 1; }
systemctl enable eGTouchD.service >/dev/null 2>&1 || true

echo
cat <<'DONE'
EETI eGTouch byl nainstalován.
Po restartu spustí příkaz „kalibrace“ pro eGalax oficiální eCalib.
Pro správné převzetí dotyku ovladačem je nyní nutný reboot.
DONE

echo
if [[ "$AUTO_REBOOT" -eq 1 ]]; then
  echo "Restartuji zařízení za 5 sekund..."
  sleep 5
  reboot
else
  echo "Reboot odložen volbou --no-reboot."
fi
