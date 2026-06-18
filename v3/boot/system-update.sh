#!/usr/bin/env bash
# Complete non-interactive Raspberry Pi OS update for MASTER BOOT FINAL v2.1.7.
set -Eeuo pipefail

[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo." >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
APT_OPTS=(
  -o Dpkg::Options::=--force-confdef
  -o Dpkg::Options::=--force-confold
)

stop_packagekit() {
  systemctl stop packagekit.service 2>/dev/null || true
  systemctl stop packagekit 2>/dev/null || true
  pkill -x packagekitd 2>/dev/null || true
  sleep 1
}

wait_for_apt_lock() {
  local i holder=""
  for i in $(seq 1 90); do
    stop_packagekit
    if ! fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; then
      return 0
    fi
    holder="$(fuser /var/lib/apt/lists/lock 2>/dev/null | tr -s ' ' || true)"
    printf '\r[UPDATE] Cekam na uvolneni apt zamku (%s/90)... holder: %s   ' "$i" "${holder:-packagekitd?}"
    sleep 2
  done
  printf '\n'
  echo "VAROVANI: apt zamyk stale drzen – zkousim apt i tak." >&2
  stop_packagekit
  return 1
}

apt_safe() {
  wait_for_apt_lock || true
  stop_packagekit
  apt-get "${APT_OPTS[@]}" "$@"
}

echo "[UPDATE] Vypinam PackageKit (koliduje s apt)..."
stop_packagekit
systemctl disable --now packagekit.service 2>/dev/null || true

echo "[UPDATE] Dokoncuji pripadne rozpracovane baliky..."
dpkg --configure -a || true
apt_safe -f install -y || true

echo "[UPDATE] Obnovuji seznam baliku..."
if ! apt_safe update; then
  echo "VAROVANI: apt-get update selhal (zamyk nebo sit). Preskakuji zbytek aktualizaci." >&2
  exit 0
fi

echo "[UPDATE] Instaluji vsechny dostupne aktualizace..."
apt_safe full-upgrade -y || {
  echo "VAROVANI: apt full-upgrade selhal. Pokracuji bez dokonceni vsech baliku." >&2
  exit 0
}

echo "[UPDATE] Uklizim nepotrebne baliky a cache..."
apt_safe autoremove --purge -y || true
apt-get clean || true

if [[ -f /var/run/reboot-required ]]; then
  echo "[UPDATE] Aktualizace vyzaduji reboot; MASTER BOOT jej provede na konci."
fi

echo "[UPDATE] Systemove aktualizace byly dokonceny."
