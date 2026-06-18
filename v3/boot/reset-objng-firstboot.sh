#!/usr/bin/env bash
# Reset MASTER BOOT FINAL v2.1.7 zpet pred kalibraci.
# Pouziti:
#   sudo reset-objng-firstboot           # soft reset (firstboot od kalibrace)
#   sudo reset-objng-firstboot --factory # + smaze /opt/objednavka-ng a ikony na ploche

# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -qP '\r' "$0" 2>/dev/null; then sed -i 's/\r//' "$0"; exec bash "$0" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -Eeuo pipefail

TARGET_USER="${OBJNG_USER:-objng}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
STATE="$TARGET_HOME/.local/state/objng-master-bootstrap"
CAL="$TARGET_HOME/.local/state/objednavka-ng-touch-calibrator"
AUTO="$TARGET_HOME/.config/labwc/autostart"
KANSHI="$TARGET_HOME/.config/kanshi/config"
DESKTOP="$TARGET_HOME/Desktop"
FACTORY=0

for arg in "$@"; do
  case "$arg" in
    --factory) FACTORY=1 ;;
    -h|--help)
      echo "Pouziti: sudo $0 [--factory]"
      echo "  --factory  smaze take /opt/objednavka-ng a servisni ikony (testovaci cisty stav bez nove SD)"
      exit 0
      ;;
  esac
done

[[ "$EUID" -eq 0 ]] || exec sudo "$0" "$@"

pkill -TERM -f "$TARGET_HOME/bin/firstboot-install.sh" 2>/dev/null || true
pkill -TERM -f "$TARGET_HOME/bin/touch-test.py" 2>/dev/null || true
pkill -TERM -f "$TARGET_HOME/bin/touch_calibrator_v3.py" 2>/dev/null || true
pkill -TERM -f /opt/objednavka-ng/objednavka-ng.AppImage 2>/dev/null || true
pkill -TERM -x eCalib 2>/dev/null || true
pkill -TERM -x squeekboard 2>/dev/null || true
pkill -TERM -x kanshi 2>/dev/null || true

if [[ -x "$TARGET_HOME/bin/touch-bootstrap.sh" ]]; then
  runuser -u "$TARGET_USER" -- "$TARGET_HOME/bin/touch-bootstrap.sh" --reset 2>/dev/null || true
fi

rm -rf "$STATE" "$CAL" "$TARGET_HOME/install" "$TARGET_HOME/update"
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$STATE"

rm -f /etc/udev/rules.d/99-objednavka-ng-touchscreen-calibration.rules
rm -f /etc/udev/rules.d/99-objng-3m-calibration.rules
rm -f /etc/udev/rules.d/99-3m-touch-calibration.rules
udevadm control --reload-rules 2>/dev/null || true

rm -f /tmp/objng-firstboot-install.lock
rm -f "$TARGET_HOME/objng_firstboot_install.log" \
      "$TARGET_HOME/objng_egtouch_install.log" \
      "$TARGET_HOME/objng_teamviewer_install.log" \
      "$TARGET_HOME/objng-install-summary.txt"

if [[ "$FACTORY" -eq 1 ]]; then
  echo "Factory reset: odstranuji /opt/objednavka-ng a servisni ikony."
  rm -rf /opt/objednavka-ng
  rm -f "$DESKTOP/Config OBJNG.desktop" \
        "$DESKTOP/Prikazy OBJNG.desktop" \
        "$DESKTOP/Prikazy OBJNG.txt" \
        "$DESKTOP/Info OBJNG.desktop" \
        "$DESKTOP/Info OBJNG.txt"
fi

# Pri resetu zobraz znovu desktop a vypni autostart aplikace/kanshi,
# aby nic neprekazelo nove kalibraci.
if [[ -x /usr/local/sbin/objednavka-kiosk-system-mode ]]; then
  /usr/local/sbin/objednavka-kiosk-system-mode desktop || true
fi

install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$(dirname "$AUTO")"
touch "$AUTO"
python3 - "$AUTO" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); t=p.read_text(encoding='utf-8', errors='replace') if p.exists() else ''
for pat in [
 r'\n?# >>> OBJNG_MASTER_BOOT_V2 >>>.*?# <<< OBJNG_MASTER_BOOT_V2 <<<\n?',
 r'\n?# >>> OBJNG_KANSHI >>>.*?# <<< OBJNG_KANSHI <<<\n?',
 r'\n?# >>> OBJEDNAVKA-NG-KIOSK >>>.*?# <<< OBJEDNAVKA-NG-KIOSK <<<\n?',
]:
    t=re.sub(pat,'\n',t,flags=re.S)
block='''
# >>> OBJNG_MASTER_BOOT_V2 >>>
if [ ! -f /home/objng/.local/state/objng-master-bootstrap/final.done ]; then
    if command -v foot >/dev/null 2>&1; then
        foot -a objng-master-boot -T "ObjednavkaNG MASTER BOOT FINAL" -W 120x17 /home/objng/bin/firstboot-install.sh &
    else
        lxterminal --geometry=120x17+0+0 --title="ObjednavkaNG MASTER BOOT FINAL" -e /home/objng/bin/firstboot-install.sh &
    fi
fi
# <<< OBJNG_MASTER_BOOT_V2 <<<
'''
p.write_text(t.rstrip()+'\n'+block, encoding='utf-8')
PY
chown "$TARGET_USER:$TARGET_GROUP" "$AUTO"
chmod 0755 "$AUTO"

if [[ -f "$KANSHI" ]] && grep -q '^# OBJEDNAVKANG-MANAGED-DISPLAY-SCALE' "$KANSHI"; then
  rm -f "$KANSHI"
fi

raspi-config nonint do_squeekboard S3 2>/dev/null || raspi-config nonint do_squeekboard S2 2>/dev/null || true
runuser -u "$TARGET_USER" -- gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false 2>/dev/null || true

chown -R "$TARGET_USER:$TARGET_GROUP" "$TARGET_HOME/.local/state" "$TARGET_HOME/.config/labwc" 2>/dev/null || true
sync

echo "MASTER BOOT FINAL v2.1.7 byl resetovan pred kalibraci."
if [[ "$FACTORY" -eq 1 ]]; then
  echo "Factory reset: /opt/objednavka-ng byl smazan, firstboot nainstaluje znovu z payloadu v IMG."
fi
echo "Nyni proved: sudo reboot"
