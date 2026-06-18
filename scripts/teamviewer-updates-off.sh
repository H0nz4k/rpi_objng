#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Spusť přes sudo: sudo teamviewer-updates-off" >&2; exit 1; }
PKG="$(dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | grep -E '^teamviewer(-host)?(:|$)' | head -1 | cut -d: -f1 || true)"
[[ -n "$PKG" ]] || { echo "Nainstalovaný TeamViewer balíček nebyl nalezen." >&2; exit 1; }
apt-mark hold "$PKG"; echo "APT aktualizace balíčku '$PKG' jsou zablokované."
