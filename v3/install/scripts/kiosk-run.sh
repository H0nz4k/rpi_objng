#!/usr/bin/env bash
set -Eeuo pipefail
APP="/opt/objednavka-ng/objednavka-ng.AppImage"
APP_DIR="/opt/objednavka-ng"
APP_ID="objednavka-ng"
LOG_DIR="${HOME}/.local/state/objednavka-ng"
LOG="${LOG_DIR}/kiosk-startup.log"

mkdir -p "$LOG_DIR"
printf '\n=== %s start kiosku ===\n' "$(date '+%F %T')" >> "$LOG"

if [[ ! -x "$APP" ]]; then
    echo "$(date '+%F %T') CHYBA: aplikace neexistuje nebo není spustitelná: $APP" >> "$LOG"
    exit 1
fi

if ! pgrep -u "$(id -u)" -f "$APP" >/dev/null 2>&1; then
    ( cd "$APP_DIR"; exec "$APP" >>"$LOG" 2>&1 ) &
fi

for _ in $(seq 1 60); do
    if wlrctl toplevel find "app_id:${APP_ID}" >/dev/null 2>&1; then
        wlrctl toplevel fullscreen "app_id:${APP_ID}" >>"$LOG" 2>&1 || true
        wlrctl toplevel focus "app_id:${APP_ID}" >>"$LOG" 2>&1 || true
        echo "$(date '+%F %T') fullscreen aktivován pro ${APP_ID}" >> "$LOG"
        exit 0
    fi
    sleep 0.5
done

echo "$(date '+%F %T') CHYBA: okno ${APP_ID} nenalezeno do 30 sekund." >> "$LOG"
exit 1
