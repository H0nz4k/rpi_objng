#!/usr/bin/env bash
# ObjednavkaNG MASTER BOOT FINAL v2.1.6
# Pripravi Raspberry Pi OS Desktop master kartu pro prvni automaticke spusteni.
set -Eeuo pipefail

VERSION="2.1.6"
TARGET_USER="${OBJNG_USER:-objng}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$SRC_DIR/files/bin"
PAYLOAD_SRC="$SRC_DIR/files/payload"
SECRETS_SRC="$SRC_DIR/files/secrets"
BOOT_ROOT="$TARGET_HOME/bootstrap/v2"
PAYLOAD_DST="$BOOT_ROOT/payload"
TV_URL="https://download.teamviewer.com/download/linux/teamviewer-host_arm64.deb"

[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo: sudo ./setup-master-img.sh" >&2; exit 1; }
[[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] || { echo "Nenalezen uzivatel $TARGET_USER" >&2; exit 1; }
[[ -s "$PAYLOAD_SRC/app/objednavka-ng.AppImage" ]] || { echo "Chybi AppImage v baliku." >&2; exit 1; }

echo "============================================================"
echo " ObjednavkaNG MASTER BOOT v$VERSION"
echo "============================================================"
echo

apt-get update
PACKAGES=(
  wget ca-certificates util-linux usbutils p7zip-full
  python3-evdev python3-tk libinput-tools
  squeekboard wlr-randr kanshi e2fsprogs foot lightdm wlrctl
)
for optional in lxterminal rpi-splash-screen-support; do
  if apt-cache show "$optional" >/dev/null 2>&1; then
    PACKAGES+=("$optional")
  fi
done
if apt-cache show libfuse2t64 >/dev/null 2>&1; then
  PACKAGES+=(libfuse2t64)
elif apt-cache show libfuse2 >/dev/null 2>&1; then
  PACKAGES+=(libfuse2)
fi
DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGES[@]}"

install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" \
  "$TARGET_HOME/bin" "$BOOT_ROOT" "$PAYLOAD_DST" "$BOOT_ROOT/secrets" \
  "$TARGET_HOME/.config/labwc" "$TARGET_HOME/.local/state/objng-master-bootstrap"

for f in \
  firstboot-install.sh touch-bootstrap.sh touch-test.py touch_calibrator_v3.py \
  labwc-fullscreen.sh labwc_tk_helper.py \
  install-egalax-eeti-bootstrap.sh install-local-core.sh install-teamviewer.sh \
  teamviewer-postinstall.sh apply-public-update.sh finalize-system.sh system-update.sh \
  verify-final-state.sh reset-objng-firstboot.sh; do
  [[ -s "$BIN_SRC/$f" ]] || { echo "Chybi $BIN_SRC/$f" >&2; exit 1; }
  install -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$BIN_SRC/$f" "$TARGET_HOME/bin/$f"
done

rm -rf "$PAYLOAD_DST"
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$PAYLOAD_DST"
cp -a "$PAYLOAD_SRC/." "$PAYLOAD_DST/"
chown -R "$TARGET_USER:$TARGET_GROUP" "$PAYLOAD_DST"
find "$PAYLOAD_DST" -type d -exec chmod 0755 {} +
find "$PAYLOAD_DST" -type f -name '*.sh' -exec chmod 0755 {} +
chmod 0755 "$PAYLOAD_DST/app/objednavka-ng.AppImage"

# Volitelne neverejne TeamViewer secret soubory (0600).
for tv_secret in teamviewer-assignment-id teamviewer-password teamviewer-alias; do
  if [[ -s "$SECRETS_SRC/$tv_secret" ]]; then
    install -m 0600 -o "$TARGET_USER" -g "$TARGET_GROUP" \
      "$SECRETS_SRC/$tv_secret" "$BOOT_ROOT/secrets/$tv_secret"
  fi
done

# TeamViewer zustava jen jako instalacni DEB v IMG. Na masteru se nespousti,
# aby se do klonu neprenesla identita TeamVieweru.
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$PAYLOAD_DST/teamviewer"
TV_LOCAL="$(find "$PAYLOAD_DST/teamviewer" -maxdepth 1 -type f -name 'teamviewer*.deb' | head -1 || true)"
if [[ -z "$TV_LOCAL" ]]; then
  echo "TeamViewer DEB neni v baliku; zkousim ho ulozit do IMG payloadu."
  if wget --timeout=30 --tries=2 -O "$PAYLOAD_DST/teamviewer/teamviewer-host_arm64.deb.tmp" "$TV_URL"; then
    mv "$PAYLOAD_DST/teamviewer/teamviewer-host_arm64.deb.tmp" "$PAYLOAD_DST/teamviewer/teamviewer-host_arm64.deb"
    chown "$TARGET_USER:$TARGET_GROUP" "$PAYLOAD_DST/teamviewer/teamviewer-host_arm64.deb"
  else
    rm -f "$PAYLOAD_DST/teamviewer/teamviewer-host_arm64.deb.tmp"
    echo "VAROVANI: TeamViewer se ted nestahl. Firstboot ho stahne na cilovem zarizeni." >&2
  fi
fi

# Behem firstbootu nesmi byt vyzadovano fyzicke heslo.
cat > /etc/sudoers.d/010-objng-firstboot-nopasswd <<EOF2
$TARGET_USER ALL=(root) NOPASSWD: ALL
EOF2
chmod 0440 /etc/sudoers.d/010-objng-firstboot-nopasswd
visudo -cf /etc/sudoers.d/010-objng-firstboot-nopasswd

configure_touch_access() {
  getent group input >/dev/null 2>&1 || groupadd --system input
  usermod -aG input "$TARGET_USER"
  cat > /etc/udev/rules.d/98-objednavka-ng-touch-access.rules <<'EOF2'
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="0596", ATTRS{idProduct}=="0001", GROUP="input", MODE="0660"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="0eef", ATTRS{idProduct}=="0001", GROUP="input", MODE="0660"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="eGalaxTouch Virtual Device for Single*", GROUP="input", MODE="0660"
EOF2
  chmod 0644 /etc/udev/rules.d/98-objednavka-ng-touch-access.rules
  udevadm control --reload-rules 2>/dev/null || true
  udevadm trigger --subsystem-match=input --action=change 2>/dev/null || true
}
configure_touch_access

configure_autologin() {
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
}
configure_autologin

# Vypnuti starych duplicitnich launcheru.
rm -f "$TARGET_HOME/.config/autostart/objng-firstboot.desktop"
AUTO="$TARGET_HOME/.config/labwc/autostart"
touch "$AUTO"
chown "$TARGET_USER:$TARGET_GROUP" "$AUTO"
python3 - "$AUTO" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); t=p.read_text(encoding='utf-8', errors='replace') if p.exists() else ''
patterns=[
 r'\n?# BEGIN OBJNG_FIRSTBOOT_INSTALL.*?# END OBJNG_FIRSTBOOT_INSTALL\n?',
 r'\n?# >>> OBJNG-IMG-FIRSTBOOT >>>.*?# <<< OBJNG-IMG-FIRSTBOOT <<<\n?',
 r'\n?# >>> OBJNG_MASTER_FIRSTBOOT >>>.*?# <<< OBJNG_MASTER_FIRSTBOOT <<<\n?',
 r'\n?# >>> OBJNG_MASTER_BOOT_V2 >>>.*?# <<< OBJNG_MASTER_BOOT_V2 <<<\n?',
 r'\n?# >>> OBJEDNAVKA-NG-FIRSTBOOT >>>.*?# <<< OBJEDNAVKA-NG-FIRSTBOOT <<<\n?',
]
for pat in patterns:
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
chmod 0755 "$AUTO"

# Nativni terminal foot ma vlastni app-id; labwc ho proto umi spolehlive umistit k horni hrane.
RC="$TARGET_HOME/.config/labwc/rc.xml"
if [[ ! -f "$RC" && -f /etc/xdg/labwc/rc.xml ]]; then
  cp -a /etc/xdg/labwc/rc.xml "$RC"
  chown "$TARGET_USER:$TARGET_GROUP" "$RC"
fi
python3 - "$RC" <<'PY'
from pathlib import Path
import sys, xml.etree.ElementTree as ET
p=Path(sys.argv[1])
if not p.exists():
    p.write_text('<labwc_config>\n</labwc_config>\n', encoding='utf-8')
tree=ET.parse(p)
root=tree.getroot()
wr=root.find('windowRules')
if wr is None:
    wr=ET.SubElement(root,'windowRules')
for child in list(wr):
    if child.tag == 'windowRule' and (
        child.attrib.get('identifier') == 'objng-master-boot' or
        child.attrib.get('title','').startswith('ObjednavkaNG MASTER BOOT')
    ):
        wr.remove(child)
rule=ET.SubElement(wr,'windowRule',{
    'identifier':'objng-master-boot',
    'title':'ObjednavkaNG MASTER BOOT*',
    'matchOnce':'no',
    'fixedPosition':'yes',
})
ET.SubElement(rule,'action',{'name':'MoveTo','x':'0','y':'0'})
for ident, title in (
    ('ObjngTouchTest', 'ObjednavkaNG - test dotyku*'),
    ('ObjngTouchCalibrator', 'ObjednavkaNG - kalibrace 3M touch*'),
):
    for child in list(wr):
        if child.tag == 'windowRule' and child.attrib.get('identifier') == ident:
            wr.remove(child)
    touch_rule=ET.SubElement(wr,'windowRule',{
        'identifier': ident,
        'title': title,
        'matchOnce':'no',
    })
    ET.SubElement(touch_rule,'action',{'name':'ToggleFullscreen'})
    ET.SubElement(touch_rule,'action',{'name':'MoveTo','x':'0','y':'0'})
    ET.SubElement(touch_rule,'action',{'name':'Focus'})
ET.indent(tree, space='  ')
tree.write(p, encoding='utf-8', xml_declaration=True)
PY
chown "$TARGET_USER:$TARGET_GROUP" "$RC"

ln -sfn "$TARGET_HOME/bin/reset-objng-firstboot.sh" /usr/local/bin/reset-objng-firstboot
ln -sfn "$TARGET_HOME/bin/verify-final-state.sh" /usr/local/bin/objng-final-check

# Klavesnice je pred kalibraci vzdy vypnuta.
raspi-config nonint do_squeekboard S3 2>/dev/null || raspi-config nonint do_squeekboard S2 2>/dev/null || true
runuser -u "$TARGET_USER" -- gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false 2>/dev/null || true
pkill -x squeekboard 2>/dev/null || true

# Cisty stav pred vytvorenim IMG. Odstranime i vsechny stare 3M matice,
# aby se na novem klonu nikdy neskladaly dve transformace pres sebe.
rm -f /etc/udev/rules.d/99-objednavka-ng-touchscreen-calibration.rules
rm -f /etc/udev/rules.d/99-objng-3m-calibration.rules
rm -f /etc/udev/rules.d/99-3m-touch-calibration.rules
udevadm control --reload-rules 2>/dev/null || true
rm -rf "$TARGET_HOME/.local/state/objng-master-bootstrap" "$TARGET_HOME/.local/state/objednavka-ng-touch-calibrator"
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$TARGET_HOME/.local/state/objng-master-bootstrap"
rm -rf "$TARGET_HOME/install" "$TARGET_HOME/update"
rm -f /tmp/objng-firstboot-install.lock
rm -f "$TARGET_HOME/objng_firstboot_install.log" "$TARGET_HOME/objng_egtouch_install.log"
chown -R "$TARGET_USER:$TARGET_GROUP" "$TARGET_HOME/bin" "$BOOT_ROOT" "$TARGET_HOME/.config/labwc" "$TARGET_HOME/.local/state/objng-master-bootstrap"

echo
echo "Hotovo. MASTER BOOT v$VERSION je pripraven v IMG."
echo "Pro vytvoreni master IMG bez spusteni firstbootu: sync && sudo poweroff"
echo "POZOR: sudo reboot na master kartu spusti firstboot touch kalibraci."
