#!/usr/bin/env bash
# ObjednavkaNG master IMG bootstrap: instalace EETI driveru pro eGalax 0eef:0001 v0.9.1
# Skript MUSI overit, ze vzniklo /usr/bin/eCalib, /usr/bin/eGTouchD a /etc/eGTouchL.ini.
set -Eeuo pipefail

VERSION="2.1.6"
EETI_ARCHIVE_NAME="eGTouch_v2.5.13219.L-ma.7z"
LOCAL_ARCHIVES=(
  "/home/objng/bootstrap/v2/payload/drivers/${EETI_ARCHIVE_NAME}"
  "/home/objng/bootstrap/drivers/${EETI_ARCHIVE_NAME}"
  "/home/objng/firstboot/${EETI_ARCHIVE_NAME}"
  "/home/objng/bin/${EETI_ARCHIVE_NAME}"
)
DOWNLOAD_URL="https://www.eeti.com/touch_driver/Linux/20240510/${EETI_ARCHIVE_NAME}"
WORKDIR="/tmp/objng-egtouch-install"
LOG="/home/objng/objng_egtouch_install.log"
ACCEPT_LICENSE=0

usage() {
  cat <<USAGE
Pouziti:
  sudo install-egalax-eeti-bootstrap.sh --accept-license

Instaluje oficialni EETI eGTouch driver pro eGalax 0eef:0001.
Primarne pouzije lokalni archiv:
  /home/objng/bootstrap/v2/payload/drivers/${EETI_ARCHIVE_NAME}
Pokud neni dostupny, pokusi se stahnout:
  ${DOWNLOAD_URL}
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --accept-license) ACCEPT_LICENSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Neznama volba: $1" >&2; usage; exit 1 ;;
  esac
done

[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo." >&2; exit 1; }
[[ "$ACCEPT_LICENSE" -eq 1 ]] || { echo "CHYBA: chybi --accept-license." >&2; exit 1; }

exec > >(tee -a "$LOG") 2>&1

echo "============================================================"
echo " EETI eGalax installer bootstrap v$VERSION"
echo "============================================================"
echo "Cas: $(date)"
echo

verify_install() {
  local ok=0
  [[ -x /usr/bin/eCalib ]] || ok=1
  [[ -x /usr/bin/eGTouchD ]] || ok=1
  [[ -f /etc/eGTouchL.ini ]] || ok=1
  if [[ "$ok" -eq 0 ]]; then
    echo "EETI instalace OVERENA:"
    ls -l /usr/bin/eGTouchD /usr/bin/eCalib /etc/eGTouchL.ini
    return 0
  fi
  echo "EETI instalace zatim neni overena. Aktualni stav:"
  ls -l /usr/bin/eGTouchD /usr/bin/eCalib /etc/eGTouchL.ini 2>/dev/null || true
  return 1
}

if verify_install; then
  systemctl enable --now eGTouchD.service 2>/dev/null || true
  exit 0
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y p7zip-full wget usbutils

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

ARCHIVE=""
for candidate in "${LOCAL_ARCHIVES[@]}"; do
  if [[ -s "$candidate" ]]; then
    ARCHIVE="$candidate"
    break
  fi
done

if [[ -n "$ARCHIVE" ]]; then
  echo "Pouzivam lokalni EETI archiv: $ARCHIVE"
  cp -a "$ARCHIVE" "$WORKDIR/$EETI_ARCHIVE_NAME"
else
  echo "Lokalni EETI archiv nebyl nalezen. Stahuji z EETI:"
  echo "  $DOWNLOAD_URL"
  wget -O "$WORKDIR/$EETI_ARCHIVE_NAME" "$DOWNLOAD_URL"
fi

echo
echo "Rozbaluji EETI archiv..."
7z x "$WORKDIR/$EETI_ARCHIVE_NAME"

SETUP_SH="$(find "$WORKDIR" -type f -name setup.sh | head -1 || true)"
if [[ -z "$SETUP_SH" ]]; then
  echo "CHYBA: V archivu nebyl nalezen setup.sh."
  exit 1
fi
chmod +x "$SETUP_SH"
SETUP_DIR="$(dirname "$SETUP_SH")"

run_official_setup_attempt() {
  local answers="$1"
  local label="$2"
  echo
  echo "------------------------------------------------------------"
  echo " Spoustim oficialni EETI setup: $label"
  echo "------------------------------------------------------------"
  echo
  cd "$SETUP_DIR"
  set +e
  printf '%b' "$answers" | bash ./setup.sh
  local rc=$?
  set -e
  echo "EETI setup rc=$rc"
  verify_install
}

# Prvni pokus odpovida predchozimu uspesnemu rucnimu testu na RPi OS arm64:
# y = souhlas, 2 = USB, Enter = potvrzeni touch, n = bez specialni rotace, y = blacklist, 1 = jeden controller.
if run_official_setup_attempt 'y\n2\n\nn\ny\n1\n' 'standard USB/aarch64 odpovedi'; then
  systemctl daemon-reload || true
  systemctl enable --now eGTouchD.service 2>/dev/null || true
  verify_install
  exit 0
fi

# Druhy pokus: nektere verze setupu berou prvni ciselny vyber jinak.
if run_official_setup_attempt 'y\n1\n\ny\n1\n' 'alternativni kratke odpovedi'; then
  systemctl daemon-reload || true
  systemctl enable --now eGTouchD.service 2>/dev/null || true
  verify_install
  exit 0
fi

manual_fallback() {
  echo
  echo "------------------------------------------------------------"
  echo " Manual fallback: hledam eCalib/eGTouchD v rozbalenem baliku"
  echo "------------------------------------------------------------"
  echo

  local ecalib egtouch bin_dir ini
  ecalib="$(find "$WORKDIR" -type f -name eCalib | grep -Ei 'aarch64|arm64|withx|linux' | head -1 || true)"
  [[ -n "$ecalib" ]] || ecalib="$(find "$WORKDIR" -type f -name eCalib | head -1 || true)"
  [[ -n "$ecalib" ]] || { echo "Manual fallback: eCalib nenalezen."; return 1; }

  bin_dir="$(dirname "$ecalib")"
  egtouch="$bin_dir/eGTouchD"
  [[ -x "$egtouch" || -f "$egtouch" ]] || egtouch="$(find "$WORKDIR" -type f -name eGTouchD | grep -Ei 'aarch64|arm64|withx|linux' | head -1 || true)"
  [[ -n "$egtouch" ]] || { echo "Manual fallback: eGTouchD nenalezen."; return 1; }

  echo "Pouzivam binarni adresar: $bin_dir"
  echo "eCalib: $ecalib"
  echo "eGTouchD: $egtouch"

  install -m 0755 "$ecalib" /usr/bin/eCalib
  install -m 0755 "$egtouch" /usr/bin/eGTouchD

  ini="$(find "$WORKDIR" -type f -name eGTouchL.ini | head -1 || true)"
  if [[ -n "$ini" ]]; then
    install -m 0644 "$ini" /etc/eGTouchL.ini
  elif [[ ! -f /etc/eGTouchL.ini ]]; then
    cat > /etc/eGTouchL.ini <<'INIEOF'
[Controller]
DeviceType		1
Interface		0
UseDriverCalib		0
Direction		0
Orientation		0
MonitorName		null
DetectRotation		0
INIEOF
  fi

  cat > /etc/systemd/system/eGTouchD.service <<'SERVICEEOF'
[Unit]
Description=EETI eGTouchD touchscreen daemon
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/eGTouchD
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
SERVICEEOF

  cat > /etc/modprobe.d/99-objng-egalax-blacklist.conf <<'BLEOF'
# ObjednavkaNG/eGalax: EETI driver pouziva vlastni daemon, proto blokujeme kernel usbtouchscreen.
blacklist usbtouchscreen
BLEOF

  systemctl daemon-reload || true
  systemctl enable --now eGTouchD.service || true

  verify_install
}

if manual_fallback; then
  echo
  echo "Manual fallback probehl. Doporucen reboot."
  exit 0
fi

echo
echo "CHYBA: EETI driver se nepodarilo nainstalovat ani overit."
echo "Log: $LOG"
echo "Diagnostika:"
find "$WORKDIR" -maxdepth 4 -type f \( -name eCalib -o -name eGTouchD -o -name eGTouchL.ini -o -name setup.sh \) -print || true
exit 1
