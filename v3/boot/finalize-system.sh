#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q # Final verified system tuning for ObjednavkaNG MASTER BOOT FINAL v2.1.7.
set -Eeuo pipefail

TARGET_USER="${OBJNG_USER:-objng}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
TARGET_UID="$(id -u "$TARGET_USER")"
AUTO="$TARGET_HOME/.config/labwc/autostart"
KANSHI_DIR="$TARGET_HOME/.config/kanshi"
KANSHI_CONFIG="$KANSHI_DIR/config"
OUTPUT="${OBJNG_OUTPUT:-HDMI-A-1}"
SCALE="${OBJNG_SCALE:-1.25}"
SUMMARY="$TARGET_HOME/objng-install-summary.txt"

[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo." >&2; exit 1; }
[[ -x /opt/objednavka-ng/objednavka-ng.AppImage ]] || { echo "Chybi aplikace ObjednavkaNG." >&2; exit 1; }
[[ -x /usr/local/sbin/objednavka-kiosk-system-mode ]] || { echo "Chybi kiosk system helper." >&2; exit 1; }

configure_autologin() {
  echo "[FINAL] Nastavuji desktop autologin uzivatele $TARGET_USER."
  if command -v raspi-config >/dev/null 2>&1; then
    env SUDO_USER="$TARGET_USER" raspi-config nonint do_boot_behaviour B4
  fi
  install -d -m 0755 /etc/lightdm/lightdm.conf.d
  cat > /etc/lightdm/lightdm.conf.d/90-objednavka-ng-autologin.conf <<EOF2
[Seat:*]
autologin-user=$TARGET_USER
autologin-user-timeout=0
EOF2
  systemctl set-default graphical.target
  systemctl enable lightdm.service
  systemctl is-enabled --quiet lightdm.service
  grep -q "^autologin-user=$TARGET_USER$" /etc/lightdm/lightdm.conf.d/90-objednavka-ng-autologin.conf
}

configure_scale() {
  echo "[FINAL] Nastavuji trvale zvetseni ${SCALE} na vystupu $OUTPUT."
  install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$KANSHI_DIR"
  cat > "$KANSHI_CONFIG" <<EOF2
# OBJEDNAVKANG-MANAGED-DISPLAY-SCALE
profile objednavka-ng-scale {
    output $OUTPUT enable scale $SCALE position 0,0 transform normal
}
EOF2
  chown "$TARGET_USER:$TARGET_GROUP" "$KANSHI_CONFIG"
  chmod 0644 "$KANSHI_CONFIG"
}

configure_user_autostart() {
  echo "[FINAL] Nastavuji kanshi a automaticke spusteni aplikace."
  install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$(dirname "$AUTO")"
  touch "$AUTO"
  chown "$TARGET_USER:$TARGET_GROUP" "$AUTO"

  python3 - "$AUTO" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); t=p.read_text(encoding='utf-8', errors='replace') if p.exists() else ''
patterns=[
 r'\n?# >>> OBJNG_KANSHI >>>.*?# <<< OBJNG_KANSHI <<<\n?',
 r'\n?# >>> OBJEDNAVKA-NG-KIOSK >>>.*?# <<< OBJEDNAVKA-NG-KIOSK <<<\n?',
]
for pat in patterns:
    t=re.sub(pat,'\n',t,flags=re.S)
blocks='''
# >>> OBJNG_KANSHI >>>
pgrep -u "$(id -u)" -x kanshi >/dev/null 2>&1 || kanshi >>"$HOME/.local/state/objednavka-ng/kanshi.log" 2>&1 &
# <<< OBJNG_KANSHI <<<

# >>> OBJEDNAVKA-NG-KIOSK >>>
(sleep 3; /opt/objednavka-ng/scripts/kiosk-run.sh) &
# <<< OBJEDNAVKA-NG-KIOSK <<<
'''
p.write_text(t.rstrip()+'\n'+blocks, encoding='utf-8')
PY
  chown "$TARGET_USER:$TARGET_GROUP" "$AUTO"
  chmod 0755 "$AUTO"
  grep -Fq '# >>> OBJNG_KANSHI >>>' "$AUTO"
  grep -Fq '# >>> OBJEDNAVKA-NG-KIOSK >>>' "$AUTO"
}

kiosk_entry_active() {
  local needle="$1"
  local file="$2"
  grep -F "$needle" "$file" 2>/dev/null | grep -Ev '^[[:space:]]*#' | grep -q .
}

configure_kiosk_desktop() {
  echo "[FINAL] Skryvam plochu a panel pro kiosk rezim."
  if ! /usr/local/sbin/objednavka-kiosk-system-mode clean; then
    echo "VAROVANI: objednavka-kiosk-system-mode clean selhal; pokracuji do finalizace." >&2
  fi

  SYSTEM_AUTO="/etc/xdg/labwc/autostart"
  if [[ ! -f "$SYSTEM_AUTO" ]]; then
    echo "VAROVANI: $SYSTEM_AUTO neexistuje; stav kiosk desktopu nebyl overen." >&2
    return 0
  fi

  if kiosk_entry_active '/usr/bin/lwrespawn /usr/bin/pcmanfm-pi' "$SYSTEM_AUTO"; then
    echo "VAROVANI: pcmanfm-pi neni v systemovem autostartu spolehlive skryty." >&2
  fi
  if kiosk_entry_active '/usr/bin/lwrespawn /usr/bin/wf-panel-pi' "$SYSTEM_AUTO"; then
    echo "VAROVANI: wf-panel-pi neni v systemovem autostartu spolehlive skryty." >&2
  fi
}

apply_scale_now_best_effort() {
  local runtime="/run/user/$TARGET_UID" wayland=""
  if [[ -d "$runtime" ]]; then
    wayland="$(find "$runtime" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' 2>/dev/null | head -1 || true)"
  fi
  if [[ -n "$wayland" && -x /usr/bin/wlr-randr ]]; then
    runuser -u "$TARGET_USER" -- env \
      HOME="$TARGET_HOME" XDG_RUNTIME_DIR="$runtime" WAYLAND_DISPLAY="$wayland" \
      wlr-randr --output "$OUTPUT" --scale "$SCALE" || true
  fi
}

verify_teamviewer() {
  echo "[FINAL] Overuji TeamViewer."
  command -v teamviewer >/dev/null 2>&1
  systemctl is-enabled --quiet teamviewerd.service
  systemctl is-active --quiet teamviewerd.service
}

disable_keyboard_final() {
  echo "[FINAL] Vypinam obrazovkovou klavesnici."
  if command -v raspi-config >/dev/null 2>&1; then
    raspi-config nonint do_squeekboard S3 2>/dev/null || raspi-config nonint do_squeekboard S2 2>/dev/null || true
  fi
  runuser -u "$TARGET_USER" -- gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false 2>/dev/null || true
  pkill -x squeekboard 2>/dev/null || true
}


configure_autologin
configure_scale
configure_user_autostart
configure_kiosk_desktop
apply_scale_now_best_effort
verify_teamviewer
disable_keyboard_final

cat > "$SUMMARY" <<EOF2
OBJEDNAVKANG - FINALNI STAV
==========================
Datum: $(date '+%F %T')
Uzivatel: $TARGET_USER
Autologin: ZAPNUT
TeamViewer: NAINSTALOVAN, SLUZBA AKTIVNI
Zobrazeni: scale $SCALE na $OUTPUT
Kiosk desktop: ZAPNUT
Autostart ObjednavkaNG: ZAPNUT
Obrazovkova klavesnice: VYPNUTA
Filesystem: ROZSIRENI PROBEHLO VE FAZI 4
Systemove aktualizace: PROVEDENY VE FAZI 4
EOF2
chown "$TARGET_USER:$TARGET_GROUP" "$SUMMARY"

sync
echo "Finalni ladeni bylo uspesne overeno. MASTER BOOT launcher zustava bezpecne blokovan souborem final.done."
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
# Final verified system tuning for ObjednavkaNG MASTER BOOT FINAL v2.1.7.
set -Eeuo pipefail

TARGET_USER="${OBJNG_USER:-objng}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
TARGET_UID="$(id -u "$TARGET_USER")"
AUTO="$TARGET_HOME/.config/labwc/autostart"
KANSHI_DIR="$TARGET_HOME/.config/kanshi"
KANSHI_CONFIG="$KANSHI_DIR/config"
OUTPUT="${OBJNG_OUTPUT:-HDMI-A-1}"
SCALE="${OBJNG_SCALE:-1.25}"
SUMMARY="$TARGET_HOME/objng-install-summary.txt"

[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo." >&2; exit 1; }
[[ -x /opt/objednavka-ng/objednavka-ng.AppImage ]] || { echo "Chybi aplikace ObjednavkaNG." >&2; exit 1; }
[[ -x /usr/local/sbin/objednavka-kiosk-system-mode ]] || { echo "Chybi kiosk system helper." >&2; exit 1; }

configure_autologin() {
  echo "[FINAL] Nastavuji desktop autologin uzivatele $TARGET_USER."
  if command -v raspi-config >/dev/null 2>&1; then
    env SUDO_USER="$TARGET_USER" raspi-config nonint do_boot_behaviour B4
  fi
  install -d -m 0755 /etc/lightdm/lightdm.conf.d
  cat > /etc/lightdm/lightdm.conf.d/90-objednavka-ng-autologin.conf <<EOF2
[Seat:*]
autologin-user=$TARGET_USER
autologin-user-timeout=0
EOF2
  systemctl set-default graphical.target
  systemctl enable lightdm.service
  systemctl is-enabled --quiet lightdm.service
  grep -q "^autologin-user=$TARGET_USER$" /etc/lightdm/lightdm.conf.d/90-objednavka-ng-autologin.conf
}

configure_scale() {
  echo "[FINAL] Nastavuji trvale zvetseni ${SCALE} na vystupu $OUTPUT."
  install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$KANSHI_DIR"
  cat > "$KANSHI_CONFIG" <<EOF2
# OBJEDNAVKANG-MANAGED-DISPLAY-SCALE
profile objednavka-ng-scale {
    output $OUTPUT enable scale $SCALE position 0,0 transform normal
}
EOF2
  chown "$TARGET_USER:$TARGET_GROUP" "$KANSHI_CONFIG"
  chmod 0644 "$KANSHI_CONFIG"
}

configure_user_autostart() {
  echo "[FINAL] Nastavuji kanshi a automaticke spusteni aplikace."
  install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$(dirname "$AUTO")"
  touch "$AUTO"
  chown "$TARGET_USER:$TARGET_GROUP" "$AUTO"

  python3 - "$AUTO" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); t=p.read_text(encoding='utf-8', errors='replace') if p.exists() else ''
patterns=[
 r'\n?# >>> OBJNG_KANSHI >>>.*?# <<< OBJNG_KANSHI <<<\n?',
 r'\n?# >>> OBJEDNAVKA-NG-KIOSK >>>.*?# <<< OBJEDNAVKA-NG-KIOSK <<<\n?',
]
for pat in patterns:
    t=re.sub(pat,'\n',t,flags=re.S)
blocks='''
# >>> OBJNG_KANSHI >>>
pgrep -u "$(id -u)" -x kanshi >/dev/null 2>&1 || kanshi >>"$HOME/.local/state/objednavka-ng/kanshi.log" 2>&1 &
# <<< OBJNG_KANSHI <<<

# >>> OBJEDNAVKA-NG-KIOSK >>>
(sleep 3; /opt/objednavka-ng/scripts/kiosk-run.sh) &
# <<< OBJEDNAVKA-NG-KIOSK <<<
'''
p.write_text(t.rstrip()+'\n'+blocks, encoding='utf-8')
PY
  chown "$TARGET_USER:$TARGET_GROUP" "$AUTO"
  chmod 0755 "$AUTO"
  grep -Fq '# >>> OBJNG_KANSHI >>>' "$AUTO"
  grep -Fq '# >>> OBJEDNAVKA-NG-KIOSK >>>' "$AUTO"
}

kiosk_entry_active() {
  local needle="$1"
  local file="$2"
  grep -F "$needle" "$file" 2>/dev/null | grep -Ev '^[[:space:]]*#' | grep -q .
}

configure_kiosk_desktop() {
  echo "[FINAL] Skryvam plochu a panel pro kiosk rezim."
  if ! /usr/local/sbin/objednavka-kiosk-system-mode clean; then
    echo "VAROVANI: objednavka-kiosk-system-mode clean selhal; pokracuji do finalizace." >&2
  fi

  SYSTEM_AUTO="/etc/xdg/labwc/autostart"
  if [[ ! -f "$SYSTEM_AUTO" ]]; then
    echo "VAROVANI: $SYSTEM_AUTO neexistuje; stav kiosk desktopu nebyl overen." >&2
    return 0
  fi

  if kiosk_entry_active '/usr/bin/lwrespawn /usr/bin/pcmanfm-pi' "$SYSTEM_AUTO"; then
    echo "VAROVANI: pcmanfm-pi neni v systemovem autostartu spolehlive skryty." >&2
  fi
  if kiosk_entry_active '/usr/bin/lwrespawn /usr/bin/wf-panel-pi' "$SYSTEM_AUTO"; then
    echo "VAROVANI: wf-panel-pi neni v systemovem autostartu spolehlive skryty." >&2
  fi
}

apply_scale_now_best_effort() {
  local runtime="/run/user/$TARGET_UID" wayland=""
  if [[ -d "$runtime" ]]; then
    wayland="$(find "$runtime" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' 2>/dev/null | head -1 || true)"
  fi
  if [[ -n "$wayland" && -x /usr/bin/wlr-randr ]]; then
    runuser -u "$TARGET_USER" -- env \
      HOME="$TARGET_HOME" XDG_RUNTIME_DIR="$runtime" WAYLAND_DISPLAY="$wayland" \
      wlr-randr --output "$OUTPUT" --scale "$SCALE" || true
  fi
}

verify_teamviewer() {
  echo "[FINAL] Overuji TeamViewer."
  command -v teamviewer >/dev/null 2>&1
  systemctl is-enabled --quiet teamviewerd.service
  systemctl is-active --quiet teamviewerd.service
}

disable_keyboard_final() {
  echo "[FINAL] Vypinam obrazovkovou klavesnici."
  if command -v raspi-config >/dev/null 2>&1; then
    raspi-config nonint do_squeekboard S3 2>/dev/null || raspi-config nonint do_squeekboard S2 2>/dev/null || true
  fi
  runuser -u "$TARGET_USER" -- gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false 2>/dev/null || true
  pkill -x squeekboard 2>/dev/null || true
}


configure_autologin
configure_scale
configure_user_autostart
configure_kiosk_desktop
apply_scale_now_best_effort
verify_teamviewer
disable_keyboard_final

cat > "$SUMMARY" <<EOF2
OBJEDNAVKANG - FINALNI STAV
==========================
Datum: $(date '+%F %T')
Uzivatel: $TARGET_USER
Autologin: ZAPNUT
TeamViewer: NAINSTALOVAN, SLUZBA AKTIVNI
Zobrazeni: scale $SCALE na $OUTPUT
Kiosk desktop: ZAPNUT
Autostart ObjednavkaNG: ZAPNUT
Obrazovkova klavesnice: VYPNUTA
Filesystem: ROZSIRENI PROBEHLO VE FAZI 4
Systemove aktualizace: PROVEDENY VE FAZI 4
EOF2
chown "$TARGET_USER:$TARGET_GROUP" "$SUMMARY"

sync
echo "Finalni ladeni bylo uspesne overeno. MASTER BOOT launcher zustava bezpecne blokovan souborem final.done."
