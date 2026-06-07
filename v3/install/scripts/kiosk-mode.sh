#!/usr/bin/env bash
# Samostatné přepnutí čistého kiosk desktopu; nespouští automaticky aplikaci.
set -Eeuo pipefail
[[ "$EUID" -ne 0 ]] || { echo "Spusť jako běžný uživatel, bez sudo." >&2; exit 1; }
case "${1:-status}" in
  on|clean|enable) sudo /usr/local/sbin/objednavka-kiosk-system-mode clean ;;
  off|desktop|disable) sudo /usr/local/sbin/objednavka-kiosk-system-mode desktop ;;
  status)
    if grep -Eq '^[[:space:]]*#[[:space:]]*/usr/bin/lwrespawn /usr/bin/(pcmanfm-pi|wf-panel-pi)' /etc/xdg/labwc/autostart 2>/dev/null; then
      echo "Kiosk_mode: ZAPNUTÝ (plocha skrytá)"
    else
      echo "Kiosk_mode: VYPNUTÝ (plocha zobrazená)"
    fi
    ;;
  *) echo "Použití: kiosk-mode {on|off|status}" >&2; exit 1 ;;
esac
