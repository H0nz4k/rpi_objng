# ObjednavkaNG RPi Linux v3

Tahle verze oddeluje dve casti instalace:

```text
v3/
  boot/      soubory primo do pripraveneho IMG
  install/   obsah instalacniho baliku stahovaneho ze serveru
```

## 1. Co patri do IMG

Do pripraveneho Raspberry Pi IMG zkopiruj obsah slozky:

```text
C:\Work\projects\objng_rpi_linux\v3\boot
```

na Raspberry typicky sem:

```bash
/home/objng/firstboot/
```

Minimalni obsah:

```text
/home/objng/firstboot/firstboot-install.sh
/home/objng/firstboot/firstboot.conf
/home/objng/firstboot/touch_calibrator_v3.py
/home/objng/firstboot/prepare-image-autostart.sh
```

Volitelne, ale doporucene pro offline prvni cast:

```text
/home/objng/firstboot/teamviewer.deb
/home/objng/firstboot/eGTouch_v2.5.13219.L-ma.7z
```

`firstboot.conf` vytvor podle:

```text
v3/boot/firstboot.conf.example
```

Po zkopirovani souboru do IMG/RPi spust jednorazove:

```bash
sudo bash /home/objng/firstboot/prepare-image-autostart.sh
```

Tenhle skript nastavi:

- autologin uzivatele `objng`,
- graficky boot target,
- firstboot autostart pro labwc,
- zalozni XDG autostart,
- executable bit pro `firstboot-install.sh`.

Bez autologinu se firstboot terminal po zapnuti nemusi sam otevrit.

## 2. firstboot.conf

Priklad:

```bash
PACKAGE_URL="https://cdn.public.altisima.cz/rpibox_install.7z"
PACKAGE_PASSWORD="ZMENIT_NA_VLASTNI_HESLO"

TEAMVIEWER_ALIAS_SUFFIX="KUCHYNE-01"
TEAMVIEWER_PASSWORD="volitelne-tv-heslo"
TEAMVIEWER_REASSIGN=0

AUTO_CONTINUE_SECONDS=20
FIRSTBOOT_RETRY_SECONDS=20
FIRSTBOOT_MAX_STEP_RETRIES=3
OBJNG_INTERACTIVE=0
```

Vysledek TeamViewer nazvu:

```text
RPIBOX-KUCHYNE-01
```

Kdyz `TEAMVIEWER_ALIAS_SUFFIX` zustane prazdny, nazev bude jen:

```text
RPIBOX
```

`OBJNG_INTERACTIVE=0` je vychozi touch-only automaticky rezim. Skript se zbytecne nepta a pokracuje sam.

`OBJNG_INTERACTIVE=1` povoli nektere dotazy a pokusi se spustit obrazovkovou klavesnici.

## 3. Zaheslovany balik na server

Obsah slozky:

```text
v3/install
```

se bali do zaheslovaneho 7z archivu:

```text
v3/rpibox_install.7z
```

Vytvoreni baliku:

```bash
cd /c/Work/projects/objng_rpi_linux/v3
PACKAGE_PASSWORD='ZMENIT_NA_VLASTNI_HESLO' ./build-encrypted-package.sh
```

Heslo musi byt stejne jako `PACKAGE_PASSWORD` ve `firstboot.conf`.

Archiv se vytvari s:

```bash
-mhe=on
```

To znamena, ze bez hesla nejsou videt ani nazvy souboru uvnitr archivu.

Vysledny soubor nahraj na CDN:

```text
https://cdn.public.altisima.cz/rpibox_install.7z
```

Poznamka k bezpecnosti: heslo je ulozene v IMG ve `firstboot.conf` nebo ve skriptu. Chrani tedy hlavne proti nahodnemu stazeni baliku ze serveru. Nechrani proti cloveku, ktery ma fyzicky IMG a umi si z nej heslo precist.

## 4. Co dela firstboot-install.sh

Skript:

```text
v3/boot/firstboot-install.sh
```

pri prvnim startu:

1. ukaze IP adresu,
2. po timeoutu pokracuje sam,
3. zajisti svuj vlastni autostart, dokud neni instalace hotova,
4. zkusi nainstalovat minimalni nastroje,
5. zkusi nainstalovat a nastavit TeamViewer z IMG,
6. pripravi nebo spusti kalibraci touch panelu,
7. stahne zaheslovany `rpibox_install.7z`,
8. rozbali ho pomoci hesla z `firstboot.conf`,
9. spusti hlavni `install.sh`,
10. teprve po uspesnem dobehnuti hlavni instalace odstrani firstboot autostart.

## 5. Retry a nedostupna sit

Firstboot nesmi zustat mrtvy po jedne chybe.

Dokud neexistuje:

```bash
/home/objng/.local/state/objednavka-ng-firstboot/done
```

skript se bude po startu spoustet znovu.

Stav se uklada sem:

```bash
/home/objng/.local/state/objednavka-ng-firstboot/state
```

Pocet pokusu:

```bash
/home/objng/.local/state/objednavka-ng-firstboot/retry-count
```

Kdyz neni sit nebo CDN balik neni dostupny:

```text
state = download_main
```

a skript po rebootu znovu zkusi stazeni.

Volitelne kroky jako TeamViewer nebo touch priprava nesmi blokovat stazeni hlavniho baliku. Kdyz opakovane selzou, firstboot prejde na `download_main`.

## 6. Touch

Podporovane cesty:

```text
3M USB 0596:0001
eGalax USB 0eef:0001
```

3M:

- spusti `touch_calibrator_v3.py`,
- po poslednim bodu automaticky zapise udev pravidlo,
- fullscreen okno se samo zavre,
- nasleduje reboot.

eGalax:

- nainstaluje EETI driver,
- vynuti reboot,
- po dalsim startu spusti oficialni `eCalib`,
- po kalibraci vynuti reboot.

Kdyz touch priprava selze, skript to zapise do logu a pokracuje ke stazeni hlavniho baliku.

## 7. TeamViewer

Firstboot i pozdejsi prikaz:

```bash
teamviewer-dokoncit
```

nastavuji:

- nazev zarizeni `RPIBOX` nebo `RPIBOX-<suffix>`,
- volitelne trvale heslo,
- TeamViewer assignment,
- cestinu v TeamVieweru,
- LAN rezim,
- zakaz APT aktualizaci TeamViewer baliku,
- sluzbu `teamviewerd` po startu.

Pokud `teamviewer.deb` neni v IMG, firstboot tento krok preskoci a hlavni instalacni balik ho muze doinstalovat pozdeji.

## 8. Hlavni install

Stahovany balik se po rozbaleni spousti z:

```bash
/home/objng/install/install.sh
```

Pokud uz byl TeamViewer nainstalovany z IMG, hlavni instalator dostane:

```bash
--skip-teamviewer
```

aby se TeamViewer neinstaloval znovu.

## 9. Build checklist

Pred vytvorenim IMG:

```text
[ ] v3/boot/firstboot-install.sh je v /home/objng/firstboot/
[ ] v3/boot/touch_calibrator_v3.py je v /home/objng/firstboot/
[ ] v3/boot/prepare-image-autostart.sh je v /home/objng/firstboot/
[ ] /home/objng/firstboot/firstboot.conf existuje a ma spravne PACKAGE_PASSWORD
[ ] volitelne: teamviewer.deb je v /home/objng/firstboot/
[ ] volitelne: eGTouch_v2.5.13219.L-ma.7z je v /home/objng/firstboot/
[ ] spusten prikaz: sudo bash /home/objng/firstboot/prepare-image-autostart.sh
[ ] po rebootu se uzivatel objng automaticky prihlasi
[ ] firstboot terminal se otevira sam
```

Pred nahranim na CDN:

```bash
cd /c/Work/projects/objng_rpi_linux/v3
PACKAGE_PASSWORD='stejne-heslo-jako-v-IMG' ./build-encrypted-package.sh
```

Pak nahrat:

```text
v3/rpibox_install.7z -> https://cdn.public.altisima.cz/rpibox_install.7z
```

Upload z Windows prikazove radky na devel server:

```powershell
scp -P 10022 "C:\Work\projects\objng_rpi_linux\v3\rpibox_install.7z" honza@devel.altisima.cz:/home/honza/
```

Na serveru pak presun na CDN umisteni:

```bash
ssh -p 10022 honza@devel.altisima.cz
sudo mv /home/honza/rpibox_install.7z /altisima/cdn/public/rpibox_install.7z
sudo chmod 644 /altisima/cdn/public/rpibox_install.7z
ls -lh /altisima/cdn/public/rpibox_install.7z
```

## 10. Overeni syntaxe

Na vyvojovem stroji:

```bash
bash -n v3/boot/firstboot-install.sh v3/build-encrypted-package.sh v3/install/install.sh v3/install/scripts/*.sh
bash -n v3/boot/prepare-image-autostart.sh
python -m py_compile v3/boot/touch_calibrator_v3.py v3/install/scripts/touch_calibrator_v3.py
```
