#!/usr/bin/env bash
# ObjednĂˇvkaNG OFFLINE Wizard installer â€“ Raspberry Pi OS Desktop / Wayland / labwc
set -Eeuo pipefail

VERSION="0.7.0"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FILES="$ROOT/files"
SCRIPTS="$ROOT/scripts"
DOCS="$ROOT/docs"
APP_SOURCE="$FILES/objednavka-ng.AppImage"
TV_SOURCE="$FILES/teamviewer.deb"
CONFIG_SOURCE="$FILES/config.json"
SPLASH_SOURCE="$FILES/splash-image.tga"
SUMS="$FILES/SHA256SUMS"

TARGET_USER="${OBJNG_USER:-objng}"
HOSTNAME_VALUE="${OBJNG_HOSTNAME:-rpi-pcbox}"
INSTALL_TEAMVIEWER=1
ENABLE_KIOSK=0
APPLY_TOUCH_PRESET=1
INTERACTIVE=1
TV_ASSIGNMENT_ID=""

usage() {
cat <<EOF
PouĹľitĂ­:
  sudo ./install.sh [volby]

PĹ™ed instalacĂ­ vloĹľ do files/:
  objednavka-ng.AppImage
  teamviewer.deb

Volby:
  --user USER            cĂ­lovĂ˝ uĹľivatel; vĂ˝chozĂ­ objng
  --hostname NAME        hostname; vĂ˝chozĂ­ rpi-pcbox
  --enable-kiosk         zapne ÄŤistĂ˝ kiosk pro pĹ™Ă­ĹˇtĂ­ reboot
  --skip-teamviewer      neinstaluje files/teamviewer.deb
  --skip-touch-preset    nenastavĂ­ vĂ˝chozĂ­ matici dotyku 0 -1 1 -1 0 1
  --non-interactive      nepoklĂˇdĂˇ otĂˇzku na TeamViewer Assignment ID
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) TARGET_USER="$2"; shift 2 ;;
    --hostname) HOSTNAME_VALUE="$2"; shift 2 ;;
    --enable-kiosk) ENABLE_KIOSK=1; shift ;;
    --skip-teamviewer) INSTALL_TEAMVIEWER=0; shift ;;
    --skip-touch-preset) APPLY_TOUCH_PRESET=0; shift ;;
    --non-interactive) INTERACTIVE=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "NeznĂˇmĂˇ volba: $1" >&2; usage; exit 1 ;;
  esac
done

[[ "$EUID" -eq 0 ]] || { echo "SpusĹĄ pĹ™es sudo: sudo ./install.sh" >&2; exit 1; }
getent passwd "$TARGET_USER" >/dev/null || {
  echo "CHYBA: uĹľivatel '$TARGET_USER' neexistuje. VytvoĹ™ jej v Raspberry Pi Imageru pĹ™ed prvnĂ­m bootem." >&2
  exit 1
}
[[ -s "$APP_SOURCE" ]] || { echo "CHYBĂŤ: files/objednavka-ng.AppImage" >&2; exit 1; }
if [[ "$INSTALL_TEAMVIEWER" -eq 1 ]]; then
  [[ -s "$TV_SOURCE" ]] || { echo "CHYBĂŤ: files/teamviewer.deb (TeamViewer Full ARM64)" >&2; exit 1; }
  dpkg-deb --info "$TV_SOURCE" >/dev/null 2>&1 || { echo "files/teamviewer.deb nenĂ­ validnĂ­ Debian balĂ­ÄŤek." >&2; exit 1; }
fi
[[ -s "$CONFIG_SOURCE" && -s "$SPLASH_SOURCE" ]] || { echo "ChybĂ­ config.json nebo splash-image.tga." >&2; exit 1; }

if [[ -f "$SUMS" ]]; then
  (cd "$FILES" && sha256sum -c SHA256SUMS)
else
  echo "VAROVĂNĂŤ: files/SHA256SUMS neexistuje. DoporuÄŤuji pĹ™ed instalacĂ­ spustit ./tools/build_SHA256SUMS.sh." >&2
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
APP_DIR="/opt/objednavka-ng"
OPT_SCRIPTS="$APP_DIR/scripts"
OPT_ASSETS="$APP_DIR/assets"
OPT_DOCS="$APP_DIR/docs"
BACKUP="$APP_DIR/backups/install-$(date +%Y%m%d_%H%M%S)"
LOG="/var/log/objng-install.log"
mkdir -p "$APP_DIR" "$OPT_SCRIPTS" "$OPT_ASSETS" "$OPT_DOCS" "$BACKUP"
touch "$LOG"; chmod 0644 "$LOG"
exec > >(tee -a "$LOG") 2>&1
log(){ printf '\n[OBJNG] %s\n' "$*"; }
warn(){ printf '\n[VAROVĂNĂŤ] %s\n' "$*" >&2; }

log "Offline instalace v${VERSION}; user=${TARGET_USER}; hostname=${HOSTNAME_VALUE}"

log "Instaluji zĂˇvislosti ze systĂ©movĂ˝ch repozitĂˇĹ™ĹŻ..."
apt-get update
PACKAGES=(ca-certificates wlrctl kanshi python3-evdev python3-tk libinput-tools)
if apt-cache show rpi-splash-screen-support >/dev/null 2>&1; then PACKAGES+=(rpi-splash-screen-support); fi
if apt-cache show libfuse2t64 >/dev/null 2>&1; then PACKAGES+=(libfuse2t64); elif apt-cache show libfuse2 >/dev/null 2>&1; then PACKAGES+=(libfuse2); fi
DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGES[@]}"

log "ZĂˇlohuji stĂˇvajĂ­cĂ­ nastavenĂ­ a instaluji strukturu /opt/objednavka-ng..."
for old in "$APP_DIR/objednavka-ng.AppImage" "$APP_DIR/config.json" "$APP_DIR/scripts" /etc/xdg/labwc/autostart /boot/firmware/config.txt; do
  [[ -e "$old" || -L "$old" ]] && cp -a "$old" "$BACKUP/" 2>/dev/null || true
done
# Config zapisujeme jeĹˇtÄ› pĹ™ed instalacĂ­/spuĹˇtÄ›nĂ­m aplikace, aby jej aplikace nikdy nevytvoĹ™ila vĂ˝chozĂ­.
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$TARGET_HOME/.config/objednavka-ng"
install -m 0644 -o "$TARGET_USER" -g "$TARGET_GROUP" "$CONFIG_SOURCE" "$TARGET_HOME/.config/objednavka-ng/config.json"
ln -sfn "$TARGET_HOME/.config/objednavka-ng/config.json" "$APP_DIR/config.json"

install -m 0755 "$APP_SOURCE" "$APP_DIR/objednavka-ng.AppImage"
install -m 0644 "$SPLASH_SOURCE" "$OPT_ASSETS/splash-image.tga"

for script in "$SCRIPTS"/*; do
  [[ -f "$script" ]] && install -m 0755 "$script" "$OPT_SCRIPTS/$(basename "$script")"
done
if [[ -d "$DOCS" ]]; then
  for doc in "$DOCS"/*; do [[ -f "$doc" ]] && install -m 0644 "$doc" "$OPT_DOCS/$(basename "$doc")"; done
fi

log "VytvĂˇĹ™Ă­m pĹ™Ă­kazy dostupnĂ© z terminĂˇlu..."
install -d -m 0755 /usr/local/bin /usr/local/sbin
ln -sfn "$OPT_SCRIPTS/gui-on.sh" /usr/local/bin/gui-on
ln -sfn "$OPT_SCRIPTS/gui-off.sh" /usr/local/bin/gui-off
ln -sfn "$OPT_SCRIPTS/kalibrace.sh" /usr/local/bin/kalibrace
ln -sfn "$OPT_SCRIPTS/kiosk-on.sh" /usr/local/bin/kiosk-on
ln -sfn "$OPT_SCRIPTS/kiosk-off.sh" /usr/local/bin/kiosk-off
ln -sfn "$OPT_SCRIPTS/objednavka-kiosk.sh" /usr/local/bin/objednavka-kiosk
ln -sfn "$OPT_SCRIPTS/objednavka-zvetseni.sh" /usr/local/bin/objednavka-zvetseni
for c in zvetseni-on zvetseni-off zvetseni-status zvetseni-restore; do ln -sfn "$OPT_SCRIPTS/objednavka-zvetseni.sh" "/usr/local/bin/$c"; done
ln -sfn "$OPT_SCRIPTS/touch_calibrator_v3.py" /usr/local/bin/touch-calibrator
ln -sfn "$OPT_SCRIPTS/touch-preset.sh" /usr/local/bin/touch-preset
ln -sfn "$OPT_SCRIPTS/nastavit-ctecku.sh" /usr/local/bin/nastavit-ctecku
ln -sfn "$OPT_SCRIPTS/touch-setup.sh" /usr/local/bin/touch-setup
ln -sfn "$OPT_SCRIPTS/teamviewer-dokoncit.sh" /usr/local/bin/teamviewer-dokoncit
ln -sfn "$OPT_SCRIPTS/teamviewer-lokalni-volby.sh" /usr/local/bin/teamviewer-lokalni-volby
ln -sfn "$OPT_SCRIPTS/teamviewer-updates-off.sh" /usr/local/bin/teamviewer-updates-off
ln -sfn "$OPT_SCRIPTS/teamviewer-updates-on.sh" /usr/local/bin/teamviewer-updates-on
ln -sfn "$OPT_SCRIPTS/prvni-spusteni.sh" /usr/local/bin/objng-dokoncit
ln -sfn "$OPT_SCRIPTS/objednavka-kiosk-system-mode.sh" /usr/local/sbin/objednavka-kiosk-system-mode

log "Nastavuji pĹ™Ă­stup k touchscreen zaĹ™Ă­zenĂ­ pro kalibrĂˇtor..."
getent group input >/dev/null 2>&1 || groupadd --system input
usermod -aG input "$TARGET_USER"
cat > /etc/udev/rules.d/98-objednavka-ng-touch-access.rules <<'EOF'
# 3M USB touchscreen
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="0596", ATTRS{idProduct}=="0001", GROUP="input", MODE="0660"
# eGalax virtuĂˇlnĂ­ zaĹ™Ă­zenĂ­ vytvoĹ™enĂ© EETI driverem (hlĂˇsĂ­ se jako pointer)
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="eGalaxTouch Virtual Device for Single*", GROUP="input", MODE="0660"
EOF
chmod 0644 /etc/udev/rules.d/98-objednavka-ng-touch-access.rules
udevadm control --reload-rules
udevadm trigger --subsystem-match=input --action=change || true

if [[ "$APPLY_TOUCH_PRESET" -eq 1 ]]; then
  log "Dotyk: automatickĂ˝ preset je ovÄ›Ĺ™en pouze pro 3M USB panel."
  if libinput list-devices 2>/dev/null | grep -q '3M 3M USB Touchscreen - EX II'; then
    "$OPT_SCRIPTS/touch-preset.sh" apply --no-reboot
  elif libinput list-devices 2>/dev/null | grep -q 'eGalaxTouch Virtual Device for Single'; then
    warn "Nalezen eGalaxTouch (Calibration: n/a); libinput preset se neaplikuje. PouĹľij EETI kalibraci."
  else
    warn "ZnĂˇmĂ˝ touchscreen pĹ™i instalaci nenalezen; pozdÄ›ji spusĹĄ: touch-setup"
  fi
else
  warn "VĂ˝chozĂ­ orientace dotyku pĹ™eskoÄŤena."
fi

log "Kontroluji pĹ™ipojenou sĂ©riovou ÄŤteÄŤku pro SERIAL_READER_PORT..."
if [[ "$INTERACTIVE" -eq 1 && -t 0 ]]; then
  runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" PATH="/usr/local/bin:/usr/bin:/bin" nastavit-ctecku || warn "Cestu ke ÄŤteÄŤce doplĹ pozdÄ›ji pĹ™Ă­kazem: nastavit-ctecku"
else
  runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" PATH="/usr/local/bin:/usr/bin:/bin" nastavit-ctecku --non-interactive || true
fi

log "Nastavuji trvalĂ© zvÄ›tĹˇenĂ­ displeje scale 1.25..."
runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" PATH="/usr/local/bin:/usr/bin:/bin" zvetseni-on || warn "Scale nastav pozdÄ›ji pĹ™Ă­kazem zvetseni-on."

log "Nastavuji boot splash a firmware parametry..."
if command -v configure-splash >/dev/null 2>&1; then
  configure-splash "$OPT_ASSETS/splash-image.tga" || warn "configure-splash selhal; zkontroluj splash ruÄŤnÄ›."
else
  warn "configure-splash nenĂ­ dostupnĂ˝; splash-image.tga je pouze uloĹľen v assets."
fi
BOOTCFG="/boot/firmware/config.txt"; [[ -f "$BOOTCFG" ]] || BOOTCFG="/boot/config.txt"
if [[ -f "$BOOTCFG" ]]; then
  cp -a "$BOOTCFG" "$BACKUP/"
  python3 - "$BOOTCFG" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text()
block="""# >>> OBJEDNAVKANG BOOT SETTINGS >>>
[all]
disable_splash=1
boot_delay_ms=4000
# <<< OBJEDNAVKANG BOOT SETTINGS <<<"""
s=re.sub(r"\n?# >>> OBJEDNAVKANG BOOT SETTINGS >>>.*?# <<< OBJEDNAVKANG BOOT SETTINGS <<<\n?", "\n", s, flags=re.S)
p.write_text(s.rstrip()+"\n\n"+block+"\n")
PY
else
  warn "Nenalezen config.txt; firmware parametry nebyly zapsĂˇny."
fi

log "Nastavuji hostname a Desktop Autologin..."
hostnamectl set-hostname "$HOSTNAME_VALUE"
printf '%s\n' "$HOSTNAME_VALUE" > /etc/hostname
mkdir -p /etc/cloud/cloud.cfg.d
printf 'preserve_hostname: true\n' > /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg
[[ -e /etc/init.d/lightdm ]] || { echo "LightDM nenalezen; pouĹľij Raspberry Pi OS with Desktop." >&2; exit 1; }
env SUDO_USER="$TARGET_USER" raspi-config nonint do_boot_behaviour B4
install -d -m 0755 /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/90-objednavka-ng-autologin.conf <<EOF
[Seat:*]
autologin-user=${TARGET_USER}
autologin-user-timeout=0
EOF
systemctl set-default graphical.target

if [[ "$INSTALL_TEAMVIEWER" -eq 1 ]]; then
  log "Instaluji lokĂˇlnĂ­ TeamViewer Full balĂ­ÄŤek: files/teamviewer.deb..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$TV_SOURCE"
  systemctl enable --now teamviewerd 2>/dev/null || warn "SluĹľbu teamviewerd ovÄ›Ĺ™ ruÄŤnÄ›."
  log "TeamViewer Full je nainstalovanĂ˝; ĂşÄŤet, heslo a preference dokonÄŤĂ­Ĺˇ pĹ™Ă­kazem: teamviewer-dokoncit"
fi

DB_HOST="$(python3 - "$TARGET_HOME/.config/objednavka-ng/config.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1], encoding="utf-8")).get("DATABASE_HOST",""))
PY
)"
[[ -n "$DB_HOST" ]] || warn "DATABASE_HOST je prĂˇzdnĂ˝; doplĹ jej v /opt/objednavka-ng/config.json."

if [[ "$ENABLE_KIOSK" -eq 1 ]]; then
  log "ZapĂ­nĂˇm ÄŤistĂ˝ kiosk pro pĹ™Ă­ĹˇtĂ­ reboot..."
  runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" PATH="/usr/local/bin:/usr/bin:/bin" kiosk-on || warn "Kiosk pozdÄ›ji zapni pĹ™Ă­kazem kiosk-on."
fi

cat <<EOF

============================================================
Instalace dokonÄŤena.

NainstalovĂˇno:
  $APP_DIR/objednavka-ng.AppImage
  $APP_DIR/config.json -> $TARGET_HOME/.config/objednavka-ng/config.json
  $APP_DIR/scripts/
  $APP_DIR/assets/
  $APP_DIR/docs/

Dotyk:
  VĂ˝chozĂ­ smÄ›ry: LIBINPUT_CALIBRATION_MATRIX="0 -1 1 -1 0 1"
  JemnĂ© doladÄ›nĂ­: kalibrace
  PodporovanĂ© profily: 3M USB 0596:0001 / eGalaxTouch Virtual Device for Single

ÄŚteÄŤka:
  Detekce a zĂˇpis do configu: nastavit-ctecku

Po restartu:
  objng-dokoncit

Servis:
  gui-on / gui-off
  kiosk-on / kiosk-off
  objednavka-kiosk status
  touch-preset status / touch-setup
  nastavit-ctecku
  teamviewer-dokoncit
  teamviewer-updates-off / teamviewer-updates-on
  zvetseni-status

ZĂˇloha:
  $BACKUP

DoporuÄŤenĂ˝ dalĹˇĂ­ krok:
  sudo reboot
============================================================
EOF
