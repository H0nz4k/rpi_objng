#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q # Local/offline core install for ObjednavkaNG MASTER BOOT FINAL v2.1.7
set -Eeuo pipefail

VERSION="2.1.7"
TARGET_USER="${OBJNG_USER:-objng}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
PAYLOAD="${OBJNG_PAYLOAD:-$TARGET_HOME/bootstrap/v2/payload}"
APP_SRC="$PAYLOAD/app/objednavka-ng.AppImage"
CONFIG_SRC="$PAYLOAD/config/config.json"
SPLASH_SRC="$PAYLOAD/assets/splash-image.tga"
SCRIPTS_SRC="$PAYLOAD/scripts"
EETI_SRC="$PAYLOAD/drivers/eGTouch_v2.5.13219.L-ma.7z"
APP_DIR="/opt/objednavka-ng"
OPT_SCRIPTS="$APP_DIR/scripts"
OPT_ASSETS="$APP_DIR/assets"
OPT_DOCS="$APP_DIR/docs"
OPT_VENDOR="$APP_DIR/vendor/eeti"
CONFIG_REAL="$TARGET_HOME/.config/objednavka-ng/config.json"
DESKTOP="$TARGET_HOME/Desktop"
BACKUP="$APP_DIR/backups/core-$(date +%Y%m%d_%H%M%S)"

[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo." >&2; exit 1; }
[[ -s "$APP_SRC" ]] || { echo "CHYBI AppImage: $APP_SRC" >&2; exit 1; }
[[ -s "$CONFIG_SRC" ]] || { echo "CHYBI config: $CONFIG_SRC" >&2; exit 1; }
[[ -d "$SCRIPTS_SRC" ]] || { echo "CHYBI scripts: $SCRIPTS_SRC" >&2; exit 1; }

log(){ printf '\n[CORE v%s] %s\n' "$VERSION" "$*"; }

log "Instaluji lokalni jadro ObjednavkaNG."
mkdir -p "$APP_DIR" "$OPT_SCRIPTS" "$OPT_ASSETS" "$OPT_DOCS" "$OPT_VENDOR" "$BACKUP"
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$TARGET_HOME/.config/objednavka-ng" "$DESKTOP"

if [[ -f "$CONFIG_REAL" ]]; then
  cp -a "$CONFIG_REAL" "$BACKUP/config.json"
  log "Existujici config zachovan."
else
  install -m 0644 -o "$TARGET_USER" -g "$TARGET_GROUP" "$CONFIG_SRC" "$CONFIG_REAL"
  log "Nainstalovan vychozi config."
fi
ln -sfn "$CONFIG_REAL" "$APP_DIR/config.json"

install -m 0755 "$APP_SRC" "$APP_DIR/objednavka-ng.AppImage"
[[ -s "$SPLASH_SRC" ]] && install -m 0644 "$SPLASH_SRC" "$OPT_ASSETS/splash-image.tga"

for script in "$SCRIPTS_SRC"/*.sh; do
  [[ -f "$script" ]] || continue
  install -m 0755 "$script" "$OPT_SCRIPTS/$(basename "$script")"
done
install -m 0755 "$TARGET_HOME/bin/touch_calibrator_v3.py" "$OPT_SCRIPTS/touch_calibrator_v3.py"
install -m 0755 "$TARGET_HOME/bin/touch-bootstrap.sh" "$OPT_SCRIPTS/touch-bootstrap.sh"
install -m 0755 "$TARGET_HOME/bin/touch-test.py" "$OPT_SCRIPTS/touch-test.py"
install -m 0755 "$TARGET_HOME/bin/teamviewer-postinstall.sh" "$OPT_SCRIPTS/teamviewer-postinstall.sh"

if [[ -s "$EETI_SRC" ]]; then
  install -m 0644 "$EETI_SRC" "$OPT_VENDOR/$(basename "$EETI_SRC")"
fi

install -d -m 0755 /usr/local/bin /usr/local/sbin
ln -sfn "$OPT_SCRIPTS/gui-on.sh" /usr/local/bin/gui-on
ln -sfn "$OPT_SCRIPTS/gui-off.sh" /usr/local/bin/gui-off
ln -sfn "$OPT_SCRIPTS/kalibrace.sh" /usr/local/bin/kalibrace
ln -sfn "$OPT_SCRIPTS/kiosk-on.sh" /usr/local/bin/kiosk-on
ln -sfn "$OPT_SCRIPTS/kiosk-off.sh" /usr/local/bin/kiosk-off
ln -sfn "$OPT_SCRIPTS/objednavka-kiosk.sh" /usr/local/bin/objednavka-kiosk
ln -sfn "$OPT_SCRIPTS/objednavka-zvetseni.sh" /usr/local/bin/objednavka-zvetseni
for cmd in zvetseni-on zvetseni-off zvetseni-status zvetseni-restore; do
  ln -sfn "$OPT_SCRIPTS/objednavka-zvetseni.sh" "/usr/local/bin/$cmd"
done
ln -sfn "$OPT_SCRIPTS/touch_calibrator_v3.py" /usr/local/bin/touch-calibrator
ln -sfn "$OPT_SCRIPTS/touch-preset.sh" /usr/local/bin/touch-preset
ln -sfn "$OPT_SCRIPTS/touch-setup.sh" /usr/local/bin/touch-setup
ln -sfn "$OPT_SCRIPTS/nastavit-connection.sh" /usr/local/bin/nastavit-connection
ln -sfn "$OPT_SCRIPTS/nastavit-ctecku.sh" /usr/local/bin/nastavit-ctecku
ln -sfn "$OPT_SCRIPTS/kiosk-mode.sh" /usr/local/bin/kiosk-mode
ln -sfn "$OPT_SCRIPTS/objednavka-autostart.sh" /usr/local/bin/objednavka-autostart
ln -sfn "$OPT_SCRIPTS/teamviewer-dokoncit.sh" /usr/local/bin/teamviewer-dokoncit
ln -sfn "$OPT_SCRIPTS/teamviewer-postinstall.sh" /usr/local/bin/teamviewer-postinstall
ln -sfn "$OPT_SCRIPTS/teamviewer-lokalni-volby.sh" /usr/local/bin/teamviewer-lokalni-volby
ln -sfn "$OPT_SCRIPTS/teamviewer-updates-off.sh" /usr/local/bin/teamviewer-updates-off
ln -sfn "$OPT_SCRIPTS/teamviewer-updates-on.sh" /usr/local/bin/teamviewer-updates-on
ln -sfn "$TARGET_HOME/bin/firstboot-install.sh" /usr/local/bin/objng-dokoncit
ln -sfn "$OPT_SCRIPTS/objednavka-kiosk-system-mode.sh" /usr/local/sbin/objednavka-kiosk-system-mode
ln -sfn "$TARGET_HOME/bin/install-egalax-eeti-bootstrap.sh" /usr/local/sbin/install-egalax-eeti

# Touch access permissions used by both service calibration paths.
getent group input >/dev/null 2>&1 || groupadd --system input
usermod -aG input "$TARGET_USER"
cat > /etc/udev/rules.d/98-objednavka-ng-touch-access.rules <<'EOF'
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="0596", ATTRS{idProduct}=="0001", GROUP="input", MODE="0660"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="0eef", ATTRS{idProduct}=="0001", GROUP="input", MODE="0660"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="eGalaxTouch Virtual Device for Single*", GROUP="input", MODE="0660"
EOF
chmod 0644 /etc/udev/rules.d/98-objednavka-ng-touch-access.rules
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger --subsystem-match=input --action=change 2>/dev/null || true

# Splash is installed only after the touch calibration/test has succeeded.
if [[ -s "$OPT_ASSETS/splash-image.tga" ]]; then
  if command -v configure-splash >/dev/null 2>&1; then
    configure-splash "$OPT_ASSETS/splash-image.tga" || true
  fi
fi
BOOTCFG="/boot/firmware/config.txt"; [[ -f "$BOOTCFG" ]] || BOOTCFG="/boot/config.txt"
if [[ -f "$BOOTCFG" ]]; then
  python3 - "$BOOTCFG" <<'PY'
from pathlib import Path
import re, sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8', errors='replace')
block='''# >>> OBJEDNAVKANG BOOT SETTINGS >>>
[all]
disable_splash=1
boot_delay_ms=4000
# <<< OBJEDNAVKANG BOOT SETTINGS <<<'''
s=re.sub(r'\n?# >>> OBJEDNAVKANG BOOT SETTINGS >>>.*?# <<< OBJEDNAVKANG BOOT SETTINGS <<<\n?', '\n', s, flags=re.S)
p.write_text(s.rstrip()+'\n\n'+block+'\n', encoding='utf-8')
PY
fi

# Hostname + desktop autologin. Toto se nastavi uz v master IMG a znovu overi pri instalaci jadra.
hostnamectl set-hostname "${OBJNG_HOSTNAME:-rpi-pcbox}"
printf '%s\n' "${OBJNG_HOSTNAME:-rpi-pcbox}" > /etc/hostname
if command -v raspi-config >/dev/null 2>&1; then
  env SUDO_USER="$TARGET_USER" raspi-config nonint do_boot_behaviour B4
fi
install -d -m 0755 /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/90-objednavka-ng-autologin.conf <<EOF
[Seat:*]
autologin-user=$TARGET_USER
autologin-user-timeout=0
EOF
systemctl set-default graphical.target
systemctl enable lightdm.service
grep -q "^autologin-user=$TARGET_USER$" /etc/lightdm/lightdm.conf.d/90-objednavka-ng-autologin.conf

cat > "$OPT_DOCS/SERVISNI_PRIKAZY.txt" <<'EOF'
OBJEDNÁVKANG - SERVISNÍ PŘÍKAZY
================================

Tento soubor je také na ploše jako zástupce: Příkazy OBJNG
Trvalá dokumentace v: /opt/objednavka-ng/docs/


BĚŽNÁ OBSLUHA
=============

Příkaz                  Funkce
----------------------  ------------------------------------------------------------
kalibrace               Automaticky rozezná touch panel. eGalax spustí přes eCalib,
                        3M přes fullscreen kalibrátor.

nastavit-connection     Nastaví IP databáze, port, název DB a název PCBOX.

nastavit-ctecku         Najde připojenou čtečku a uloží její port do konfigurace.

objng-dokoncit          Ručně spustí instalačního průvodce, pokud se po rebootu
                        neotevřel automaticky.


KIOSK REŽIM A AUTOMATICKÉ SPUŠTĚNÍ APLIKACE
============================================

Příkaz                          Funkce
------------------------------  ------------------------------------------------------------
kiosk-mode on                   Skryje desktop a panel po dalším startu; samotnou
                                aplikaci automaticky nespouští.

kiosk-mode off                  Vrátí běžný desktop a panel po dalším startu.

kiosk-mode status               Zobrazí, zda je čistý kiosk desktop zapnutý.

objednavka-autostart on         Zapne automatické spuštění aplikace ObjednávkaNG
                                po přihlášení.

objednavka-autostart off        Vypne automatické spuštění aplikace.

objednavka-autostart status     Zobrazí stav automatického spouštění aplikace.

kiosk-on                        Zapne čistý kiosk režim i automatické spuštění
                                aplikace pro další start.

kiosk-off                       Vypne kiosk režim i automatické spuštění aplikace
                                pro další start.

kiosk-on --now                  Zapne kiosk režim a spustí jej také ihned v aktuální
                                relaci.

kiosk-off --now                 Vypne kiosk, zavře aplikaci a zobrazí desktop také
                                ihned.


ZOBRAZENÍ A TEAMVIEWER
======================

Příkaz                  Funkce
----------------------  ------------------------------------------------------------
zvetseni-on             Zapne trvalé zvětšení 125 % přes kanshi.

zvetseni-off            Vrátí nativní měřítko 100 %.

zvetseni-status         Zobrazí aktivní výstup a scale.

zvetseni-restore        Obnoví původní kanshi konfiguraci ze zálohy.

teamviewer-postinstall  Vždy po instalaci: čeština, LAN, apt hold, alias, heslo ze secret.

teamviewer-dokoncit     Přiřazení do TeamViewer správy (Assignment ID ze secret).

teamviewer-lokalni-volby preview|apply|restore
                        Ruční patch jazyka/LAN/alias v global.conf.

teamviewer-updates-off  Zablokuje apt aktualizace balíčku TeamVieweru.

teamviewer-updates-on   Znovu povolí apt aktualizace TeamVieweru.

objng-final-check       Ověří TeamViewer, autologin, scale, kiosk a autostart
                        aplikace.


GUI A OSTATNÍ
=============

Příkaz                  Funkce
----------------------  ------------------------------------------------------------
gui-on                  Ihned zobrazí plochu a panel (boot režim nemění).

gui-off                 Ihned skryje plochu a panel (boot režim nemění).

reset-objng-firstboot   Resetuje celý MASTER BOOT proces od kalibrace touch.

touch-setup             Průvodce detekcí touch panelu a kalibrací.

touch-preset            Výchozí orientace 3M panelu před kalibrací.
EOF

cat > "$OPT_DOCS/INFO_OBJNG.txt" <<'EOF'
OBJEDNÁVKANG - SERVISNÍ DOKUMENTACE
===================================

Trvalá dokumentace je v adresáři:
  /opt/objednavka-ng/docs/

Soubory:
  SERVISNI_PRIKAZY.txt   Přehled servisních příkazů (příkaz → funkce)
  INFO_OBJNG.txt         Tento soubor

Na ploše jsou zástupce:
  Config OBJNG           Otevře config aplikace
  Příkazy OBJNG          Otevře SERVISNI_PRIKAZY.txt

TeamViewer secret soubory (volitelné, mimo veřejný Git):
  /home/objng/bootstrap/v2/secrets/teamviewer-assignment-id
  /home/objng/bootstrap/v2/secrets/teamviewer-password
  /home/objng/bootstrap/v2/secrets/teamviewer-alias
EOF

SERVISNI_DOC="$OPT_DOCS/SERVISNI_PRIKAZY.txt"

open_editor_cmd() {
  # Vrati prikaz pro otevreni souboru v textovem editoru (mousepad -> gedit -> kate -> nano v terminalu).
  echo 'sh -c '"'"'for e in mousepad gedit kate leafpad xed; do command -v "$e" >/dev/null 2>&1 && exec "$e" "$@"; done; foot nano "$@" 2>/dev/null || lxterminal -e nano "$@"'"'"' -- '
}
OPEN_EDITOR="$(open_editor_cmd)"

cat > "$DESKTOP/Config OBJNG.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Config OBJNG
Comment=Otevřít konfiguraci aplikace ObjednávkaNG
Exec=${OPEN_EDITOR}"$CONFIG_REAL"
Icon=accessories-text-editor
Terminal=false
Categories=Utility;
EOF
chmod 0755 "$DESKTOP/Config OBJNG.desktop"

cat > "$DESKTOP/Prikazy OBJNG.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Příkazy OBJNG
Comment=Servisní příkazy ObjednávkaNG
Exec=${OPEN_EDITOR}"$SERVISNI_DOC"
Icon=accessories-text-editor
Terminal=false
Categories=Utility;
EOF
chmod 0755 "$DESKTOP/Prikazy OBJNG.desktop"

ln -sfn "$SERVISNI_DOC" "$DESKTOP/Prikazy OBJNG.txt"
ln -sfn "$OPT_DOCS/INFO_OBJNG.txt" "$DESKTOP/Info OBJNG.txt"

cat > "$DESKTOP/Info OBJNG.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Info OBJNG
Comment=Informace a cesty k servisni dokumentaci
Exec=${OPEN_EDITOR}"$OPT_DOCS/INFO_OBJNG.txt"
Icon=help-about
Terminal=false
Categories=Utility;
EOF
chmod 0755 "$DESKTOP/Info OBJNG.desktop"

# Wrapper pro kalibraci – potrebuje DISPLAY/XAUTHORITY a spusti foot terminal.
TOUCH_WRAPPER="$TARGET_HOME/bin/touch-gui-launcher.sh"
cat > "$TOUCH_WRAPPER" <<'WRAPPER'
#!/usr/bin/env bash
# Spusti kalibrace nebo touch-test v terminalu s DISPLAY/XAUTHORITY.
MODE="${1:-calibrate}"
DISPLAY="${DISPLAY:-:0}"
XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
export DISPLAY XAUTHORITY

run_in_term() {
  if command -v foot >/dev/null 2>&1; then
    foot -T "ObjednavkaNG - $1" -- bash -c "$2; echo; read -rsp 'Stiskni Enter pro zavřeni...' _" &
  elif command -v lxterminal >/dev/null 2>&1; then
    lxterminal --title="ObjednavkaNG - $1" -e bash -c "$2; echo; read -rsp 'Stiskni Enter pro zavřeni...' _" &
  else
    bash -c "$2" &
  fi
}

case "$MODE" in
  calibrate)
    run_in_term "Kalibrace touch" "kalibrace"
    ;;
  test)
    run_in_term "Test touch" "env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY python3 /home/objng/bin/touch-test.py"
    ;;
esac
WRAPPER
chmod 0755 "$TOUCH_WRAPPER"
chown "$TARGET_USER:$TARGET_GROUP" "$TOUCH_WRAPPER"

cat > "$DESKTOP/Kalibrace touch.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Kalibrace touch
Comment=Spustí kalibraci dotykového panelu (3M nebo eGalax)
Exec=$TOUCH_WRAPPER calibrate
Icon=input-touchpad
Terminal=false
Categories=Utility;
EOF
chmod 0755 "$DESKTOP/Kalibrace touch.desktop"

cat > "$DESKTOP/Test touch.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Test touch
Comment=Fullscreen 4-bodový test dotykového panelu
Exec=$TOUCH_WRAPPER test
Icon=input-touchpad
Terminal=false
Categories=Utility;
EOF
chmod 0755 "$DESKTOP/Test touch.desktop"

chown -R "$TARGET_USER:$TARGET_GROUP" "$DESKTOP" "$OPT_DOCS" "$TARGET_HOME/.config/objednavka-ng"

log "Lokalni jadro je nainstalovane. Config nebyl pri opakovani prepsan."
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
# Local/offline core install for ObjednavkaNG MASTER BOOT FINAL v2.1.7
set -Eeuo pipefail

VERSION="2.1.7"
TARGET_USER="${OBJNG_USER:-objng}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
PAYLOAD="${OBJNG_PAYLOAD:-$TARGET_HOME/bootstrap/v2/payload}"
APP_SRC="$PAYLOAD/app/objednavka-ng.AppImage"
CONFIG_SRC="$PAYLOAD/config/config.json"
SPLASH_SRC="$PAYLOAD/assets/splash-image.tga"
SCRIPTS_SRC="$PAYLOAD/scripts"
EETI_SRC="$PAYLOAD/drivers/eGTouch_v2.5.13219.L-ma.7z"
APP_DIR="/opt/objednavka-ng"
OPT_SCRIPTS="$APP_DIR/scripts"
OPT_ASSETS="$APP_DIR/assets"
OPT_DOCS="$APP_DIR/docs"
OPT_VENDOR="$APP_DIR/vendor/eeti"
CONFIG_REAL="$TARGET_HOME/.config/objednavka-ng/config.json"
DESKTOP="$TARGET_HOME/Desktop"
BACKUP="$APP_DIR/backups/core-$(date +%Y%m%d_%H%M%S)"

[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo." >&2; exit 1; }
[[ -s "$APP_SRC" ]] || { echo "CHYBI AppImage: $APP_SRC" >&2; exit 1; }
[[ -s "$CONFIG_SRC" ]] || { echo "CHYBI config: $CONFIG_SRC" >&2; exit 1; }
[[ -d "$SCRIPTS_SRC" ]] || { echo "CHYBI scripts: $SCRIPTS_SRC" >&2; exit 1; }

log(){ printf '\n[CORE v%s] %s\n' "$VERSION" "$*"; }

log "Instaluji lokalni jadro ObjednavkaNG."
mkdir -p "$APP_DIR" "$OPT_SCRIPTS" "$OPT_ASSETS" "$OPT_DOCS" "$OPT_VENDOR" "$BACKUP"
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$TARGET_HOME/.config/objednavka-ng" "$DESKTOP"

if [[ -f "$CONFIG_REAL" ]]; then
  cp -a "$CONFIG_REAL" "$BACKUP/config.json"
  log "Existujici config zachovan."
else
  install -m 0644 -o "$TARGET_USER" -g "$TARGET_GROUP" "$CONFIG_SRC" "$CONFIG_REAL"
  log "Nainstalovan vychozi config."
fi
ln -sfn "$CONFIG_REAL" "$APP_DIR/config.json"

install -m 0755 "$APP_SRC" "$APP_DIR/objednavka-ng.AppImage"
[[ -s "$SPLASH_SRC" ]] && install -m 0644 "$SPLASH_SRC" "$OPT_ASSETS/splash-image.tga"

for script in "$SCRIPTS_SRC"/*.sh; do
  [[ -f "$script" ]] || continue
  install -m 0755 "$script" "$OPT_SCRIPTS/$(basename "$script")"
done
install -m 0755 "$TARGET_HOME/bin/touch_calibrator_v3.py" "$OPT_SCRIPTS/touch_calibrator_v3.py"
install -m 0755 "$TARGET_HOME/bin/touch-bootstrap.sh" "$OPT_SCRIPTS/touch-bootstrap.sh"
install -m 0755 "$TARGET_HOME/bin/touch-test.py" "$OPT_SCRIPTS/touch-test.py"
install -m 0755 "$TARGET_HOME/bin/teamviewer-postinstall.sh" "$OPT_SCRIPTS/teamviewer-postinstall.sh"

if [[ -s "$EETI_SRC" ]]; then
  install -m 0644 "$EETI_SRC" "$OPT_VENDOR/$(basename "$EETI_SRC")"
fi

install -d -m 0755 /usr/local/bin /usr/local/sbin
ln -sfn "$OPT_SCRIPTS/gui-on.sh" /usr/local/bin/gui-on
ln -sfn "$OPT_SCRIPTS/gui-off.sh" /usr/local/bin/gui-off
ln -sfn "$OPT_SCRIPTS/kalibrace.sh" /usr/local/bin/kalibrace
ln -sfn "$OPT_SCRIPTS/kiosk-on.sh" /usr/local/bin/kiosk-on
ln -sfn "$OPT_SCRIPTS/kiosk-off.sh" /usr/local/bin/kiosk-off
ln -sfn "$OPT_SCRIPTS/objednavka-kiosk.sh" /usr/local/bin/objednavka-kiosk
ln -sfn "$OPT_SCRIPTS/objednavka-zvetseni.sh" /usr/local/bin/objednavka-zvetseni
for cmd in zvetseni-on zvetseni-off zvetseni-status zvetseni-restore; do
  ln -sfn "$OPT_SCRIPTS/objednavka-zvetseni.sh" "/usr/local/bin/$cmd"
done
ln -sfn "$OPT_SCRIPTS/touch_calibrator_v3.py" /usr/local/bin/touch-calibrator
ln -sfn "$OPT_SCRIPTS/touch-preset.sh" /usr/local/bin/touch-preset
ln -sfn "$OPT_SCRIPTS/touch-setup.sh" /usr/local/bin/touch-setup
ln -sfn "$OPT_SCRIPTS/nastavit-connection.sh" /usr/local/bin/nastavit-connection
ln -sfn "$OPT_SCRIPTS/nastavit-ctecku.sh" /usr/local/bin/nastavit-ctecku
ln -sfn "$OPT_SCRIPTS/kiosk-mode.sh" /usr/local/bin/kiosk-mode
ln -sfn "$OPT_SCRIPTS/objednavka-autostart.sh" /usr/local/bin/objednavka-autostart
ln -sfn "$OPT_SCRIPTS/teamviewer-dokoncit.sh" /usr/local/bin/teamviewer-dokoncit
ln -sfn "$OPT_SCRIPTS/teamviewer-postinstall.sh" /usr/local/bin/teamviewer-postinstall
ln -sfn "$OPT_SCRIPTS/teamviewer-lokalni-volby.sh" /usr/local/bin/teamviewer-lokalni-volby
ln -sfn "$OPT_SCRIPTS/teamviewer-updates-off.sh" /usr/local/bin/teamviewer-updates-off
ln -sfn "$OPT_SCRIPTS/teamviewer-updates-on.sh" /usr/local/bin/teamviewer-updates-on
ln -sfn "$TARGET_HOME/bin/firstboot-install.sh" /usr/local/bin/objng-dokoncit
ln -sfn "$OPT_SCRIPTS/objednavka-kiosk-system-mode.sh" /usr/local/sbin/objednavka-kiosk-system-mode
ln -sfn "$TARGET_HOME/bin/install-egalax-eeti-bootstrap.sh" /usr/local/sbin/install-egalax-eeti

# Touch access permissions used by both service calibration paths.
getent group input >/dev/null 2>&1 || groupadd --system input
usermod -aG input "$TARGET_USER"
cat > /etc/udev/rules.d/98-objednavka-ng-touch-access.rules <<'EOF'
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="0596", ATTRS{idProduct}=="0001", GROUP="input", MODE="0660"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="0eef", ATTRS{idProduct}=="0001", GROUP="input", MODE="0660"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="eGalaxTouch Virtual Device for Single*", GROUP="input", MODE="0660"
EOF
chmod 0644 /etc/udev/rules.d/98-objednavka-ng-touch-access.rules
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger --subsystem-match=input --action=change 2>/dev/null || true

# Splash is installed only after the touch calibration/test has succeeded.
if [[ -s "$OPT_ASSETS/splash-image.tga" ]]; then
  if command -v configure-splash >/dev/null 2>&1; then
    configure-splash "$OPT_ASSETS/splash-image.tga" || true
  fi
fi
BOOTCFG="/boot/firmware/config.txt"; [[ -f "$BOOTCFG" ]] || BOOTCFG="/boot/config.txt"
if [[ -f "$BOOTCFG" ]]; then
  python3 - "$BOOTCFG" <<'PY'
from pathlib import Path
import re, sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8', errors='replace')
block='''# >>> OBJEDNAVKANG BOOT SETTINGS >>>
[all]
disable_splash=1
boot_delay_ms=4000
# <<< OBJEDNAVKANG BOOT SETTINGS <<<'''
s=re.sub(r'\n?# >>> OBJEDNAVKANG BOOT SETTINGS >>>.*?# <<< OBJEDNAVKANG BOOT SETTINGS <<<\n?', '\n', s, flags=re.S)
p.write_text(s.rstrip()+'\n\n'+block+'\n', encoding='utf-8')
PY
fi

# Hostname + desktop autologin. Toto se nastavi uz v master IMG a znovu overi pri instalaci jadra.
hostnamectl set-hostname "${OBJNG_HOSTNAME:-rpi-pcbox}"
printf '%s\n' "${OBJNG_HOSTNAME:-rpi-pcbox}" > /etc/hostname
if command -v raspi-config >/dev/null 2>&1; then
  env SUDO_USER="$TARGET_USER" raspi-config nonint do_boot_behaviour B4
fi
install -d -m 0755 /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/90-objednavka-ng-autologin.conf <<EOF
[Seat:*]
autologin-user=$TARGET_USER
autologin-user-timeout=0
EOF
systemctl set-default graphical.target
systemctl enable lightdm.service
grep -q "^autologin-user=$TARGET_USER$" /etc/lightdm/lightdm.conf.d/90-objednavka-ng-autologin.conf

cat > "$OPT_DOCS/SERVISNI_PRIKAZY.txt" <<'EOF'
OBJEDNÁVKANG - SERVISNÍ PŘÍKAZY
================================

Tento soubor je také na ploše jako zástupce: Příkazy OBJNG
Trvalá dokumentace v: /opt/objednavka-ng/docs/


BĚŽNÁ OBSLUHA
=============

Příkaz                  Funkce
----------------------  ------------------------------------------------------------
kalibrace               Automaticky rozezná touch panel. eGalax spustí přes eCalib,
                        3M přes fullscreen kalibrátor.

nastavit-connection     Nastaví IP databáze, port, název DB a název PCBOX.

nastavit-ctecku         Najde připojenou čtečku a uloží její port do konfigurace.

objng-dokoncit          Ručně spustí instalačního průvodce, pokud se po rebootu
                        neotevřel automaticky.


KIOSK REŽIM A AUTOMATICKÉ SPUŠTĚNÍ APLIKACE
============================================

Příkaz                          Funkce
------------------------------  ------------------------------------------------------------
kiosk-mode on                   Skryje desktop a panel po dalším startu; samotnou
                                aplikaci automaticky nespouští.

kiosk-mode off                  Vrátí běžný desktop a panel po dalším startu.

kiosk-mode status               Zobrazí, zda je čistý kiosk desktop zapnutý.

objednavka-autostart on         Zapne automatické spuštění aplikace ObjednávkaNG
                                po přihlášení.

objednavka-autostart off        Vypne automatické spuštění aplikace.

objednavka-autostart status     Zobrazí stav automatického spouštění aplikace.

kiosk-on                        Zapne čistý kiosk režim i automatické spuštění
                                aplikace pro další start.

kiosk-off                       Vypne kiosk režim i automatické spuštění aplikace
                                pro další start.

kiosk-on --now                  Zapne kiosk režim a spustí jej také ihned v aktuální
                                relaci.

kiosk-off --now                 Vypne kiosk, zavře aplikaci a zobrazí desktop také
                                ihned.


ZOBRAZENÍ A TEAMVIEWER
======================

Příkaz                  Funkce
----------------------  ------------------------------------------------------------
zvetseni-on             Zapne trvalé zvětšení 125 % přes kanshi.

zvetseni-off            Vrátí nativní měřítko 100 %.

zvetseni-status         Zobrazí aktivní výstup a scale.

zvetseni-restore        Obnoví původní kanshi konfiguraci ze zálohy.

teamviewer-postinstall  Vždy po instalaci: čeština, LAN, apt hold, alias, heslo ze secret.

teamviewer-dokoncit     Přiřazení do TeamViewer správy (Assignment ID ze secret).

teamviewer-lokalni-volby preview|apply|restore
                        Ruční patch jazyka/LAN/alias v global.conf.

teamviewer-updates-off  Zablokuje apt aktualizace balíčku TeamVieweru.

teamviewer-updates-on   Znovu povolí apt aktualizace TeamVieweru.

objng-final-check       Ověří TeamViewer, autologin, scale, kiosk a autostart
                        aplikace.


GUI A OSTATNÍ
=============

Příkaz                  Funkce
----------------------  ------------------------------------------------------------
gui-on                  Ihned zobrazí plochu a panel (boot režim nemění).

gui-off                 Ihned skryje plochu a panel (boot režim nemění).

reset-objng-firstboot   Resetuje celý MASTER BOOT proces od kalibrace touch.

touch-setup             Průvodce detekcí touch panelu a kalibrací.

touch-preset            Výchozí orientace 3M panelu před kalibrací.
EOF

cat > "$OPT_DOCS/INFO_OBJNG.txt" <<'EOF'
OBJEDNÁVKANG - SERVISNÍ DOKUMENTACE
===================================

Trvalá dokumentace je v adresáři:
  /opt/objednavka-ng/docs/

Soubory:
  SERVISNI_PRIKAZY.txt   Přehled servisních příkazů (příkaz → funkce)
  INFO_OBJNG.txt         Tento soubor

Na ploše jsou zástupce:
  Config OBJNG           Otevře config aplikace
  Příkazy OBJNG          Otevře SERVISNI_PRIKAZY.txt

TeamViewer secret soubory (volitelné, mimo veřejný Git):
  /home/objng/bootstrap/v2/secrets/teamviewer-assignment-id
  /home/objng/bootstrap/v2/secrets/teamviewer-password
  /home/objng/bootstrap/v2/secrets/teamviewer-alias
EOF

SERVISNI_DOC="$OPT_DOCS/SERVISNI_PRIKAZY.txt"

open_editor_cmd() {
  # Vrati prikaz pro otevreni souboru v textovem editoru (mousepad -> gedit -> kate -> nano v terminalu).
  echo 'sh -c '"'"'for e in mousepad gedit kate leafpad xed; do command -v "$e" >/dev/null 2>&1 && exec "$e" "$@"; done; foot nano "$@" 2>/dev/null || lxterminal -e nano "$@"'"'"' -- '
}
OPEN_EDITOR="$(open_editor_cmd)"

cat > "$DESKTOP/Config OBJNG.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Config OBJNG
Comment=Otevřít konfiguraci aplikace ObjednávkaNG
Exec=${OPEN_EDITOR}"$CONFIG_REAL"
Icon=accessories-text-editor
Terminal=false
Categories=Utility;
EOF
chmod 0755 "$DESKTOP/Config OBJNG.desktop"

cat > "$DESKTOP/Prikazy OBJNG.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Příkazy OBJNG
Comment=Servisní příkazy ObjednávkaNG
Exec=${OPEN_EDITOR}"$SERVISNI_DOC"
Icon=accessories-text-editor
Terminal=false
Categories=Utility;
EOF
chmod 0755 "$DESKTOP/Prikazy OBJNG.desktop"

ln -sfn "$SERVISNI_DOC" "$DESKTOP/Prikazy OBJNG.txt"
ln -sfn "$OPT_DOCS/INFO_OBJNG.txt" "$DESKTOP/Info OBJNG.txt"

cat > "$DESKTOP/Info OBJNG.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Info OBJNG
Comment=Informace a cesty k servisni dokumentaci
Exec=${OPEN_EDITOR}"$OPT_DOCS/INFO_OBJNG.txt"
Icon=help-about
Terminal=false
Categories=Utility;
EOF
chmod 0755 "$DESKTOP/Info OBJNG.desktop"

# Wrapper pro kalibraci – potrebuje DISPLAY/XAUTHORITY a spusti foot terminal.
TOUCH_WRAPPER="$TARGET_HOME/bin/touch-gui-launcher.sh"
cat > "$TOUCH_WRAPPER" <<'WRAPPER'
#!/usr/bin/env bash
# Spusti kalibrace nebo touch-test v terminalu s DISPLAY/XAUTHORITY.
MODE="${1:-calibrate}"
DISPLAY="${DISPLAY:-:0}"
XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
export DISPLAY XAUTHORITY

run_in_term() {
  if command -v foot >/dev/null 2>&1; then
    foot -T "ObjednavkaNG - $1" -- bash -c "$2; echo; read -rsp 'Stiskni Enter pro zavřeni...' _" &
  elif command -v lxterminal >/dev/null 2>&1; then
    lxterminal --title="ObjednavkaNG - $1" -e bash -c "$2; echo; read -rsp 'Stiskni Enter pro zavřeni...' _" &
  else
    bash -c "$2" &
  fi
}

case "$MODE" in
  calibrate)
    run_in_term "Kalibrace touch" "kalibrace"
    ;;
  test)
    run_in_term "Test touch" "env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY python3 /home/objng/bin/touch-test.py"
    ;;
esac
WRAPPER
chmod 0755 "$TOUCH_WRAPPER"
chown "$TARGET_USER:$TARGET_GROUP" "$TOUCH_WRAPPER"

cat > "$DESKTOP/Kalibrace touch.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Kalibrace touch
Comment=Spustí kalibraci dotykového panelu (3M nebo eGalax)
Exec=$TOUCH_WRAPPER calibrate
Icon=input-touchpad
Terminal=false
Categories=Utility;
EOF
chmod 0755 "$DESKTOP/Kalibrace touch.desktop"

cat > "$DESKTOP/Test touch.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Test touch
Comment=Fullscreen 4-bodový test dotykového panelu
Exec=$TOUCH_WRAPPER test
Icon=input-touchpad
Terminal=false
Categories=Utility;
EOF
chmod 0755 "$DESKTOP/Test touch.desktop"

chown -R "$TARGET_USER:$TARGET_GROUP" "$DESKTOP" "$OPT_DOCS" "$TARGET_HOME/.config/objednavka-ng"

log "Lokalni jadro je nainstalovane. Config nebyl pri opakovani prepsan."
