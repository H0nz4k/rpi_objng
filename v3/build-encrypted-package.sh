#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$ROOT/install"
OUT="${1:-$ROOT/rpibox_install.7z}"
PASSWORD="${PACKAGE_PASSWORD:-}"

if [[ -z "$PASSWORD" ]]; then
  read -r -s -p "Heslo pro rpibox_install.7z: " PASSWORD
  echo
fi

[[ -n "$PASSWORD" ]] || { echo "CHYBA: heslo nesmi byt prazdne." >&2; exit 1; }
[[ -f "$INSTALL_DIR/install.sh" ]] || { echo "CHYBA: chybi $INSTALL_DIR/install.sh" >&2; exit 1; }
command -v 7z >/dev/null 2>&1 || { echo "CHYBA: chybi 7z. Nainstaluj p7zip-full / 7-Zip." >&2; exit 1; }

rm -f "$OUT"

(
  cd "$INSTALL_DIR"
  7z a -t7z -mx=9 -mhe=on "-p$PASSWORD" "$OUT" ./*
)

echo
echo "Hotovo:"
ls -lh "$OUT"
echo
echo "Nahraj na CDN jako:"
echo "  https://cdn.public.altisima.cz/rpibox_install.7z"
