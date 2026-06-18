#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q # Apply an optional public update package without overwriting config.json.
set -Eeuo pipefail

UPDATE_DIR="${1:-}"
[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo." >&2; exit 1; }
[[ -n "$UPDATE_DIR" && -d "$UPDATE_DIR" ]] || { echo "Pouziti: $0 /cesta/k/rozbalenemu/update" >&2; exit 1; }

if [[ -x "$UPDATE_DIR/apply-update.sh" ]]; then
  exec "$UPDATE_DIR/apply-update.sh"
fi

APP_DIR="/opt/objednavka-ng"
mkdir -p "$APP_DIR/scripts" "$APP_DIR/assets"
if [[ -s "$UPDATE_DIR/files/objednavka-ng.AppImage" ]]; then
  install -m 0755 "$UPDATE_DIR/files/objednavka-ng.AppImage" "$APP_DIR/objednavka-ng.AppImage.new"
  mv -f "$APP_DIR/objednavka-ng.AppImage.new" "$APP_DIR/objednavka-ng.AppImage"
fi
if [[ -d "$UPDATE_DIR/scripts" ]]; then
  for f in "$UPDATE_DIR/scripts"/*.sh; do
    [[ -f "$f" ]] || continue
    install -m 0755 "$f" "$APP_DIR/scripts/$(basename "$f")"
  done
fi
if [[ -s "$UPDATE_DIR/files/splash-image.tga" ]]; then
  install -m 0644 "$UPDATE_DIR/files/splash-image.tga" "$APP_DIR/assets/splash-image.tga"
  command -v configure-splash >/dev/null 2>&1 && configure-splash "$APP_DIR/assets/splash-image.tga" || true
fi

echo "Aktualizace byla aplikovana. Uzivatelsky config nebyl prepsan."
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
# Apply an optional public update package without overwriting config.json.
set -Eeuo pipefail

UPDATE_DIR="${1:-}"
[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo." >&2; exit 1; }
[[ -n "$UPDATE_DIR" && -d "$UPDATE_DIR" ]] || { echo "Pouziti: $0 /cesta/k/rozbalenemu/update" >&2; exit 1; }

if [[ -x "$UPDATE_DIR/apply-update.sh" ]]; then
  exec "$UPDATE_DIR/apply-update.sh"
fi

APP_DIR="/opt/objednavka-ng"
mkdir -p "$APP_DIR/scripts" "$APP_DIR/assets"
if [[ -s "$UPDATE_DIR/files/objednavka-ng.AppImage" ]]; then
  install -m 0755 "$UPDATE_DIR/files/objednavka-ng.AppImage" "$APP_DIR/objednavka-ng.AppImage.new"
  mv -f "$APP_DIR/objednavka-ng.AppImage.new" "$APP_DIR/objednavka-ng.AppImage"
fi
if [[ -d "$UPDATE_DIR/scripts" ]]; then
  for f in "$UPDATE_DIR/scripts"/*.sh; do
    [[ -f "$f" ]] || continue
    install -m 0755 "$f" "$APP_DIR/scripts/$(basename "$f")"
  done
fi
if [[ -s "$UPDATE_DIR/files/splash-image.tga" ]]; then
  install -m 0644 "$UPDATE_DIR/files/splash-image.tga" "$APP_DIR/assets/splash-image.tga"
  command -v configure-splash >/dev/null 2>&1 && configure-splash "$APP_DIR/assets/splash-image.tga" || true
fi

echo "Aktualizace byla aplikovana. Uzivatelsky config nebyl prepsan."
