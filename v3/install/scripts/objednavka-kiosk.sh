#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q set -Eeuo pipefail
APP="/opt/objednavka-ng/objednavka-ng.AppImage"
AUTO="${HOME}/.config/labwc/autostart"
SYSTEM_AUTO="/etc/xdg/labwc/autostart"
case "${1:-status}" in
    on) shift; exec kiosk-on "$@" ;;
    off) shift; exec kiosk-off "$@" ;;
    gui-on) exec gui-on ;;
    gui-off) exec gui-off ;;
    start-now) exec /opt/objednavka-ng/scripts/kiosk-run.sh ;;
    calibration|kalibrace) exec kalibrace ;;
    status)
        if [[ -f "$AUTO" ]] && grep -Fq '# >>> OBJEDNAVKA-NG-KIOSK >>>' "$AUTO"; then
            echo "Autostart aplikace: ZAPNUTÝ"
        else
            echo "Autostart aplikace: VYPNUTÝ"
        fi
        if grep -Eq '^[[:space:]]*#[[:space:]]*/usr/bin/lwrespawn /usr/bin/(pcmanfm-pi|wf-panel-pi)' "$SYSTEM_AUTO" 2>/dev/null; then
            echo "Plocha po startu:  SKRYTÁ (čistý kiosk)"
        else
            echo "Plocha po startu:  ZOBRAZENÁ"
        fi
        if pgrep -u "$(id -u)" -f "$APP" >/dev/null 2>&1; then
            echo "Aplikace nyní:     běží"
        else
            echo "Aplikace nyní:     neběží"
        fi
        ;;
    *)
        echo "Použití: objednavka-kiosk {status|start-now|on [--now]|off [--now]|gui-on|gui-off|kalibrace}"
        echo "Krátké příkazy: gui-on gui-off kalibrace kiosk-on kiosk-off"
        exit 1
        ;;
esac
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
set -Eeuo pipefail
APP="/opt/objednavka-ng/objednavka-ng.AppImage"
AUTO="${HOME}/.config/labwc/autostart"
SYSTEM_AUTO="/etc/xdg/labwc/autostart"
case "${1:-status}" in
    on) shift; exec kiosk-on "$@" ;;
    off) shift; exec kiosk-off "$@" ;;
    gui-on) exec gui-on ;;
    gui-off) exec gui-off ;;
    start-now) exec /opt/objednavka-ng/scripts/kiosk-run.sh ;;
    calibration|kalibrace) exec kalibrace ;;
    status)
        if [[ -f "$AUTO" ]] && grep -Fq '# >>> OBJEDNAVKA-NG-KIOSK >>>' "$AUTO"; then
            echo "Autostart aplikace: ZAPNUTÝ"
        else
            echo "Autostart aplikace: VYPNUTÝ"
        fi
        if grep -Eq '^[[:space:]]*#[[:space:]]*/usr/bin/lwrespawn /usr/bin/(pcmanfm-pi|wf-panel-pi)' "$SYSTEM_AUTO" 2>/dev/null; then
            echo "Plocha po startu:  SKRYTÁ (čistý kiosk)"
        else
            echo "Plocha po startu:  ZOBRAZENÁ"
        fi
        if pgrep -u "$(id -u)" -f "$APP" >/dev/null 2>&1; then
            echo "Aplikace nyní:     běží"
        else
            echo "Aplikace nyní:     neběží"
        fi
        ;;
    *)
        echo "Použití: objednavka-kiosk {status|start-now|on [--now]|off [--now]|gui-on|gui-off|kalibrace}"
        echo "Krátké příkazy: gui-on gui-off kalibrace kiosk-on kiosk-off"
        exit 1
        ;;
esac
