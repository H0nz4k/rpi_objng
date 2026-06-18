# ObjednavkaNG RPi Linux Installer

Aktualni smer je **MASTER BOOT v2.1.6** – lokalni balicek, zadne CDN stazeni.

Repo obsahuje jen skripty, sablony a dokumentaci.
Produkcni binarky, realny `config.json`, TeamViewer `.deb`, AppImage a EETI archiv se do Gitu neposilaji.

## Struktura

```text
v3/
  boot/             skripty kopirovane na RPi (firstboot, touch, TV)
  install/scripts/  payload skripty (kiosk, kalibrace, TeamViewer dokonceni)
  setup-master-img.sh  nastavi master obraz (autologin, autostart, udev, baliky)
deploy/
  deploy.ps1              Windows PowerShell – build/scp/reset/install na RPi
  deploy.config.ps1.example
  reset-remote.ps1
scripts/            starsi / jednorazove utility
docs/               dokumentace
```

## Rychly start – priprava master karty

```bash
# Na Raspberry Pi (z distribuovaneho 216.tar.gz):
cd /home/objng
tar -xzf 216.tar.gz
cd 216/ObjednavkaNG_MASTER_BOOT_v2.1.6/objng_master_boot_v2
sudo ./setup-master-img.sh
sudo reboot
```

Prvni boot spusti firstboot pruvodce automaticky.

## Windows deploy

```powershell
# Zkopiruj deploy.config.ps1.example -> deploy.config.ps1, vyplniste IP/heslo
.\deploy\deploy.ps1 -Build -Install        # cistý RPi
.\deploy\deploy.ps1 -Build -Reset -Install  # existujici karta
.\deploy\deploy.ps1 -Reset                  # jen reset firstbootu
.\deploy\reset-remote.ps1 -Factory          # hluboky reset
```

## Faze firstbootu

| Faze | Co dela |
|------|---------|
| 1 | 3M/eGalax kalibrace touch (reboot) |
| 2 | 4-bodovy fullscreen test touch |
| 3 | AppImage, DB, ctecka, TeamViewer, volitelny public update |
| 4 | Rozsireni filesystemu + apt full-upgrade (skip po 30 s bez internetu) |
| 5 | Kiosk mode, autostart, 125% zvetseni |

## TeamViewer

`teamviewer-postinstall.sh` nastavi:
- jazyk: cestina, rezim LAN, zakaz APT aktualizaci TV
- automaticke prijeti EULA (zadny dialog po instalaci)
- volitelne heslo a alias z `files/secrets/teamviewer-{password,alias}`

`teamviewer-dokoncit.sh` (payload) provede assignment a potvrzeni ID.

## Touch

```text
3M USB  0596:0001
eGalax  0eef:0001
```

Nove: labwc fullscreen pres `wlrctl` + WM_CLASS pravidla v `rc.xml`.
Desktop ikony: **Kalibrace touch**, **Test touch**.

## Co se necommituje

```text
*.deb, *.AppImage, *.7z, *.tar.gz
deploy/deploy.config.ps1
files/config.json
v3/boot/firstboot.conf
v3/install/files/config.json
files/secrets/teamviewer-{password,alias,assignment-id}
```

## Overeni skriptu

```bash
bash -n v3/boot/firstboot-install.sh v3/boot/touch-bootstrap.sh \
     v3/setup-master-img.sh v3/install/scripts/*.sh
python3 -m py_compile v3/boot/touch_calibrator_v3.py v3/boot/touch-test.py \
     v3/boot/labwc_tk_helper.py
```
