# ObjednavkaNG RPi Linux Installer

Aktualni smer je **v3 firstboot + zaheslovany instalacni balik**.

Repo obsahuje jen skripty, sablony a dokumentaci. Produkcni binarky, realny `config.json`, TeamViewer `.deb`, AppImage, EETI archiv a vygenerovany `rpibox_install.7z` se do Gitu neposilaji.

## Struktura

```text
v3/
  boot/      soubory primo do pripraveneho IMG
  install/   obsah instalacniho baliku stahovaneho ze serveru
```

Podrobny navod je v:

```text
v3/README.md
```

## IMG cast

Do pripraveneho Raspberry Pi IMG nahraj obsah:

```text
v3/boot/
```

na Raspberry typicky sem:

```bash
/home/objng/firstboot/
```

Minimalne:

```text
firstboot-install.sh
firstboot.conf
touch_calibrator_v3.py
prepare-image-autostart.sh
```

`firstboot.conf` vytvor podle:

```text
v3/boot/firstboot.conf.example
```

Po nahrani na Raspberry nastav autologin a firstboot autostart:

```bash
sudo bash /home/objng/firstboot/prepare-image-autostart.sh
```

Tenhle krok nastavi autologin profilu `objng`, graficky boot target a firstboot autostart.

## Zaheslovany balik

Obsah `v3/install` se bali do:

```text
v3/rpibox_install.7z
```

Build:

```bash
cd /c/Work/projects/objng_rpi_linux/objednavka-ng-rpi-installer/v3
PACKAGE_PASSWORD='stejne-heslo-jako-v-firstboot.conf' ./build-encrypted-package.sh
```

Archiv se vytvari s `-mhe=on`, takze bez hesla nejsou videt ani nazvy souboru.

Upload na devel:

```powershell
scp -P 10022 "C:\Work\projects\objng_rpi_linux\objednavka-ng-rpi-installer\v3\rpibox_install.7z" honza@devel.altisima.cz:/home/honza/
```

Presun na CDN:

```bash
ssh -p 10022 honza@devel.altisima.cz
sudo mv /home/honza/rpibox_install.7z /altisima/cdn/public/rpibox_install.7z
sudo chmod 644 /altisima/cdn/public/rpibox_install.7z
```

Firstboot stahuje:

```text
https://cdn.public.altisima.cz/rpibox_install.7z
```

## Retry chovani

Firstboot se nesmi zaseknout po jedne chybe.

Dokud neexistuje:

```bash
/home/objng/.local/state/objednavka-ng-firstboot/done
```

spousti se po startu znovu.

Kdyz neni sit nebo CDN balik neni dostupny, stav zustane:

```text
download_main
```

a skript zkusi stazeni znovu po dalsim rebootu.

TeamViewer a touch priprava jsou volitelne predkroky. Jejich selhani nesmi blokovat stazeni hlavniho baliku.

## TeamViewer

Firstboot a `teamviewer-dokoncit` umi:

- nastavit nazev `RPIBOX` nebo `RPIBOX-<suffix>`,
- nastavit volitelne trvale heslo,
- provest assignment,
- zapnout cestinu a LAN rezim,
- zakazat APT aktualizace TeamViewer baliku,
- zapnout sluzbu `teamviewerd` po startu.

## Touch

Podporovane cesty:

```text
3M USB 0596:0001
eGalax USB 0eef:0001
```

3M kalibrator po poslednim bodu automaticky zapise pravidlo, zavre fullscreen okno a vyzada reboot.

eGalax pouziva oficialni EETI driver a `eCalib`; po instalaci driveru a po kalibraci se vynuti reboot.

## Co se necommituje

Ignorovane soubory:

```text
*.deb
*.AppImage
*.7z
*.tar.gz
files/config.json
files/SHA256SUMS
v3/boot/firstboot.conf
v3/rpibox_install.7z
v3/install/files/config.json
```

## Overeni

```bash
bash -n v3/boot/firstboot-install.sh v3/boot/prepare-image-autostart.sh v3/build-encrypted-package.sh v3/install/install.sh v3/install/scripts/*.sh
python -m py_compile v3/boot/touch_calibrator_v3.py v3/install/scripts/touch_calibrator_v3.py
```
