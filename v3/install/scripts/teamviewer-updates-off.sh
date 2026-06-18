#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Spusť přes sudo: sudo teamviewer-updates-off" >&2; exit 1; }
PKG="$(dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | grep -E '^teamviewer(-host)?(:|$)' | head -1 | cut -d: -f1 || true)"
[[ -n "$PKG" ]] || { echo "Nainstalovaný TeamViewer balíček nebyl nalezen." >&2; exit 1; }
apt-mark hold "$PKG"; echo "APT aktualizace balíčku '$PKG' jsou zablokované."
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Spusť přes sudo: sudo teamviewer-updates-off" >&2; exit 1; }
PKG="$(dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | grep -E '^teamviewer(-host)?(:|$)' | head -1 | cut -d: -f1 || true)"
[[ -n "$PKG" ]] || { echo "Nainstalovaný TeamViewer balíček nebyl nalezen." >&2; exit 1; }
apt-mark hold "$PKG"; echo "APT aktualizace balíčku '$PKG' jsou zablokované."
