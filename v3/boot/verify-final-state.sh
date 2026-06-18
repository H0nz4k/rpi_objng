#!/usr/bin/env bash
# Final state verification for ObjednavkaNG MASTER BOOT FINAL v2.1.8.
set -u

USER_HOME="/home/objng"
AUTO="$USER_HOME/.config/labwc/autostart"
SYSTEM_AUTO="/etc/xdg/labwc/autostart"
FAIL=0

check() {
  local label="$1"; shift
  if "$@"; then
    printf 'OK    %s\n' "$label"
  else
    printf 'CHYBA %s\n' "$label"
    FAIL=1
  fi
}

warn() {
  local label="$1"; shift
  if "$@"; then
    printf 'OK    %s\n' "$label"
  else
    printf 'WARN  %s\n' "$label"
  fi
}

check "AppImage" test -x /opt/objednavka-ng/objednavka-ng.AppImage
check "Config symlink" test -L /opt/objednavka-ng/config.json
warn "TeamViewer prikaz" command -v teamviewer
warn "TeamViewer sluzba aktivni" systemctl is-active --quiet teamviewerd.service
check "Desktop autologin" grep -q '^autologin-user=objng$' /etc/lightdm/lightdm.conf.d/90-objednavka-ng-autologin.conf
check "Graphical target" test "$(systemctl get-default)" = graphical.target
check "Kanshi profil" grep -q '^# OBJEDNAVKANG-MANAGED-DISPLAY-SCALE' "$USER_HOME/.config/kanshi/config"
check "Kanshi autostart" grep -Fq '# >>> OBJNG_KANSHI >>>' "$AUTO"
check "ObjednavkaNG autostart" grep -Fq '# >>> OBJEDNAVKA-NG-KIOSK >>>' "$AUTO"
check "MASTER BOOT final marker" test -f "$USER_HOME/.local/state/objng-master-bootstrap/final.done"
check "MASTER BOOT launcher zachovan pro reset" grep -Fq '# >>> OBJNG_MASTER_BOOT_V2 >>>' "$AUTO"
check "Desktop skryt" grep -Eq '^[[:space:]]*#[[:space:]]*/usr/bin/lwrespawn /usr/bin/pcmanfm-pi' "$SYSTEM_AUTO"
check "Panel skryt" grep -Eq '^[[:space:]]*#[[:space:]]*/usr/bin/lwrespawn /usr/bin/wf-panel-pi' "$SYSTEM_AUTO"

exit "$FAIL"
