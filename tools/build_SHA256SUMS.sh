#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"; FILES="$ROOT/files"
for f in objednavka-ng.AppImage teamviewer.deb config.json splash-image.tga; do [[ -s "$FILES/$f" ]] || { echo "Chybí lokální instalační soubor: files/$f" >&2; exit 1; }; done
(cd "$FILES" && sha256sum config.json splash-image.tga objednavka-ng.AppImage teamviewer.deb > SHA256SUMS)
echo "Vytvořeno: $FILES/SHA256SUMS"; cat "$FILES/SHA256SUMS"
