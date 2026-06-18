#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Spusť přes sudo: sudo teamviewer-updates-on" >&2; exit 1; }
HELD="$(apt-mark showhold | grep -E '^teamviewer(-host)?(:|$)' || true)"; [[ -n "$HELD" ]] || { echo "TeamViewer není v APT hold stavu."; exit 0; }
# shellcheck disable=SC2086
apt-mark unhold $HELD; echo "APT aktualizace TeamVieweru jsou opět povolené."
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Spusť přes sudo: sudo teamviewer-updates-on" >&2; exit 1; }
HELD="$(apt-mark showhold | grep -E '^teamviewer(-host)?(:|$)' || true)"; [[ -n "$HELD" ]] || { echo "TeamViewer není v APT hold stavu."; exit 0; }
# shellcheck disable=SC2086
apt-mark unhold $HELD; echo "APT aktualizace TeamVieweru jsou opět povolené."
