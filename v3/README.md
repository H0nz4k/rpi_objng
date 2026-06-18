# v3 – ObjednavkaNG MASTER BOOT

Vsechny firstboot a payload skripty pro MASTER BOOT model.

## Struktura

```text
v3/
  setup-master-img.sh    hlavni setup skript (spust jednou na RPi)
  boot/                  skripty kopirovane do /home/objng/bin/
  install/scripts/       payload skripty (kiosk, kalibrace, TeamViewer)
```

## Priprava master karty

```bash
cd /home/objng
tar -xzf 216.tar.gz
cd 216/ObjednavkaNG_MASTER_BOOT_v2.1.6/objng_master_boot_v2
sudo ./setup-master-img.sh
sudo reboot
```

## Faze firstbootu

| Faze | Co dela |
|------|---------|
| 1 | 3M/eGalax kalibrace touch → reboot |
| 2 | 4-bodovy fullscreen test touch |
| 3 | AppImage, DB, ctecka, TeamViewer, volitelny public update |
| 4 | Expand filesystem + apt full-upgrade (skip po 30 s) |
| 5 | Kiosk mode, autostart, 125% zvetseni |

## Reset bez prepsani SD

```bash
sudo reset-objng-firstboot           # soft reset stavu
sudo reset-objng-firstboot --factory  # + smaze /opt/objednavka-ng
sudo reboot
```

## Klicove skripty v boot/

| Soubor | Popis |
|--------|-------|
| `firstboot-install.sh` | Hlavni firstboot orchestrator |
| `touch-bootstrap.sh` | Kalibrace + verifikace 3M/eGalax |
| `touch-test.py` | 4-bodovy fullscreen touch test |
| `touch_calibrator_v3.py` | 3M kalibrator |
| `labwc-fullscreen.sh` | Wlrctl wrapper pro fullscreen na labwc |
| `labwc_tk_helper.py` | Tkinter helper pro labwc/XWayland |
| `install-local-core.sh` | Instalace AppImage, symlinku, ikon |
| `teamviewer-postinstall.sh` | TV konfigurace + EULA + secrets |
| `finalize-system.sh` | Kiosk, autostart, zvetseni |
| `reset-objng-firstboot.sh` | Reset/factory reset firstboot stavu |
