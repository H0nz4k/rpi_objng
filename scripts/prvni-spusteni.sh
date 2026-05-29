#!/usr/bin/env bash
set -Eeuo pipefail
CONFIG="/opt/objednavka-ng/config.json"
echo "============================================================"; echo " ObjednávkaNG – dokončení prvního nastavení"; echo "============================================================"; echo
[[ -f "$CONFIG" ]] || { echo "Chybí config: $CONFIG" >&2; exit 1; }
echo "Config byl vytvořen před prvním spuštěním aplikace: $CONFIG"
python3 - "$CONFIG" <<'PY'
import json, sys
c=json.load(open(sys.argv[1], encoding='utf-8'))
print('  PCBOX_NAME:        ' + str(c.get('PCBOX_NAME','')))
print('  DATABASE_HOST:     ' + str(c.get('DATABASE_HOST','')))
print('  SERIAL_READER_PORT:' + str(c.get('SERIAL_READER_PORT','')))
PY
read -r -p "Otevřít config k ruční kontrole/úpravě? [A/n] " cfg; [[ "${cfg:-A}" =~ ^[AaYy]$ ]] && nano "$CONFIG" || true
echo; read -r -p "Vyhledat čtečku v /dev/serial/by-id a nabídnout zápis do configu? [A/n] " rdr; [[ "${rdr:-A}" =~ ^[AaYy]$ ]] && nastavit-ctecku || true
echo; read -r -p "Dokončit nastavení TeamViewer Full? [A/n] " tv; [[ "${tv:-A}" =~ ^[AaYy]$ ]] && teamviewer-dokoncit || true
echo; read -r -p "Rozpoznat dotykovou vrstvu a nabídnout správný postup? [A/n] " tch; [[ "${tch:-A}" =~ ^[AaYy]$ ]] && touch-setup || true
echo; read -r -p "Zapnout čistý kiosk pro příští reboot? [a/N] " kiosk
if [[ "${kiosk:-N}" =~ ^[AaYy]$ ]]; then kiosk-on; echo "Dokonči: sudo reboot"; else echo "Kiosk zatím není zapnutý. Později: kiosk-on && sudo reboot"; fi
