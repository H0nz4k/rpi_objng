# ObjednávkaNG – Raspberry Pi Terminal Installer

**Verze:** `0.7.0`  
**Stav:** vývojový / připravený pro první test čisté instalace  
**Cílový systém:** Raspberry Pi OS Desktop (Wayland / labwc), ARM64

Instalační projekt připravuje Raspberry Pi terminál pro aplikaci **ObjednávkaNG**. Instalace je navržená jako offline wizard: AppImage a TeamViewer `.deb` vložíš lokálně do `files/`, zařízení si pak stáhne pouze potřebné systémové balíčky přes `apt`.

## Co instalátor umí

- vytvoří provozní strukturu `/opt/objednavka-ng/`,
- před prvním spuštěním aplikace nainstaluje `config.json` a vytvoří symlink pro pohodlnou editaci,
- nainstaluje aplikaci z `files/objednavka-ng.AppImage`,
- detekuje sériovou čtečku v `/dev/serial/by-id/` a po potvrzení zapíše `SERIAL_READER_PORT`,
- nastaví hostname `rpi-pcbox` a Desktop Autologin uživatele `objng`,
- nainstaluje boot splash a zapíše `disable_splash=1` + `boot_delay_ms=4000`,
- nastaví trvalé zvětšení displeje `scale 1.25`,
- připraví Wayland/labwc kiosk režim bez viditelné plochy a panelu,
- nainstaluje TeamViewer Full z `files/teamviewer.deb` a nabídne bezpečné dokončení účtu/hesla,
- podporuje ověřený touch preset pro 3M USB panel a rozpozná eGalax variantu pro oficiální EETI kalibraci.

## Touchscreen: 3M vs. eGalax

Automatická matice `0 -1 1 -1 0 1` je aktivována pouze pro ověřený **3M USB** panel. U `eGalaxTouch Virtual Device for Single` byl ve výpisu vidět stav `Calibration: n/a`; instalační wizard jej tedy rozpozná, ale automaticky na něj libinput matici neaplikuje a navede na oficiální EETI kalibraci.

## Příprava lokálních souborů

Do složky `files/` vlož před instalací:

```text
objednavka-ng.AppImage   # aplikace – nevkládá se do běžného Gitu
teamviewer.deb            # TeamViewer Full ARM64 – nevkládá se do běžného Gitu
config.json               # lokální produkční config – nevkládá se do běžného Gitu
```

V ZIPu je přiložen lokální `files/config.json` pro pokračování práce; díky `.gitignore` se při běžném `git add .` neodešle do repozitáře. Verzovaná šablona je `files/config.example.json`.

## Instalace na čisté Raspberry Pi

V Raspberry Pi Imageru vytvoř uživatele `objng`. Na Raspberry potom:

```bash
chmod +x install.sh tools/*.sh scripts/*.sh
./tools/build_SHA256SUMS.sh
sudo ./install.sh
sudo reboot
objng-dokoncit
```

Po ověření čtečky, TeamVieweru a dotyku:

```bash
kiosk-on
sudo reboot
```

## Servisní příkazy

```bash
gui-on                    # ihned zobrazí plochu a panel
gui-off                   # ihned skryje plochu a panel
nastavit-ctecku           # nabídne zápis čtečky do configu
touch-setup               # rozpozná 3M/eGalax a navrhne postup
touch-preset status       # stav 3M korekce
kalibrace                 # jemná kalibrace pro 3M/libinput cestu
kiosk-on                  # čistý kiosk pro příští reboot
kiosk-off --now           # vrátí GUI ihned i pro další reboot
objednavka-kiosk status   # stav kiosku
zvetseni-status           # stav scale 1.25
objng-dokoncit            # dokončovací wizard
teamviewer-dokoncit       # TeamViewer účet, heslo a update krok
```

## TeamViewer

Installer instaluje **TeamViewer Full ARM64** z lokálního `files/teamviewer.deb` a zapíná službu `teamviewerd` při startu systému. `teamviewer-dokoncit` nabídne `teamviewer setup`, připomene e-mail `hamouz@altisima.cz`, nabídne `teamviewer passwd` a blokování APT aktualizace balíčku. Patch češtiny/LAN režimu je přiložen jako experimentální a vždy vytváří zálohu; volby se následně ověřují v GUI.

## Git workflow

Postup pro první push z Windows je v [`docs/GIT_PUSH_WINDOWS.md`](docs/GIT_PUSH_WINDOWS.md). Před commitem spusť:

```bash
./tools/validate_project.sh
git status --ignored
```

`files/objednavka-ng.AppImage`, `files/teamviewer.deb`, `files/config.json` a `files/SHA256SUMS` jsou záměrně ignorované, aby se neodeslaly omylem na Git.
