#!/usr/bin/env bash
# ObjednávkaNG – trvalé zvětšení zobrazení na Wayland/labwc přes kanshi
# Ovlada scale automaticky detekovaneho aktivniho vystupu.
set -Eeuo pipefail

detect_output() {
    if command -v wlr-randr >/dev/null 2>&1; then
        wlr-randr 2>/dev/null | awk '/^[^[:space:]]/{out=$1} /Enabled:[[:space:]]+yes/{print out; exit}'
    fi
}
OUTPUT="${OBJNG_OUTPUT:-$(detect_output)}"
OUTPUT="${OUTPUT:-HDMI-A-1}"
SCALE_BIG="1.25"
SCALE_NORMAL="1.0"
CONFIG_DIR="${HOME}/.config/kanshi"
CONFIG="${CONFIG_DIR}/config"
STATE_DIR="${HOME}/.local/state/objednavka-ng-display"
ORIGINAL_MARK="${STATE_DIR}/original_config_path"
MANAGED_HEADER="# OBJEDNAVKANG-MANAGED-DISPLAY-SCALE"

log() { printf '\n[ZVETSENI] %s\n' "$*"; }

require_user() {
    if [[ "${EUID}" -eq 0 ]]; then
        echo "Tento příkaz spouštěj jako uživatel objng, bez sudo." >&2
        exit 1
    fi
}

backup_original_once() {
    mkdir -p "$CONFIG_DIR" "$STATE_DIR"
    if [[ -f "$ORIGINAL_MARK" ]]; then
        return
    fi

    if [[ -f "$CONFIG" ]]; then
        local original="${STATE_DIR}/kanshi.config.original.$(date +%Y%m%d_%H%M%S)"
        cp -a "$CONFIG" "$original"
        printf '%s\n' "$original" > "$ORIGINAL_MARK"
        log "Původní kanshi konfigurace byla zazálohována: $original"
    else
        printf '%s\n' "__PUVODNE_NEEXISTOVAL__" > "$ORIGINAL_MARK"
        log "Původní kanshi konfigurace neexistovala; stav byl zaznamenán."
    fi
}

backup_before_change() {
    mkdir -p "$STATE_DIR"
    if [[ -f "$CONFIG" ]]; then
        cp -a "$CONFIG" "${STATE_DIR}/kanshi.config.before-change.$(date +%Y%m%d_%H%M%S)"
    fi
}

write_managed_config() {
    local scale="$1"
    backup_original_once
    backup_before_change
    mkdir -p "$CONFIG_DIR"

    cat > "$CONFIG" <<EOF
${MANAGED_HEADER}
# Aktivni vystup je detekovan pri spusteni prikazu
# Nativní rozlišení ponecháváme automaticky dle preferovaného režimu monitoru.
profile objednavka-ng-scale {
    output ${OUTPUT} enable scale ${scale} position 0,0 transform normal
}
EOF
    log "Trvalý profil byl uložen do ${CONFIG}; scale=${scale}."
}

apply_to_current_session() {
    local scale="$1"

    # Běžící kanshi si načte novou konfiguraci.
    pkill -HUP -u "$(id -u)" -x kanshi 2>/dev/null || true

    # V lokálním/TeamViewer terminálu změnu provedeme ihned.
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wlr-randr >/dev/null 2>&1; then
        if wlr-randr --output "$OUTPUT" --scale "$scale"; then
            log "Měřítko bylo aplikováno také ihned v aktuální relaci."
        else
            log "Profil je uložený; okamžitá aplikace selhala. Po rebootu se použije přes kanshi."
        fi
    else
        log "Profil je uložený. Z tohoto terminálu nelze měřítko přepnout ihned; po rebootu se použije přes kanshi."
    fi
}

show_status() {
    log "Uložené nastavení"
    if [[ -f "$CONFIG" ]]; then
        echo "Soubor: $CONFIG"
        sed 's/^/  /' "$CONFIG"
    else
        echo "Soubor $CONFIG neexistuje."
    fi

    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wlr-randr >/dev/null 2>&1; then
        echo
        echo "Aktuální nastavení displeje:"
        wlr-randr | awk -v output="$OUTPUT" '
            $0 ~ "^"output {inside=1}
            inside && /Scale:/ {print "  " $0; exit}
        '
    else
        echo
        echo "Aktuální hodnotu v běžící relaci zobrazíš z terminálu na obrazovce/TeamVieweru:"
        echo "  wlr-randr | grep -A40 "^$OUTPUT" | grep Scale"
    fi
}

restore_original() {
    if [[ ! -f "$ORIGINAL_MARK" ]]; then
        echo "Nebyla nalezena původní záloha; není co obnovovat." >&2
        exit 1
    fi

    backup_before_change
    local original
    original="$(cat "$ORIGINAL_MARK")"

    if [[ "$original" == "__PUVODNE_NEEXISTOVAL__" ]]; then
        rm -f "$CONFIG"
        log "Obnoven původní stav: kanshi config byl odstraněn, protože před instalací neexistoval."
    elif [[ -f "$original" ]]; then
        cp -a "$original" "$CONFIG"
        log "Obnoven původní kanshi config: $original"
    else
        echo "Záložní soubor nebyl nalezen: $original" >&2
        exit 1
    fi

    pkill -HUP -u "$(id -u)" -x kanshi 2>/dev/null || true
    log "Původní konfigurace bude jistě aktivní po novém přihlášení nebo rebootu."
}

require_user

case "$(basename "$0")" in
    zvetseni-on) ACTION="on" ;;
    zvetseni-off) ACTION="off" ;;
    zvetseni-status) ACTION="status" ;;
    zvetseni-restore) ACTION="restore" ;;
    *) ACTION="${1:-status}" ;;
esac

case "$ACTION" in
    on)
        write_managed_config "$SCALE_BIG"
        apply_to_current_session "$SCALE_BIG"
        echo
        echo "Zvětšení 125 % je zapnuté i pro příští start systému."
        ;;
    off)
        write_managed_config "$SCALE_NORMAL"
        apply_to_current_session "$SCALE_NORMAL"
        echo
        echo "Zvětšení je vrácené na 100 % i pro příští start systému."
        ;;
    status)
        show_status
        ;;
    restore)
        restore_original
        ;;
    *)
        echo "Použití: objednavka-zvetseni {on|off|status|restore}" >&2
        echo "Nebo: zvetseni-on | zvetseni-off | zvetseni-status | zvetseni-restore" >&2
        exit 1
        ;;
esac
