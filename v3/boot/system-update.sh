#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q # Complete non-interactive Raspberry Pi OS update for MASTER BOOT FINAL v2.1.7.
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
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
# Complete non-interactive Raspberry Pi OS update for MASTER BOOT FINAL v2.1.7.
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
