#!/usr/bin/env bash
# Complete non-interactive Raspberry Pi OS update for MASTER BOOT FINAL v2.1.6.
set -Eeuo pipefail

[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo." >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
APT_OPTS=(
  -o Dpkg::Options::=--force-confdef
  -o Dpkg::Options::=--force-confold
)

echo "[UPDATE] Dokoncuji pripadne rozpracovane baliky..."
dpkg --configure -a
apt-get "${APT_OPTS[@]}" -f install -y

echo "[UPDATE] Obnovuji seznam baliku..."
apt-get update

echo "[UPDATE] Instaluji vsechny dostupne aktualizace..."
apt-get "${APT_OPTS[@]}" full-upgrade -y

echo "[UPDATE] Uklizim nepotrebne baliky a cache..."
apt-get autoremove --purge -y
apt-get clean

if [[ -f /var/run/reboot-required ]]; then
  echo "[UPDATE] Aktualizace vyzaduji reboot; MASTER BOOT jej provede na konci."
fi

echo "[UPDATE] Systemove aktualizace byly dokonceny."
