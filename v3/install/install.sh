#!/usr/bin/env bash
# ObjednávkaNG OFFLINE Wizard installer – Raspberry Pi OS Desktop / Wayland / labwc
set -Eeuo pipefail

VERSION="0.8.2"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FILES="$ROOT/files"
SCRIPTS="$ROOT/scripts"
DOCS="$ROOT/docs"
APP_SOURCE="$FILES/objednavka-ng.AppImage"
TV_SOURCE="$FILES/teamviewer.deb"
CONFIG_SOURCE="$FILES/config.json"
SPLASH_SOURCE="$FILES/splash-image.tga"
SUMS="$FILES/SHA256SUMS"
EETI_ARCHIVE_NAME="eGTouch_v2.5.13219.L-ma.7z"
EETI_SOURCE="$FILES/drivers/$EETI_ARCHIVE_NAME"

TARGET_USER="${OBJNG_USER:-objng}"
HOSTNAME_VALUE="${OBJNG_HOSTNAME:-rpi-pcbox}"
INSTALL_TEAMVIEWER=1
ENABLE_KIOSK=0
APPLY_TOUCH_PRESET=1
INTERACTIVE=1
ACCEPT_EETI_LICENSE=0

usage() {
cat <<EOF
Použití:
  sudo ./install.sh [volby]

Před instalací vlož do files/:
  objednavka-ng.AppImage
  teamviewer.deb

Volby:
  --user USER            cílový uživatel; výchozí objng
  --hostname NAME        hostname; výchozí rpi-pcbox
  --enable-kiosk         zapne čistý kiosk pro příští reboot
  --skip-teamviewer      neinstaluje files/teamviewer.deb
  --skip-touch-preset    nenastaví výchozí matici pro 3M panel
  --accept-eeti-license  při detekci eGalax povolí automatickou instalaci EETI bez dotazu
  --non-interactive      nepokládá interaktivní otázky v první části

Volitelně pro plně offline instalaci vlož do files/drivers/:
  eGTouch_v2.5.13219.L-ma.7z
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) TARGET_USER="$2"; shift 2 ;;
    --hostname) HOSTNAME_VALUE="$2"; shift 2 ;;
    --enable-kiosk) ENABLE_KIOSK=1; shift ;;
    --skip-teamviewer) INSTALL_TEAMVIEWER=0; shift ;;
    --skip-touch-preset) APPLY_TOUCH_PRESET=0; shift ;;
    --accept-eeti-license) ACCEPT_EETI_LICENSE=1; shift ;;
    --non-interactive) INTERACTIVE=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Neznámá volba: $1" >&2; usage; exit 1 ;;
  esac
done

[[ "$EUID" -eq 0 ]] || { echo "Spusť přes sudo: sudo ./install.sh" >&2; exit 1; }
getent passwd "$TARGET_USER" >/dev/null || {
  echo "CHYBA: uživatel '$TARGET_USER' neexistuje. Vytvoř jej v Raspberry Pi Imageru před prvním bootem." >&2
  exit 1
}
[[ -s "$APP_SOURCE" ]] || { echo "CHYBÍ: files/objednavka-ng.AppImage" >&2; exit 1; }
if [[ "$INSTALL_TEAMVIEWER" -eq 1 ]]; then
  [[ -s "$TV_SOURCE" ]] || { echo "CHYBÍ: files/teamviewer.deb (TeamViewer Full ARM64)" >&2; exit 1; }
  dpkg-deb --info "$TV_SOURCE" >/dev/null 2>&1 || { echo "files/teamviewer.deb není validní Debian balíček." >&2; exit 1; }
fi
[[ -s "$CONFIG_SOURCE" && -s "$SPLASH_SOURCE" ]] || { echo "Chybí config.json nebo splash-image.tga." >&2; exit 1; }

if [[ -f "$SUMS" ]]; then
  (cd "$FILES" && sha256sum -c SHA256SUMS)
else
  echo "VAROVÁNÍ: files/SHA256SUMS neexistuje. Doporučuji před instalací spustit ./tools/build_SHA256SUMS.sh." >&2
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
APP_DIR="/opt/objednavka-ng"
OPT_SCRIPTS="$APP_DIR/scripts"
OPT_ASSETS="$APP_DIR/assets"
OPT_DOCS="$APP_DIR/docs"
OPT_VENDOR="$APP_DIR/vendor/eeti"
BACKUP="$APP_DIR/backups/install-$(date +%Y%m%d_%H%M%S)"
LOG="/var/log/objng-install.log"
mkdir -p "$APP_DIR" "$OPT_SCRIPTS" "$OPT_ASSETS" "$OPT_DOCS" "$OPT_VENDOR" "$BACKUP"
touch "$LOG"; chmod 0644 "$LOG"
exec > >(tee -a "$LOG") 2>&1
log(){ printf '\n[OBJNG] %s\n' "$*"; }
warn(){ printf '\n[VAROVÁNÍ] %s\n' "$*" >&2; }

log "Offline instalace v${VERSION}; user=${TARGET_USER}; hostname=${HOSTNAME_VALUE}"

log "Instaluji závislosti ze systémových repozitářů..."
apt-get update
PACKAGES=(ca-certificates wget p7zip-full usbutils lxterminal wlrctl kanshi python3-evdev python3-tk libinput-tools)
if apt-cache show rpi-splash-screen-support >/dev/null 2>&1; then PACKAGES+=(rpi-splash-screen-support); fi
if apt-cache show libfuse2t64 >/dev/null 2>&1; then PACKAGES+=(libfuse2t64); elif apt-cache show libfuse2 >/dev/null 2>&1; then PACKAGES+=(libfuse2); fi
DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGES[@]}"

log "Zálohuji stávající nastavení a instaluji strukturu /opt/objednavka-ng..."
for old in "$APP_DIR/objednavka-ng.AppImage" "$APP_DIR/config.json" "$APP_DIR/scripts" /etc/xdg/labwc/autostart /boot/firmware/config.txt; do
  [[ -e "$old" || -L "$old" ]] && cp -a "$old" "$BACKUP/" 2>/dev/null || true
done
# Config zapisujeme ještě před instalací/spuštěním aplikace, aby jej aplikace nikdy nevytvořila výchozí.
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
if [[ -s "$EETI_SOURCE" ]]; then
  install -m 0644 "$EETI_SOURCE" "$OPT_VENDOR/$EETI_ARCHIVE_NAME"
  log "Přibalen offline EETI driver: $OPT_VENDOR/$EETI_ARCHIVE_NAME"
else
  warn "Offline EETI archiv není v files/drivers/. Při nalezení eGalax jej instalátor stáhne z oficiálního webu EETI."
fi

log "Vytvářím příkazy dostupné z terminálu..."
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
ln -sfn "$OPT_SCRIPTS/nastavit-connection.sh" /usr/local/bin/nastavit-connection
ln -sfn "$OPT_SCRIPTS/objednavka-autostart.sh" /usr/local/bin/objednavka-autostart
ln -sfn "$OPT_SCRIPTS/kiosk-mode.sh" /usr/local/bin/kiosk-mode
ln -sfn "$OPT_SCRIPTS/install-egalax-eeti.sh" /usr/local/sbin/install-egalax-eeti
ln -sfn "$OPT_SCRIPTS/teamviewer-dokoncit.sh" /usr/local/bin/teamviewer-dokoncit
ln -sfn "$OPT_SCRIPTS/teamviewer-lokalni-volby.sh" /usr/local/bin/teamviewer-lokalni-volby
ln -sfn "$OPT_SCRIPTS/teamviewer-updates-off.sh" /usr/local/bin/teamviewer-updates-off
ln -sfn "$OPT_SCRIPTS/teamviewer-updates-on.sh" /usr/local/bin/teamviewer-updates-on
ln -sfn "$OPT_SCRIPTS/prvni-spusteni.sh" /usr/local/bin/objng-dokoncit
ln -sfn "$OPT_SCRIPTS/objednavka-kiosk-system-mode.sh" /usr/local/sbin/objednavka-kiosk-system-mode

log "Nastavuji přístup k touchscreen zařízení pro kalibraci..."
getent group input >/dev/null 2>&1 || groupadd --system input
usermod -aG input "$TARGET_USER"
cat > /etc/udev/rules.d/98-objednavka-ng-touch-access.rules <<'EOF'
# 3M USB touchscreen pro vlastní fullscreen kalibrátor
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="0596", ATTRS{idProduct}=="0001", GROUP="input", MODE="0660"
# eGalax fyzický controller; při EETI instalaci se navíc vytvoří virtuální zařízení
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="0eef", ATTRS{idProduct}=="0001", GROUP="input", MODE="0660"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="eGalaxTouch Virtual Device for Single*", GROUP="input", MODE="0660"
EOF
chmod 0644 /etc/udev/rules.d/98-objednavka-ng-touch-access.rules
udevadm control --reload-rules
udevadm trigger --subsystem-match=input --action=change || true

if lsusb 2>/dev/null | grep -qi '0eef:0001'; then
  log "Dotyk: nalezen eGalax 0eef:0001; pro tento panel je ověřen oficiální EETI eGTouch + eCalib."
  INSTALL_EETI=0
  if command -v eCalib >/dev/null 2>&1; then
    log "EETI eCalib už je nainstalovaný."
  elif [[ "$ACCEPT_EETI_LICENSE" -eq 1 ]]; then
    INSTALL_EETI=1
  elif [[ "$INTERACTIVE" -eq 1 && -t 0 ]]; then
    echo "EETI driver má vlastní licenční prohlášení, které bylo při testu ručně potvrzeno."
    read -r -p "Nainstalovat oficiální EETI driver pro eGalax a přijmout jeho licenční prohlášení? [A/n] " eeti_ans
    [[ "${eeti_ans:-A}" =~ ^[AaYy]$ ]] && INSTALL_EETI=1 || true
  else
    warn "eGalax nalezen, ale EETI nebyl automaticky instalován. Spusť později: sudo install-egalax-eeti && sudo reboot"
  fi
  if [[ "$INSTALL_EETI" -eq 1 ]]; then
    /usr/local/sbin/install-egalax-eeti --accept-license --no-reboot || warn "Instalace EETI selhala; po rebootu ověř touch ručně."
  fi
elif lsusb 2>/dev/null | grep -qi '0596:0001'; then
  log "Dotyk: nalezen 3M USB 0596:0001."
  if [[ "$APPLY_TOUCH_PRESET" -eq 1 ]]; then
    "$OPT_SCRIPTS/touch-preset.sh" apply --no-reboot
  else
    warn "Výchozí orientace 3M byla přeskočena; použij později: kalibrace"
  fi
else
  warn "Známý touchscreen při instalaci nenalezen; později použij: touch-setup nebo kalibrace"
fi

log "Kontroluji připojenou sériovou čtečku pro SERIAL_READER_PORT..."
if [[ "$INTERACTIVE" -eq 1 && -t 0 ]]; then
  runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" PATH="/usr/local/bin:/usr/bin:/bin" nastavit-ctecku || warn "Cestu ke čtečce doplň později příkazem: nastavit-ctecku"
else
  runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" PATH="/usr/local/bin:/usr/bin:/bin" nastavit-ctecku --non-interactive || true
fi

log "Nastavuji trvalé zvětšení displeje scale 1.25..."
runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" PATH="/usr/local/bin:/usr/bin:/bin" zvetseni-on || warn "Scale nastav později příkazem zvetseni-on."

log "Nastavuji boot splash a firmware parametry..."
if command -v configure-splash >/dev/null 2>&1; then
  configure-splash "$OPT_ASSETS/splash-image.tga" || warn "configure-splash selhal; zkontroluj splash ručně."
else
  warn "configure-splash není dostupný; splash-image.tga je pouze uložen v assets."
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
  warn "Nenalezen config.txt; firmware parametry nebyly zapsány."
fi

log "Nastavuji hostname a Desktop Autologin..."
hostnamectl set-hostname "$HOSTNAME_VALUE"
printf '%s\n' "$HOSTNAME_VALUE" > /etc/hostname
mkdir -p /etc/cloud/cloud.cfg.d
printf 'preserve_hostname: true\n' > /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg
[[ -e /etc/init.d/lightdm ]] || { echo "LightDM nenalezen; použij Raspberry Pi OS with Desktop." >&2; exit 1; }
env SUDO_USER="$TARGET_USER" raspi-config nonint do_boot_behaviour B4
install -d -m 0755 /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/90-objednavka-ng-autologin.conf <<EOF
[Seat:*]
autologin-user=${TARGET_USER}
autologin-user-timeout=0
EOF
systemctl set-default graphical.target

if [[ "$INSTALL_TEAMVIEWER" -eq 1 ]]; then
  log "Instaluji lokální TeamViewer Full balíček: files/teamviewer.deb..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$TV_SOURCE"
  systemctl enable --now teamviewerd 2>/dev/null || warn "Službu teamviewerd ověř ručně."
  log "TeamViewer Full je nainstalovaný; automatické přiřazení do správné skupiny později provedeš přes Assignment ID příkazem: teamviewer-dokoncit"
fi

DB_HOST="$(python3 - "$TARGET_HOME/.config/objednavka-ng/config.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1], encoding="utf-8")).get("DATABASE_HOST",""))
PY
)"
[[ -n "$DB_HOST" ]] || warn "DATABASE_HOST je prázdný; doplň jej v /opt/objednavka-ng/config.json."

log "Připravuji automatické spuštění druhé části instalace po prvním rebootu..."
FIRSTBOOT_STATE="$TARGET_HOME/.local/state/objednavka-ng"
FIRSTBOOT_AUTO="$TARGET_HOME/.config/labwc/autostart"
FIRSTBOOT_TMP="$(mktemp)"
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$FIRSTBOOT_STATE" "$(dirname "$FIRSTBOOT_AUTO")"
install -m 0644 -o "$TARGET_USER" -g "$TARGET_GROUP" /dev/null "$FIRSTBOOT_STATE/firstboot.pending"
touch "$FIRSTBOOT_AUTO"
chown "$TARGET_USER:$TARGET_GROUP" "$FIRSTBOOT_AUTO"

# Odeber předchozí OBJNG firstboot blok, pokud instalaci opakujeme, a bezpečně jej zapiš znovu.
awk '
  /# >>> OBJEDNAVKA-NG-FIRSTBOOT >>>/ { skip=1; next }
  /# <<< OBJEDNAVKA-NG-FIRSTBOOT <<</ { skip=0; next }
  !skip { print }
' "$FIRSTBOOT_AUTO" > "$FIRSTBOOT_TMP"
cat >> "$FIRSTBOOT_TMP" <<'EOF'

# >>> OBJEDNAVKA-NG-FIRSTBOOT >>>
/opt/objednavka-ng/scripts/firstboot-launcher.sh &
# <<< OBJEDNAVKA-NG-FIRSTBOOT <<<
EOF
install -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$FIRSTBOOT_TMP" "$FIRSTBOOT_AUTO"
rm -f "$FIRSTBOOT_TMP"
if [[ "$ENABLE_KIOSK" -eq 1 ]]; then
  warn "Volba --enable-kiosk se nyní neaplikuje před dokončením. Kiosk vybereš bezpečně v automatické druhé části po rebootu."
fi

cat <<EOF

============================================================
Instalace dokončena.

Nainstalováno:
  $APP_DIR/objednavka-ng.AppImage
  $APP_DIR/config.json -> $TARGET_HOME/.config/objednavka-ng/config.json
  $APP_DIR/scripts/
  $APP_DIR/assets/
  $APP_DIR/docs/

Dotyk:
  Příkaz kdykoliv později: kalibrace
  eGalax 0eef:0001 -> oficiální EETI eCalib (ověřeno na čistém OS)
  3M 0596:0001    -> vlastní fullscreen kalibrátor + libinput profil

Čtečka:
  Detekce a zápis do configu: nastavit-ctecku

Po restartu:
  Dokončovací průvodce se otevře automaticky v terminálu na displeji.
  Nouzové ruční spuštění: objng-dokoncit

Servis:
  gui-on / gui-off
  kiosk-on / kiosk-off
  objednavka-kiosk status
  touch-preset status / touch-setup / kalibrace
  nastavit-connection / nastavit-ctecku
  kiosk-mode on|off / objednavka-autostart on|off
  teamviewer-dokoncit
  teamviewer-updates-off / teamviewer-updates-on
  zvetseni-status

Záloha:
  $BACKUP

Doporučený další krok:
  sudo reboot
============================================================
EOF
