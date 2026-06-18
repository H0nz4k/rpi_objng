# Changelog

## v2.1.7 – fix kalibracni smycky + CRLF/deploy

- odstranena smycka kalibrace (verify pres udev na labwc nefungovalo spolehlive)
- faze 2: rovnou 4-bodovy touch test misto --verify
- bash/CRLF guard ve vsech .sh skriptech
- deploy.ps1: reset z nahraneeho baliku, setup pres bash + sed CR

## v2.1.6 – desktop ikony, TV EULA, opravy faze 4

- Plocha: Config/Prikazy/Info OBJNG oteviraji soubory primo v editoru (mousepad → gedit → nano).
- Plocha: nove ikony Kalibrace touch a Test touch.
- TeamViewer: automaticke prijeti EULA (`teamviewer license accept` + `LicenseAgreementStatus=1`).
- Firstboot faze 4: [X] preskoci apt nebo public update a pokracuje do faze 5.

## v2.1.5 – labwc fullscreen, deploy.ps1

- Fullscreen touch (kalibrace + test) na labwc pres `wlrctl` a `WM_CLASS`.
- `labwc_tk_helper.py` + `labwc-fullscreen.sh` – reseni Tkinter/XWayland na Waylandu.
- Poradi fazi: touch (1-2) → instalace (3) → expand+apt (4) → kiosk (5).
- Apt skip po 30 s s odpoctem.
- `deploy.ps1` – Windows PowerShell deploy s Posh-SSH, `-Reset`, `-Install`, `-TestCycle`.
- `reset-objng-firstboot.sh --factory` – hluboky reset.

## v2.1.4 – TeamViewer secrets, dokumentace

- Secret soubory pro TeamViewer heslo, alias, assignment ID.
- Druha ikona `Prikazy OBJNG.desktop` s dokumentaci v `/opt/objednavka-ng/docs/`.
- TeamViewer postinstall vzdy bezi (jazyk, LAN, apt hold).

## v2.1.3 – 3M kalibrace v4.1, eGalax

- 3M kalibrator v4.1, automaticky reboot, 180 s watchdog touch testu.
- eGalax EETI driver a eCalib.

## 0.7.0 – Git-ready konsolidace

- Prvni push na Git.
- Velke binarky a `config.json` chraneny pres `.gitignore`.
- `config.example.json`, bezpecny TeamViewer wizard, libinput matice pro 3M.
