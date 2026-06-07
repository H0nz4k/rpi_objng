#!/usr/bin/env bash
# TeamViewer - automaticke dokonceni RPIBOX: alias, heslo, assignment, lokalni volby a APT hold.
set -Eeuo pipefail

[[ "$EUID" -ne 0 ]] || { echo "Spust jako bezny uzivatel, bez sudo." >&2; exit 1; }
command -v teamviewer >/dev/null 2>&1 || { echo "TeamViewer neni nainstalovany." >&2; exit 1; }

ASSIGNMENT_ID='0001CoABChAn1DcQW0sR8ZRIokz3ZXSFEigIACAAAgAJABmtfJEnMj-Y7lbBshn0p-zoVNn2uea2GX_P6hZVOtXTGkBvtgCUKyHP8fsNMR7EM2iniBRxWb1yvECzdGpsFCp3zBDoh2HqNGcQaNpwq_q3BRo4I4QmjXOl1E_bAfP9cyvZIAEQvdqepQU='

CONFIG_LINK="/opt/objednavka-ng/config.json"
CONFIG="$(readlink -f "$CONFIG_LINK" 2>/dev/null || echo "$CONFIG_LINK")"
FIRSTBOOT_CONFIG="${OBJNG_FIRSTBOOT_CONFIG:-$HOME/firstboot/firstboot.conf}"
TEAMVIEWER_ALIAS_SUFFIX="${TEAMVIEWER_ALIAS_SUFFIX:-}"
TEAMVIEWER_PASSWORD="${TEAMVIEWER_PASSWORD:-}"
TEAMVIEWER_REASSIGN="${TEAMVIEWER_REASSIGN:-0}"

if [[ -f "$FIRSTBOOT_CONFIG" ]]; then
  # shellcheck disable=SC1090
  . "$FIRSTBOOT_CONFIG"
fi

normalize_suffix() {
  printf '%s' "$1" | tr -cs '[:alnum:]_.-' '-' | sed -E 's/^-+//; s/-+$//'
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

default_suffix_from_config() {
  [[ -f "$CONFIG" ]] || return 0
  python3 - "$CONFIG" <<'PY'
import json, sys
try:
    value = str(json.load(open(sys.argv[1], encoding="utf-8")).get("PCBOX_NAME") or "").strip()
except Exception:
    value = ""
if value and "NASTAV" not in value.upper() and "SPRAVN" not in value.upper() and value.upper() != "PCBOX":
    print(value)
PY
}

set_teamviewer_local_options() {
  sudo teamviewer-lokalni-volby apply >/dev/null 2>&1 || {
    echo "VAROVANI: Nepodarilo se zapsat lokalni TeamViewer volby. Zkontroluj pozdeji: sudo teamviewer-lokalni-volby preview" >&2
    return 0
  }
  echo "Jazyk TeamVieweru nastaven na cestinu a povoleny LAN rezim."
}

set_teamviewer_password() {
  tv_pass="$TEAMVIEWER_PASSWORD"
  if [[ -z "$tv_pass" && "${OBJNG_INTERACTIVE:-0}" == "1" ]]; then
    echo
    echo "Volitelne TeamViewer heslo. Prazdne pole = preskocit."
    start_on_screen_keyboard
    read -r -s -t 90 -p "TeamViewer heslo: " tv_pass || tv_pass=""
    echo
  fi
  if [[ -z "$tv_pass" ]]; then
    echo "TeamViewer heslo nebylo zadano; pokracuji bez zmeny hesla."
    return 0
  fi

  sudo teamviewer passwd "$tv_pass"
  unset tv_pass
  echo "TeamViewer heslo bylo nastaveno."
}

hold_teamviewer_updates() {
  sudo teamviewer-updates-off
}

echo "============================================================"
echo " TeamViewer - dokonceni RPIBOX"
echo "============================================================"
echo

sudo systemctl enable --now teamviewerd >/dev/null 2>&1 || {
  echo "VAROVANI: Nepodarilo se spustit sluzbu teamviewerd." >&2
}

teamviewer info 2>/dev/null || true
echo

config_suffix="$(default_suffix_from_config || true)"
default_extra="${TEAMVIEWER_ALIAS_SUFFIX:-$config_suffix}"
extra="$default_extra"
if [[ -z "$extra" && "${OBJNG_INTERACTIVE:-0}" == "1" ]]; then
  start_on_screen_keyboard
  read -r -t 60 -p "Volitelny doplnek nazvu za RPIBOX: " extra || extra=""
fi
extra="$(normalize_suffix "$extra")"
if [[ -n "$extra" ]]; then
  device_alias="RPIBOX-$extra"
else
  device_alias="RPIBOX"
fi

echo
echo "Nazev zarizeni v TeamVieweru: $device_alias"

set_teamviewer_password

set_teamviewer_local_options

hold_teamviewer_updates

if [[ -z "$ASSIGNMENT_ID" || "$ASSIGNMENT_ID" == "SEM_VLOZ_SKUTECNE_ASSIGNMENT_ID" ]]; then
  echo "VAROVANI: V teamviewer-dokoncit.sh neni vlozene Assignment ID. Priřazeni do spravy preskakuji."
  exit 0
fi

reassign_args=()
if [[ "${TEAMVIEWER_REASSIGN:-0}" == "1" ]]; then
  reassign_args+=(--reassign)
fi

echo
echo "Prirazuji zarizeni '$device_alias' do TeamViewer spravy..."
set +e
sudo teamviewer assignment \
  --id "$ASSIGNMENT_ID" \
  --device_alias "$device_alias" \
  --offline \
  "${reassign_args[@]}"
rc=$?
set -e
unset ASSIGNMENT_ID

if [[ "$rc" -eq 0 ]]; then
  echo
  echo "TeamViewer assignment byl prijat."
  echo "Sluzba teamviewerd je povolena po startu, aktualizace balicku jsou zakazane."
  echo "Over, ze zarizeni '$device_alias' vzniklo ve spravne cilove skupine portalu."
else
  echo
  echo "TeamViewer assignment selhal (kod $rc)." >&2
  echo "Zkontroluj Assignment ID, opravneni spravce a beh sluzby teamviewerd." >&2
  exit "$rc"
fi
