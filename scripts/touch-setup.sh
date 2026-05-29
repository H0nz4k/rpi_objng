#!/usr/bin/env bash
# Rozpoznání známé dotykové vrstvy a doporučení správné kalibrační cesty.
set -Eeuo pipefail
OUT="$(libinput list-devices 2>/dev/null || true)"
if grep -q '3M 3M USB Touchscreen - EX II' <<<"$OUT"; then
  echo "Nalezen 3M USB touchscreen (0596:0001)."
  echo "Pro tento typ máme ověřenou směrovou matici 0 -1 1 -1 0 1."
  read -r -p "Použít výchozí 3M orientaci nyní? [A/n] " ans
  if [[ "${ans:-A}" =~ ^[AaYy]$ ]]; then sudo touch-preset apply; echo "Po rebootu lze provést jemné doladění příkazem: kalibrace"; fi
  exit 0
fi
if grep -q 'eGalaxTouch Virtual Device for Single' <<<"$OUT"; then
  echo "Nalezen eGalaxTouch Virtual Device for Single."
  echo "V naměřeném výpisu se tento EETI virtuální vstup hlásí jako pointer s 'Calibration: n/a'."
  echo "Proto na něj automaticky NEAPLIKUJI libinput matici určenou pro 3M panel."
  echo "Použij kalibrační nástroj oficiálního EETI/eGalax driveru."
  exit 0
fi
echo "Nebyl nalezen známý dotykový panel 3M ani eGalaxTouch."
echo "Diagnostika: sudo libinput list-devices"
