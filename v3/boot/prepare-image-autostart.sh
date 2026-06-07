#!/usr/bin/env bash
set -Eeuo pipefail

USER_NAME="${OBJNG_USER:-objng}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
FIRSTBOOT="$USER_HOME/firstboot/firstboot-install.sh"
STATE_DONE="$USER_HOME/.local/state/objednavka-ng-firstboot/done"

[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo: sudo bash prepare-image-autostart.sh" >&2; exit 1; }
[[ -n "$USER_HOME" && -d "$USER_HOME" ]] || { echo "Uzivatel $USER_NAME neexistuje." >&2; exit 1; }
[[ -f "$FIRSTBOOT" ]] || { echo "Chybi $FIRSTBOOT" >&2; exit 1; }

TARGET_GROUP="$(id -gn "$USER_NAME")"

install -d -m 0755 -o "$USER_NAME" -g "$TARGET_GROUP" "$USER_HOME/.config/autostart" "$USER_HOME/.config/labwc"
chmod +x "$FIRSTBOOT"
chown "$USER_NAME:$TARGET_GROUP" "$FIRSTBOOT"

cat > "$USER_HOME/.config/autostart/objng-firstboot.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=ObjednavkaNG firstboot
Exec=lxterminal --title="ObjednavkaNG firstboot" -e bash $FIRSTBOOT
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
chown "$USER_NAME:$TARGET_GROUP" "$USER_HOME/.config/autostart/objng-firstboot.desktop"

AUTO="$USER_HOME/.config/labwc/autostart"
if [[ -f "$AUTO" ]]; then
  python3 - "$AUTO" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
t = p.read_text(encoding="utf-8", errors="replace")
t = re.sub(r"\n?# >>> OBJNG-IMG-FIRSTBOOT >>>.*?# <<< OBJNG-IMG-FIRSTBOOT <<<\n?", "\n", t, flags=re.S)
p.write_text(t.lstrip("\n"), encoding="utf-8")
PY
fi

cat >> "$AUTO" <<EOF

# >>> OBJNG-IMG-FIRSTBOOT >>>
if [ ! -f "$STATE_DONE" ]; then
  lxterminal --title="ObjednavkaNG firstboot" -e bash "$FIRSTBOOT" &
fi
# <<< OBJNG-IMG-FIRSTBOOT <<<
EOF
chown "$USER_NAME:$TARGET_GROUP" "$AUTO"

echo "Nastavuji autologin pro uzivatele $USER_NAME..."
if command -v raspi-config >/dev/null 2>&1; then
  env SUDO_USER="$USER_NAME" raspi-config nonint do_boot_behaviour B4 || true
fi

install -d -m 0755 /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/90-objng-autologin.conf <<EOF
[Seat:*]
autologin-user=$USER_NAME
autologin-user-timeout=0
user-session=LXDE-pi
EOF

systemctl set-default graphical.target

echo
echo "Hotovo:"
echo "  autologin-user=$USER_NAME"
echo "  firstboot autostart pripraven"
echo
echo "Pro test restartuj:"
echo "  sudo reboot"
