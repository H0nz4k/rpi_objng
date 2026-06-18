#!/usr/bin/env bash
# ObjednavkaNG MASTER BOOT FINAL v2.1.7

# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -qP '\r' "$0" 2>/dev/null; then sed -i 's/\r//' "$0"; exec bash "$0" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -Eeuo pipefail

VERSION="2.1.7"
USER_HOME="/home/objng"
STATE="$USER_HOME/.local/state/objng-master-bootstrap"
TOUCH_DONE="$STATE/touch.done"
CAL_PENDING="$STATE/touch.calibration-pending"
CORE_DONE="$STATE/core.done"
CONNECTION_DONE="$STATE/connection.done"
READER_DONE="$STATE/reader.done"
TEAMVIEWER_DONE="$STATE/teamviewer.done"
UPDATE_DONE="$STATE/update.done"
EXPAND_REQUESTED="$STATE/filesystem-expand.requested"
EXPAND_DONE="$STATE/filesystem-expand.done"
SYSTEM_UPDATE_DONE="$STATE/system-update.done"
FINAL_DONE="$STATE/final.done"
LOG="$USER_HOME/objng_firstboot_install.log"
TOUCH_TOOL="$USER_HOME/bin/touch-bootstrap.sh"
TOUCH_TEST="$USER_HOME/bin/touch-test.py"
UPDATE_URL="${OBJNG_UPDATE_URL:-https://cdn.public.altisima.cz/objng_update.tar.gz}"
UPDATE_DIR="$USER_HOME/update"

mkdir -p "$STATE"
exec > >(tee -a "$LOG") 2>&1
exec 9>/tmp/objng-firstboot-install.lock
if ! flock -n 9; then
  echo "Firstboot uz bezi v jinem okne. Tato instance konci."
  exit 0
fi

trap 'rc=$?; echo; echo "CHYBA: MASTER BOOT skoncil na radku $LINENO, kod $rc."; echo "Log: $LOG"; exit $rc' ERR

banner() {
  clear
  echo "============================================================"
  echo " ObjednavkaNG MASTER BOOT v$VERSION"
  echo " $1"
  echo "============================================================"
  echo
}

disable_keyboard() {
  sudo -n raspi-config nonint do_squeekboard S3 2>/dev/null || sudo -n raspi-config nonint do_squeekboard S2 2>/dev/null || true
  gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false >/dev/null 2>&1 || true
  pkill -x squeekboard 2>/dev/null || true
}

enable_keyboard() {
  sudo -n raspi-config nonint do_squeekboard S1 2>/dev/null || true
  gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true >/dev/null 2>&1 || true
  if command -v squeekboard >/dev/null 2>&1 && ! pgrep -x squeekboard >/dev/null 2>&1; then
    squeekboard >/tmp/objng-squeekboard.log 2>&1 &
    sleep 1
  fi
}

reboot_now() {
  sync
  sudo -n /usr/sbin/reboot
  exit 0
}

run_calibration_and_reboot() {
  rm -f "$TOUCH_DONE" "$CAL_PENDING"
  banner "FAZE 1 - automaticka kalibrace touch"
  local rc=0
  # touch-bootstrap vraci 10/20 jako uspech; set -e by to nesmi interpretovat jako chybu.
  "$TOUCH_TOOL" --calibrate || rc=$?
  "$USER_HOME/bin/restore-boot-terminal.sh" 2>/dev/null || true
  clear
  case "$rc" in
    10)
      touch "$CAL_PENDING"
      echo "Kalibrace byla ulozena. Restartuji kvuli nacteni hodnot."
      sleep 2
      reboot_now
      ;;
    20)
      echo "EETI driver byl nainstalovan. Restartuji a pak automaticky spustim eCalib."
      sleep 2
      reboot_now
      ;;
    *)
      echo "CHYBA: automaticka kalibrace selhala, kod $rc."
      echo "Log: $LOG"
      sleep 15
      exit 1
      ;;
  esac
}

touch_phase() {
  disable_keyboard
  if [[ ! -f "$CAL_PENDING" ]]; then
    run_calibration_and_reboot
  fi

  banner "FAZE 2 - fullscreen touch test (overeni kalibrace)"
  # Kalibrace byla ulozena (CAL_PENDING existuje po rebootu).
  # Aplikujeme udev pravidla a rovnou spustime 4-bodovy test.
  # --verify pres udevadm je na labwc/Wayland nespolehlave, test je lepsi overeni.
  sudo -n udevadm control --reload-rules 2>/dev/null || true
  sudo -n udevadm trigger --subsystem-match=input --action=change 2>/dev/null || true
  sleep 2

  echo "Spoustim fullscreen test se 4 body (kliknete do vsech rohů)."
  local test_rc=0
  timeout --signal=TERM --kill-after=5 180 \
    env DISPLAY="${DISPLAY:-:0}" XAUTHORITY="${XAUTHORITY:-$USER_HOME/.Xauthority}" \
    "$USER_HOME/bin/labwc-fullscreen.sh" "ObjednavkaNG - test dotyku" ObjngTouchTest \
    "$TOUCH_TEST" || test_rc=$?

  # labwc-fullscreen obnovi terminal; pro jistotu jeste jednou
  "$USER_HOME/bin/restore-boot-terminal.sh" 2>/dev/null || true
  clear

  if [[ "$test_rc" -eq 0 ]]; then
    rm -f "$CAL_PENDING"
    touch "$TOUCH_DONE"
    sync
    echo "Touch test uspesne dokoncen. Pokracuji instalaci ObjednavkaNG (faze 3)."
    return 0
  fi

  echo "Touch test neprosel nebo se neukoncil (kod $test_rc)."
  echo "Automaticky mazu hodnoty a opakuji kalibraci."
  "$TOUCH_TOOL" --reset || true
  run_calibration_and_reboot
}

show_ip() {
  local out
  out="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print "  " $2 ": " $4}')"
  [[ -n "$out" ]] && echo "$out" || echo "  bez IPv4 adresy"
}

internet_ok() {
  ip -4 route show default 2>/dev/null | grep -q . || return 1
  getent ahostsv4 deb.debian.org >/dev/null 2>&1 || return 1
  wget -qO /dev/null --timeout=8 --tries=1 https://deb.debian.org/debian/README 2>/dev/null || \
  wget -qO /dev/null --timeout=8 --tries=1 https://www.raspberrypi.com/ 2>/dev/null
}

wait_for_internet_or_skip() {
  local skip_after="${1:-30}"
  local purpose="${2:-tento krok}"
  local seconds="$skip_after"
  local key=""

  if internet_ok; then
    return 0
  fi

  banner "FAZE 3 - cekam na internet ($purpose)"
  echo "Bez internetu bude krok preskocen po ${skip_after} s."
  show_ip
  echo

  while (( seconds > 0 )); do
    if internet_ok; then
      printf '\nInternet je dostupny.\n'
      return 0
    fi
    printf '\rCekam na internet... Automaticky preskoceno za %2d s. [X] preskocit: ' "$seconds"
    if IFS= read -r -s -n 1 -t 1 key; then
      printf '\n'
      if [[ "${key^^}" == "X" ]]; then
        echo "Krok preskocen rucne. Pokracuji dalsi fazi."
        return 1
      fi
    fi
    seconds=$((seconds - 1))
  done
  printf '\nInternet neni dostupny. Preskakuji: %s\n' "$purpose"
  return 1
}

install_local_core() {
  [[ -f "$CORE_DONE" ]] && return 0
  banner "FAZE 3 - instaluji lokalni ObjednavkaNG a servisni prikazy"
  sudo -n "$USER_HOME/bin/install-local-core.sh"
  [[ -x /opt/objednavka-ng/objednavka-ng.AppImage ]]
  [[ -L /opt/objednavka-ng/config.json ]]
  touch "$CORE_DONE"
}

configure_connection() {
  [[ -f "$CONNECTION_DONE" ]] && return 0
  banner "FAZE 3 - nastaveni databaze a PCBOX"
  enable_keyboard
  echo "Vypln connection. Enter pouzije nabidnutou vychozi hodnotu."
  nastavit-connection
  touch "$CONNECTION_DONE"
}

configure_reader() {
  [[ -f "$READER_DONE" ]] && return 0
  banner "FAZE 3 - detekce ctecky"
  enable_keyboard
  if nastavit-ctecku; then
    echo "Detekce ctecky dokoncena."
  else
    echo "VAROVANI: ctecka nebyla nalezena nebo nastaveni nebylo dokonceno."
    echo "Pozdeji lze spustit prikaz: nastavit-ctecku"
  fi
  touch "$READER_DONE"
}

teamviewer_deb_exists() {
  find "$USER_HOME/bootstrap/v2/payload/teamviewer" -maxdepth 1 -type f \
    \( -name 'teamviewer*.deb' -o -name 'teamviewer-host*.deb' \) \
    -print -quit 2>/dev/null | grep -q .
}

configure_teamviewer_alias() {
  local alias_file="$USER_HOME/bootstrap/v2/secrets/teamviewer-alias"
  local preset="" loc=""

  if [[ -s "$alias_file" ]]; then
    preset="$(tr -d '\r\n' < "$alias_file")"
    preset="${preset#"${preset%%[![:space:]]*}"}"
    preset="${preset%"${preset##*[![:space:]]}"}"
    if [[ -n "$preset" && "${preset,,}" != "rpibox" ]]; then
      if [[ "$preset" == *","* ]]; then
        export TEAMVIEWER_ALIAS="$preset"
      else
        export TEAMVIEWER_ALIAS="${preset}, RPIbox"
      fi
      echo "TeamViewer nazev z baliku: $TEAMVIEWER_ALIAS"
      return 0
    fi
  fi

  enable_keyboard
  echo
  echo "Zadej nazev lokality (zacatek). Postfix je vzdy ', RPIbox'."
  echo "Priklad: Liberec -> Liberec, RPIbox"
  loc=""
  while [[ -z "$loc" ]]; do
    printf "Lokalita: "
    IFS= read -r loc || loc=""
    loc="${loc#"${loc%%[![:space:]]*}"}"
    loc="${loc%"${loc##*[![:space:]]}"}"
    if [[ -z "$loc" ]]; then
      echo "Zadej prosim nazev lokality (napr. Liberec)."
    fi
  done
  export TEAMVIEWER_ALIAS="${loc}, RPIbox"
  echo "TeamViewer nazev: $TEAMVIEWER_ALIAS"
  mkdir -p "$(dirname "$alias_file")"
  printf '%s\n' "$loc" > "$alias_file" 2>/dev/null || true
  chmod 600 "$alias_file" 2>/dev/null || true
}

install_teamviewer_phase() {
  [[ -f "$TEAMVIEWER_DONE" ]] && return 0

  if ! command -v teamviewer >/dev/null 2>&1 && ! teamviewer_deb_exists; then
    wait_for_internet_or_skip 60 "stazeni TeamVieweru" || {
      echo "VAROVANI: TeamViewer DEB neni v baliku a internet neni dostupny."
      echo "TeamViewer se nainstaluje az pri pristim spusteni s internetem."
      touch "$TEAMVIEWER_DONE"
      return 0
    }
  fi

  banner "FAZE 3 - instalace a nastaveni TeamVieweru"
  set +e
  sudo -n "$USER_HOME/bin/install-teamviewer.sh"
  local tv_rc=$?
  set -e
  if [[ "$tv_rc" -ne 0 ]]; then
    if command -v teamviewer >/dev/null 2>&1 || sudo -n pgrep -x teamviewerd >/dev/null 2>&1; then
      echo "VAROVANI: install-teamviewer skoncil kod $tv_rc, ale TeamViewer bezi – pokracuji."
    else
      echo "VAROVANI: instalace TeamVieweru selhala (kod $tv_rc). Pokracuji firstboot bez TV."
      touch "$TEAMVIEWER_DONE"
      return 0
    fi
  fi

  configure_teamviewer_alias

  sudo -n env TEAMVIEWER_ALIAS="${TEAMVIEWER_ALIAS:-}" "$USER_HOME/bin/teamviewer-postinstall.sh"

  if [[ -s "$USER_HOME/bootstrap/v2/secrets/teamviewer-assignment-id" ]]; then
    if env TEAMVIEWER_ALIAS="${TEAMVIEWER_ALIAS:-}" teamviewer-dokoncit; then
      rm -f "$STATE/teamviewer.assignment-pending"
    else
      echo "VAROVANI: TeamViewer je nainstalovany, assignment se nepodaril."
      touch "$STATE/teamviewer.assignment-pending"
    fi
  else
    echo "TeamViewer je nainstalovan a lokalne nastaven. Assignment ID neni v IMG."
  fi

  touch "$TEAMVIEWER_DONE"
}

countdown_update_question() {
  local seconds=20 key=""
  while (( seconds > 0 )); do
    printf '\rStahnout nejnovější update z public serveru? Automaticky NE za %2d s. [A] ano [N/X] ne/preskocit: ' "$seconds"
    if IFS= read -r -s -n 1 -t 1 key; then
      printf '\n'
      case "${key^^}" in
        A|P) return 0 ;;
        N|X) return 1 ;;
      esac
    fi
    seconds=$((seconds-1))
  done
  printf '\nCas vyprsel. Automaticky volim NE.\n'
  return 1
}

apply_update_phase() {
  [[ -f "$UPDATE_DONE" ]] && return 0
  banner "FAZE 3 - volitelna aktualizace z public serveru"
  echo "URL: $UPDATE_URL"
  echo "Aktualizace smi menit AppImage, pomocne skripty a splash. Config se neprepisuje."
  echo

  set +e
  countdown_update_question
  choice=$?
  set -e
  case "$choice" in
    1)
      echo "Aktualizace byla preskocena. Pokracuji dalsi fazi."
      touch "$UPDATE_DONE"
      return 0
      ;;
  esac

  wait_for_internet_or_skip 30 "aktualizace z CDN" || {
    echo "Aktualizace preskocena (bez internetu). Pokracuji dalsi fazi."
    touch "$UPDATE_DONE"
    return 0
  }
  rm -rf "$UPDATE_DIR"
  mkdir -p "$UPDATE_DIR"

  if ! wget --timeout=20 --tries=2 -O "$UPDATE_DIR/objng_update.tar.gz.tmp" "$UPDATE_URL"; then
    echo "Update balik na serveru neexistuje nebo neni dostupny. Pokracuji bez aktualizace."
    rm -f "$UPDATE_DIR/objng_update.tar.gz.tmp"
    touch "$UPDATE_DONE"
    sleep 2
    return 0
  fi
  mv "$UPDATE_DIR/objng_update.tar.gz.tmp" "$UPDATE_DIR/objng_update.tar.gz"

  if wget -q -O "$UPDATE_DIR/objng_update.tar.gz.sha256" "$UPDATE_URL.sha256"; then
    expected="$(awk '{print $1}' "$UPDATE_DIR/objng_update.tar.gz.sha256" | head -1)"
    actual="$(sha256sum "$UPDATE_DIR/objng_update.tar.gz" | awk '{print $1}')"
    if [[ -n "$expected" && "$expected" != "$actual" ]]; then
      echo "VAROVANI: SHA256 update baliku nesedi. Pokracuji bez aktualizace."
      rm -rf "$UPDATE_DIR"
      touch "$UPDATE_DONE"
      return 0
    fi
  else
    echo "VAROVANI: SHA256 soubor neni dostupny."
  fi

  mkdir -p "$UPDATE_DIR/unpacked"
  if ! tar -xzf "$UPDATE_DIR/objng_update.tar.gz" -C "$UPDATE_DIR/unpacked" --strip-components=1; then
    echo "VAROVANI: update balik nelze rozbalit. Pokracuji bez aktualizace."
    rm -rf "$UPDATE_DIR"
    touch "$UPDATE_DONE"
    return 0
  fi
  if ! sudo -n "$USER_HOME/bin/apply-public-update.sh" "$UPDATE_DIR/unpacked"; then
    echo "VAROVANI: aplikace update selhala. Pokracuji bez aktualizace."
    touch "$UPDATE_DONE"
    return 0
  fi
  touch "$UPDATE_DONE"
}

expand_filesystem_phase() {
  [[ -f "$EXPAND_DONE" ]] && return 0

  if [[ ! -f "$EXPAND_REQUESTED" ]]; then
    banner "FAZE 4 - rozsiruji filesystem na celou kartu"
    echo "Rozsireni bude dokonceno po automatickem rebootu."
    sudo -n raspi-config nonint do_expand_rootfs
    touch "$EXPAND_REQUESTED"
    sleep 2
    reboot_now
  fi

  banner "FAZE 4 - dokonceni rozsireni filesystemu"
  root_fs="$(findmnt -n -o FSTYPE /)"
  root_dev="$(findmnt -n -o SOURCE /)"
  if [[ "$root_fs" == "ext4" && -b "$root_dev" ]]; then
    sudo -n resize2fs "$root_dev"
  fi
  rm -f "$EXPAND_REQUESTED"
  touch "$EXPAND_DONE"
  df -h /
}

wait_for_internet_or_skip_system_update() {
  local skip_after="${OBJNG_APT_WAIT_SECONDS:-30}"
  local seconds="$skip_after"
  local key=""

  if internet_ok; then
    return 0
  fi

  banner "FAZE 4 - cekam na internet pro systemove aktualizace"
  echo "Bez internetu budou systemove aktualizace po ${skip_after} s automaticky preskoceny."
  show_ip
  echo

  while (( seconds > 0 )); do
    if internet_ok; then
      printf '\nInternet je dostupny. Spoustim apt aktualizace.\n'
      return 0
    fi
    printf '\rCekam na internet... Automaticky preskoceno za %2d s. [X] preskocit: ' "$seconds"
    if IFS= read -r -s -n 1 -t 1 key; then
      printf '\n'
      if [[ "${key^^}" == "X" ]]; then
        echo "Systemove aktualizace preskoceny rucne. Pokracuji do faze 5."
        touch "$SYSTEM_UPDATE_DONE"
        return 1
      fi
    fi
    seconds=$((seconds - 1))
  done
  printf '\n'

  banner "FAZE 4 - systemove aktualizace preskoceny"
  echo "Internet neni dostupny. Pokracuji do faze 5 (dokonceni systemu)."
  echo "Pozdeji lze spustit rucne: sudo system-update.sh"
  touch "$SYSTEM_UPDATE_DONE"
  return 1
}

system_update_phase() {
  [[ -f "$SYSTEM_UPDATE_DONE" ]] && return 0
  wait_for_internet_or_skip_system_update || return 0
  banner "FAZE 4 - instaluji vsechny systemove aktualizace"
  echo "Tento krok muze trvat dele. Zarizeni nevypinej."
  sudo -n "$USER_HOME/bin/system-update.sh"
  touch "$SYSTEM_UPDATE_DONE"
}

detect_output() {
  if command -v wlr-randr >/dev/null 2>&1; then
    wlr-randr 2>/dev/null | awk '/^[^[:space:]]/{out=$1} /Enabled:[[:space:]]+yes/{print out; exit}'
  fi
}

finalize_phase() {
  [[ -f "$FINAL_DONE" ]] && return 0
  banner "FAZE 5 - zaverecne ladeni systemu"
  echo "Nastavuji autologin, zvetseni 125 %, kiosk mode a autostart aplikace."
  echo "Klavesnice se vypne az po uspesne kontrole vsech nastaveni."

  output="$(detect_output)"
  output="${output:-HDMI-A-1}"
  sudo -n env OBJNG_OUTPUT="$output" "$USER_HOME/bin/finalize-system.sh"
  touch "$FINAL_DONE"
  echo
  echo "Instalace MASTER BOOT v$VERSION je dokoncena. Restartuji za 5 sekund."
  sleep 5
  reboot_now
}

if [[ -f "$FINAL_DONE" ]]; then
  exit 0
fi

if [[ ! -f "$TOUCH_DONE" ]]; then
  touch_phase
fi

enable_keyboard
install_local_core
configure_connection
configure_reader
install_teamviewer_phase
apply_update_phase

expand_filesystem_phase
system_update_phase

finalize_phase
