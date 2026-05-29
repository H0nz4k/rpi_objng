#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Spusť přes sudo: sudo teamviewer-updates-on" >&2; exit 1; }
HELD="$(apt-mark showhold | grep -E '^teamviewer(:|$)' || true)"; [[ -n "$HELD" ]] || { echo "TeamViewer není v APT hold stavu."; exit 0; }
# shellcheck disable=SC2086
apt-mark unhold $HELD; echo "APT aktualizace TeamVieweru jsou opět povolené."
