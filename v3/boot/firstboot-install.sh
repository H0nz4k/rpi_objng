#!/usr/bin/env bash

set -u

# ============================================================
# ObjednavkaNG - staged bootstrap z pripraveneho IMG
#
# Tento skript patri primo do IMG. Nejdriv vyresi veci, ktere
# davaji smysl udelat lokalne na zarizeni: IP, TeamViewer a touch.
# Az potom stahne hlavni instalacni balik z CDN a spusti install.sh.
# ============================================================

USER_NAME="${OBJNG_USER:-objng}"
USER_HOME="/home/$USER_NAME"
FIRSTBOOT_DIR="$USER_HOME/firstboot"
FIRSTBOOT_CONFIG="$FIRSTBOOT_DIR/firstboot.conf"
FIRSTBOOT_SCRIPT="$FIRSTBOOT_DIR/firstboot-install.sh"
INSTALL_DIR="$USER_HOME/install"
STATE_DIR="$USER_HOME/.local/state/objednavka-ng-firstboot"
STATE_FILE="$STATE_DIR/state"
RETRY_FILE="$STATE_DIR/retry-count"
LOG_FILE="$USER_HOME/objng_firstboot_install.log"
LABWC_AUTOSTART="$USER_HOME/.config/labwc/autostart"
XDG_AUTOSTART_DIR="$USER_HOME/.config/autostart"
XDG_AUTOSTART_FILE="$XDG_AUTOSTART_DIR/objng-firstboot.desktop"

PACKAGE_URL="${PACKAGE_URL:-https://cdn.public.altisima.cz/rpibox_install.7z}"
PACKAGE_FILE="$INSTALL_DIR/rpibox_install.7z"
PACKAGE_PASSWORD="${PACKAGE_PASSWORD:-OBJNG_RPIBOX_V3_ZMENIT_HESLO}"

TEAMVIEWER_DEB="$FIRSTBOOT_DIR/teamviewer.deb"
TOUCH_CALIBRATOR="$FIRSTBOOT_DIR/touch_calibrator_v3.py"
EETI_ARCHIVE_NAME="eGTouch_v2.5.13219.L-ma.7z"
EETI_ARCHIVE="$FIRSTBOOT_DIR/$EETI_ARCHIVE_NAME"
EETI_OFFICIAL_URL="https://www.eeti.com/touch_driver/Linux/20240510/$EETI_ARCHIVE_NAME"
TEAMVIEWER_ASSIGNMENT_ID='0001CoABChAn1DcQW0sR8ZRIokz3ZXSFEigIACAAAgAJABmtfJEnMj-Y7lbBshn0p-zoVNn2uea2GX_P6hZVOtXTGkBvtgCUKyHP8fsNMR7EM2iniBRxWb1yvECzdGpsFCp3zBDoh2HqNGcQaNpwq_q3BRo4I4QmjXOl1E_bAfP9cyvZIAEQvdqepQU='

MARKER_DONE="$STATE_DIR/done"
AUTO_CONTINUE_SECONDS="${AUTO_CONTINUE_SECONDS:-20}"
FIRSTBOOT_RETRY_SECONDS="${FIRSTBOOT_RETRY_SECONDS:-20}"
FIRSTBOOT_MAX_STEP_RETRIES="${FIRSTBOOT_MAX_STEP_RETRIES:-3}"
TEAMVIEWER_ALIAS_SUFFIX="${TEAMVIEWER_ALIAS_SUFFIX:-}"
TEAMVIEWER_PASSWORD="${TEAMVIEWER_PASSWORD:-}"
TEAMVIEWER_REASSIGN="${TEAMVIEWER_REASSIGN:-0}"

mkdir -p "$STATE_DIR"

# Vypisujeme zaroven do terminalu i do logu.
exec > >(tee -a "$LOG_FILE") 2>&1

if [ -f "$FIRSTBOOT_CONFIG" ]; then
    # shellcheck disable=SC1090
    . "$FIRSTBOOT_CONFIG"
fi

set_state() {
    printf '%s\n' "$1" > "$STATE_FILE"
}

get_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "preflight"
    fi
}

fail_and_retry() {
    current_state="$(get_state)"
    retry_count=0
    if [ -f "$RETRY_FILE" ]; then
        retry_count="$(cat "$RETRY_FILE" 2>/dev/null || echo 0)"
    fi
    retry_count=$((retry_count + 1))
    printf '%s\n' "$retry_count" > "$RETRY_FILE"

    echo
    echo "============================================================"
    echo " CHYBA: $1"
    echo "============================================================"
    echo
    echo "Stav: $current_state"
    echo "Pokus ve stavu: $retry_count"
    echo "Log: $LOG_FILE"
    echo

    if [ "$current_state" != "download_main" ] && [ "$retry_count" -ge "$FIRSTBOOT_MAX_STEP_RETRIES" ]; then
        echo "Volitelna predpriprava opakovane selhala."
        echo "Aby zarizeni nezustalo zaseknute, pokracuji po rebootu stazenim hlavniho baliku."
        set_state "download_main"
        printf '%s\n' 0 > "$RETRY_FILE"
    else
        echo "Po rebootu se firstboot spusti znovu a bude pokracovat."
    fi

    echo
    echo "Restartuji za ${FIRSTBOOT_RETRY_SECONDS} s..."
    sleep "$FIRSTBOOT_RETRY_SECONDS"
    sudo reboot || reboot || true
    exit 1
}

clear_retry_count() {
    printf '%s\n' 0 > "$RETRY_FILE"
}

warn_continue() {
    echo
    echo "VAROVANI: $1"
    echo "Pokracuji dal, aby se zarizeni nezaseklo pred stazenim hlavniho baliku."
}

ensure_firstboot_autostart() {
    script="$FIRSTBOOT_SCRIPT"
    if [ ! -f "$script" ]; then
        script="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
    fi

    mkdir -p "$(dirname "$LABWC_AUTOSTART")" "$XDG_AUTOSTART_DIR"

    if [ -f "$LABWC_AUTOSTART" ]; then
        python3 - "$LABWC_AUTOSTART" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
t = p.read_text(encoding="utf-8", errors="replace")
t = re.sub(r"\n?# >>> OBJNG-IMG-FIRSTBOOT >>>.*?# <<< OBJNG-IMG-FIRSTBOOT <<<\n?", "\n", t, flags=re.S)
p.write_text(t.lstrip("\n"), encoding="utf-8")
PY
    fi

    cat >> "$LABWC_AUTOSTART" <<EOF

# >>> OBJNG-IMG-FIRSTBOOT >>>
if [ ! -f "$MARKER_DONE" ]; then
  lxterminal --title="ObjednavkaNG firstboot" -e bash "$script" &
fi
# <<< OBJNG-IMG-FIRSTBOOT <<<
EOF

    cat > "$XDG_AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=ObjednavkaNG firstboot
Exec=lxterminal --title="ObjednavkaNG firstboot" -e bash "$script"
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
}

cleanup_firstboot_autostart() {
    if [ -f "$LABWC_AUTOSTART" ]; then
        python3 - "$LABWC_AUTOSTART" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
t = p.read_text(encoding="utf-8", errors="replace")
t = re.sub(r"\n?# >>> OBJNG-IMG-FIRSTBOOT >>>.*?# <<< OBJNG-IMG-FIRSTBOOT <<<\n?", "\n", t, flags=re.S)
p.write_text(t.lstrip("\n"), encoding="utf-8")
PY
    fi
    rm -f "$XDG_AUTOSTART_FILE"
}

ask_yes() {
    if [ "${OBJNG_INTERACTIVE:-0}" != "1" ]; then
        return 0
    fi
    prompt="$1"
    default="${2:-A}"
    read -r -p "$prompt" answer
    answer="${answer:-$default}"
    case "$answer" in
        A|a|Y|y|ano|Ano|ANO|yes|Yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

install_if_available() {
    pkg="$1"
    if apt-cache show "$pkg" >/dev/null 2>&1; then
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" || true
    fi
}

start_on_screen_keyboard() {
    if pgrep -f 'wvkbd|onboard|matchbox-keyboard|florence' >/dev/null 2>&1; then
        return 0
    fi

    if command -v wvkbd-mobintl >/dev/null 2>&1; then
        DISPLAY="${DISPLAY:-:0}" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" wvkbd-mobintl >/dev/null 2>&1 &
    elif command -v wvkbd >/dev/null 2>&1; then
        DISPLAY="${DISPLAY:-:0}" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" wvkbd >/dev/null 2>&1 &
    elif command -v onboard >/dev/null 2>&1; then
        DISPLAY="${DISPLAY:-:0}" onboard >/dev/null 2>&1 &
    elif command -v matchbox-keyboard >/dev/null 2>&1; then
        DISPLAY="${DISPLAY:-:0}" matchbox-keyboard >/dev/null 2>&1 &
    elif command -v florence >/dev/null 2>&1; then
        DISPLAY="${DISPLAY:-:0}" florence >/dev/null 2>&1 &
    fi
}

show_ip_addresses() {
    echo "IP adresy zarizeni:"
    echo

    ipv4_output="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print "  " $2 ": " $4}')"

    if [ -n "$ipv4_output" ]; then
        echo "$ipv4_output"
    else
        echo "  Zatim nebyla nalezena zadna platna IPv4 adresa."
        echo "  Zkontroluj LAN kabel nebo Wi-Fi pripojeni."
    fi
}

wait_for_operator() {
    while true; do
        clear
        echo "============================================================"
        echo " ObjednavkaNG - prvni spusteni IMG"
        echo "============================================================"
        echo
        show_ip_addresses
        echo
        echo "Moznosti:"
        echo
        echo "  [Z] Znovu nacist IP adresu"
        echo "  [P] Pokracovat hned"
        echo
        echo "Bez volby pokracuji automaticky za ${AUTO_CONTINUE_SECONDS} s."
        echo
        if ! read -r -t "$AUTO_CONTINUE_SECONDS" -p "Vyber moznost [Z/P]: " choice; then
            choice="P"
        fi

        case "${choice^^}" in
            Z) sleep 1 ;;
            P) break ;;
            *)
                echo
                echo "Neplatna volba. Pouzij Z nebo P."
                sleep 2
                ;;
        esac
    done
}

install_base_tools() {
    echo
    echo "Instaluji minimalni nastroje pro firstboot fazi..."
    if ! sudo apt-get update; then
        warn_continue "apt-get update selhal."
    fi
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates wget p7zip-full usbutils python3-evdev python3-tk libinput-tools lxterminal; then
        warn_continue "Instalace firstboot nastroju selhala."
    fi
    install_if_available wvkbd
    install_if_available onboard
}

normalize_suffix() {
    printf '%s' "$1" | tr -cs '[:alnum:]_.-' '-' | sed -E 's/^-+//; s/-+$//'
}

set_teamviewer_local_options() {
    conf="/opt/teamviewer/config/global.conf"
    backup_dir="/opt/objednavka-ng/backups/teamviewer"
    [ -f "$conf" ] || return 0
    sudo mkdir -p "$backup_dir"
    sudo cp -a "$conf" "$backup_dir/global.conf.before-firstboot.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    sudo systemctl stop teamviewerd 2>/dev/null || true
    sudo python3 - "$conf" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text(errors="replace")
values = [
    (r'^\[strng\]\s+LastSelectedLanguage\s*=.*$', '[strng] LastSelectedLanguage = "cs"'),
    (r'^\[int32\]\s+General_DirectLAN\s*=.*$', '[int32] General_DirectLAN = 1'),
]
for pattern, line in values:
    if re.search(pattern, s, flags=re.M):
        s = re.sub(pattern, line, s, flags=re.M)
    else:
        s = s.rstrip() + "\n" + line + "\n"
p.write_text(s)
PY
    sudo systemctl start teamviewerd 2>/dev/null || true
    echo "TeamViewer: nastaven jazyk cestina a LAN rezim."
}

hold_teamviewer_updates() {
    pkg="$(dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | grep -E '^teamviewer(:|$)' | head -1 | cut -d: -f1 || true)"
    if [ -n "$pkg" ]; then
        sudo apt-mark hold "$pkg" || true
        echo "TeamViewer: aktualizace balicku '$pkg' jsou zakazane."
    fi
}

configure_teamviewer() {
    command -v teamviewer >/dev/null 2>&1 || return 0

    sudo systemctl enable --now teamviewerd 2>/dev/null || true
    teamviewer info 2>/dev/null || true

    echo
    tv_extra="$TEAMVIEWER_ALIAS_SUFFIX"
    if [ -z "$tv_extra" ] && [ "${OBJNG_INTERACTIVE:-0}" = "1" ]; then
        start_on_screen_keyboard
        read -r -t 60 -p "Volitelny doplnek nazvu za RPIBOX: " tv_extra || tv_extra=""
    fi
    tv_extra="$(normalize_suffix "$tv_extra")"
    if [ -n "$tv_extra" ]; then
        tv_alias="RPIBOX-$tv_extra"
    else
        tv_alias="RPIBOX"
    fi
    echo "TeamViewer nazev zarizeni: $tv_alias"

    tv_pass="$TEAMVIEWER_PASSWORD"
    if [ -z "$tv_pass" ] && [ "${OBJNG_INTERACTIVE:-0}" = "1" ]; then
        echo
        echo "Volitelne TeamViewer heslo. Prazdne pole = preskocit."
        start_on_screen_keyboard
        read -r -s -t 90 -p "TeamViewer heslo: " tv_pass || tv_pass=""
        echo
    fi
    if [ -n "$tv_pass" ]; then
        sudo teamviewer passwd "$tv_pass" || warn_continue "Nastaveni TeamViewer hesla selhalo."
        unset tv_pass
    else
        echo "TeamViewer heslo nebylo zadano; pokracuji bez zmeny hesla."
    fi

    set_teamviewer_local_options
    hold_teamviewer_updates

    if [ -n "$TEAMVIEWER_ASSIGNMENT_ID" ] && [ "$TEAMVIEWER_ASSIGNMENT_ID" != "SEM_VLOZ_SKUTECNE_ASSIGNMENT_ID" ]; then
        echo
        echo "Prirazuji TeamViewer zarizeni '$tv_alias' do spravy..."
        reassign_arg=()
        if [ "${TEAMVIEWER_REASSIGN:-0}" = "1" ]; then
            reassign_arg+=(--reassign)
        fi
        sudo teamviewer assignment \
            --id "$TEAMVIEWER_ASSIGNMENT_ID" \
            --device_alias "$tv_alias" \
            --offline \
            "${reassign_arg[@]}" \
            || echo "VAROVANI: TeamViewer assignment selhal, lze zopakovat pozdeji."
    fi
}

install_teamviewer_from_img() {
    echo
    echo "============================================================"
    echo " TeamViewer pred hlavni instalaci"
    echo "============================================================"
    echo

    if command -v teamviewer >/dev/null 2>&1; then
        echo "TeamViewer uz je nainstalovany."
        sudo systemctl enable --now teamviewerd 2>/dev/null || true
        configure_teamviewer
        return 0
    fi

    if [ ! -s "$TEAMVIEWER_DEB" ]; then
        echo "V IMG neni lokalni TeamViewer balik:"
        echo "  $TEAMVIEWER_DEB"
        echo
        echo "Tento krok preskakuji. Hlavni instalacni balik jej muze doinstalovat pozdeji."
        return 0
    fi

    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$TEAMVIEWER_DEB"; then
        warn_continue "Instalace TeamVieweru selhala."
        return 0
    fi
    sudo systemctl enable --now teamviewerd 2>/dev/null || true
    echo "TeamViewer je nainstalovany."
    configure_teamviewer
}

install_eeti_driver() {
    sudo mkdir -p /opt/objednavka-ng/vendor/eeti

    if ! command -v eCalib >/dev/null 2>&1; then
        if [ -s "$EETI_ARCHIVE" ]; then
            echo "Pouzivam EETI archiv z IMG:"
            echo "  $EETI_ARCHIVE"
            sudo cp -f "$EETI_ARCHIVE" "/opt/objednavka-ng/vendor/eeti/$EETI_ARCHIVE_NAME"
        else
            echo "EETI archiv neni v IMG, stahuji oficialni balik:"
            echo "  $EETI_OFFICIAL_URL"
            if ! sudo wget -O "/opt/objednavka-ng/vendor/eeti/$EETI_ARCHIVE_NAME" "$EETI_OFFICIAL_URL"; then
                warn_continue "Stazeni EETI driveru selhalo."
                return 1
            fi
        fi

        work="/opt/objednavka-ng/vendor/eeti/extracted"
        sudo rm -rf "$work"
        sudo mkdir -p "$work"
        if ! sudo 7z x -y "/opt/objednavka-ng/vendor/eeti/$EETI_ARCHIVE_NAME" -o"$work" >/dev/null; then
            warn_continue "Rozbaleni EETI driveru selhalo."
            return 1
        fi

        setup="$(find "$work" -type f -name setup.sh -print -quit)"
        if [ -z "$setup" ]; then
            warn_continue "V EETI archivu nebyl nalezen setup.sh."
            return 1
        fi
        sudo chmod +x "$setup"

        echo "Instaluji EETI AARCH64 withX pro eGalax."
        if ! printf 'y\n2\n\nn\ny\n1\n' | sudo bash "$setup"; then
            warn_continue "Instalace EETI driveru selhala."
            return 1
        fi
        sudo systemctl enable eGTouchD.service >/dev/null 2>&1 || true
    fi

    echo
    echo "EETI driver je pripraveny. Pro spravne prevzeti dotyku je nutny reboot."
    set_state "touch_after_eeti_reboot"
    sudo reboot || reboot || true
    exit 0
}

run_touch_preparation() {
    echo
    echo "============================================================"
    echo " Touch pred hlavni instalaci"
    echo "============================================================"
    echo

    has_egalax=0
    has_3m=0
    lsusb 2>/dev/null | grep -qi '0eef:0001' && has_egalax=1 || true
    lsusb 2>/dev/null | grep -qi '0596:0001' && has_3m=1 || true

    if [ "$has_egalax" -eq 1 ] && [ "$has_3m" -eq 1 ]; then
        warn_continue "Je pripojen eGalax i 3M touch. Kalibraci preskakuji."
        return 0
    fi

    if [ "$has_egalax" -eq 1 ]; then
        echo "Nalezen eGalax USB touchscreen 0eef:0001."
        if ! command -v eCalib >/dev/null 2>&1; then
            install_eeti_driver || warn_continue "EETI priprava selhala."
            return 0
        fi

        echo "Spoustim oficialni eGalax kalibraci."
        if ! sudo env DISPLAY="${DISPLAY:-:0}" XAUTHORITY="${XAUTHORITY:-$USER_HOME/.Xauthority}" /usr/bin/eCalib; then
            warn_continue "eGalax kalibrace selhala."
            return 0
        fi
        echo "eGalax kalibrace dokoncena. Pro spolehlive nacteni je nutny reboot."
        set_state "download_main"
        sudo reboot || reboot || true
        exit 0
        return 0
    fi

    if [ "$has_3m" -eq 1 ]; then
        echo "Nalezen 3M USB touchscreen 0596:0001."
        if [ ! -s "$TOUCH_CALIBRATOR" ]; then
            echo "V IMG neni lokalni 3M kalibrator:"
            echo "  $TOUCH_CALIBRATOR"
            echo
            echo "Kalibraci 3M preskakuji. Hlavni balik ji doinstaluje pozdeji."
            return 0
        fi

        if ! sudo -v; then
            warn_continue "Sudo overeni pro 3M kalibraci selhalo."
            return 0
        fi
        if ! DISPLAY="${DISPLAY:-:0}" XAUTHORITY="${XAUTHORITY:-$USER_HOME/.Xauthority}" python3 "$TOUCH_CALIBRATOR"; then
            warn_continue "3M kalibrace selhala."
            return 0
        fi
        echo "3M kalibrace dokoncena. Pro spolehlive nacteni je nutny reboot."
        set_state "download_main"
        sudo reboot || reboot || true
        exit 0
        return 0
    fi

    echo "Nebyl nalezen podporovany touch panel."
    echo "Podporovano: eGalax 0eef:0001 nebo 3M 0596:0001."
}

download_and_run_main_installer() {
    set_state "download_main"
    clear_retry_count
    echo
    echo "============================================================"
    echo " Stazeni hlavniho instalacniho baliku"
    echo "============================================================"
    echo
    echo "Balik:"
    echo "  $PACKAGE_URL"
    echo
    show_ip_addresses
    echo

    package_available=0
    for attempt in $(seq 1 60); do
        if wget --spider -q "$PACKAGE_URL"; then
            package_available=1
            echo "Instalacni balik je dostupny."
            break
        fi

        echo "Balik zatim neni dostupny. Pokus $attempt/60..."
        sleep 5
    done

    [ "$package_available" -eq 1 ] || fail_and_retry "Instalacni balik nebyl dostupny ani po cekani."

    mkdir -p "$INSTALL_DIR" || fail_and_retry "Nelze vytvorit instalacni adresar."
    cd "$INSTALL_DIR" || fail_and_retry "Nelze vstoupit do instalacniho adresare."

    rm -f "$PACKAGE_FILE"
    wget -O "$PACKAGE_FILE" "$PACKAGE_URL" || fail_and_retry "Stazeni instalacniho baliku selhalo."

    find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 \
        ! -name "rpibox_install.7z" \
        -exec rm -rf -- {} +

    extract_dir="$INSTALL_DIR/.extract"
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir" || fail_and_retry "Nelze vytvorit docasny adresar pro rozbaleni."

    7z x -y "-p$PACKAGE_PASSWORD" "$PACKAGE_FILE" "-o$extract_dir" >/dev/null \
        || fail_and_retry "Rozbaleni instalacniho baliku selhalo. Zkontroluj heslo a archiv."

    if [ -f "$extract_dir/install.sh" ]; then
        find "$extract_dir" -mindepth 1 -maxdepth 1 -exec mv -- {} "$INSTALL_DIR"/ \;
    elif [ -f "$extract_dir/install/install.sh" ]; then
        find "$extract_dir/install" -mindepth 1 -maxdepth 1 -exec mv -- {} "$INSTALL_DIR"/ \;
    else
        fail_and_retry "Po rozbaleni nebyl nalezen install.sh."
    fi
    rm -rf "$extract_dir"

    [ -f "$INSTALL_DIR/install.sh" ] || fail_and_retry "Po rozbaleni nebyl nalezen install.sh."

    chmod +x "$INSTALL_DIR/install.sh" 2>/dev/null || true
    chmod +x "$INSTALL_DIR"/scripts/*.sh 2>/dev/null || true
    chmod +x "$INSTALL_DIR"/files/*.AppImage 2>/dev/null || true

    installer_args=()
    if command -v teamviewer >/dev/null 2>&1; then
        installer_args+=(--skip-teamviewer)
    fi

    echo
    echo "Spoustim hlavni instalator ObjednavkaNG."
    if [ "${#installer_args[@]}" -gt 0 ]; then
        echo "Volby: ${installer_args[*]}"
    fi
    echo

    if sudo bash "$INSTALL_DIR/install.sh" "${installer_args[@]}"; then
        clear_retry_count
        touch "$MARKER_DONE"
        set_state "done"
        cleanup_firstboot_autostart
        echo
        echo "============================================================"
        echo " Firstboot instalace byla dokoncena"
        echo "============================================================"
        echo
        echo "Pokud instalator jeste neprovedl restart, spust:"
        echo
        echo "  sudo reboot"
        echo
    else
        fail_and_retry "Hlavni install.sh skoncil chybou."
    fi
}

main() {
    ensure_firstboot_autostart

    if [ -f "$MARKER_DONE" ]; then
        clear
        echo "============================================================"
        echo " ObjednavkaNG - firstboot uz byl dokonceny"
        echo "============================================================"
        echo
        echo "Skript se znovu nespusti."
        cleanup_firstboot_autostart
        sleep 5
        exit 0
    fi

    state="$(get_state)"

    clear
    echo "============================================================"
    echo " ObjednavkaNG - staged firstboot"
    echo "============================================================"
    echo
    echo "Stav: $state"
    echo "Log:  $LOG_FILE"
    echo

    case "$state" in
        preflight)
            wait_for_operator
            set_state "local_prepare"
            install_base_tools
            install_teamviewer_from_img
            run_touch_preparation
            set_state "download_main"
            download_and_run_main_installer
            ;;
        local_prepare)
            install_base_tools
            install_teamviewer_from_img
            run_touch_preparation
            set_state "download_main"
            download_and_run_main_installer
            ;;
        touch_after_eeti_reboot)
            install_base_tools
            run_touch_preparation
            set_state "download_main"
            download_and_run_main_installer
            ;;
        download_main)
            download_and_run_main_installer
            ;;
        done)
            touch "$MARKER_DONE"
            cleanup_firstboot_autostart
            sleep 5
            ;;
        *)
            echo "Neznamy stav: $state"
            echo "Resetuji firstboot stav na preflight a restartuji."
            set_state "preflight"
            sleep 10
            sudo reboot || reboot || true
            exit 1
            ;;
    esac

    sleep 5
}

main "$@"
