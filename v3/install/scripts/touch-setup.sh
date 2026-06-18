#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q # Rozpoznání typu dotyku a příprava správné kalibrační cesty.
set -Eeuo pipefail
has_usb() { lsusb 2>/dev/null | grep -qi "$1"; }

if has_usb '0eef:0001'; then
  echo "Nalezen eGalax USB touchscreen (0eef:0001)."
  if ! command -v eCalib >/dev/null 2>&1; then
    read -r -p "Nainstalovat ověřený oficiální EETI eGTouch driver nyní? [A/n] " ans
    if [[ "${ans:-A}" =~ ^[AaYy]$ ]]; then
      sudo install-egalax-eeti
      echo "Driver je instalovaný. Nyní proveď reboot a potom spusť: kalibrace"
    fi
    exit 0
  fi
  echo "EETI eCalib je instalovaný."
  read -r -p "Spustit oficiální kalibraci eGalax nyní? [A/n] " ans
  [[ "${ans:-A}" =~ ^[AaYy]$ ]] && exec kalibrace || true
  exit 0
fi

if has_usb '0596:0001'; then
  echo "Nalezen 3M USB touchscreen (0596:0001)."
  read -r -p "Použít ověřenou výchozí orientaci 3M před kalibrací? [A/n] " ans
  if [[ "${ans:-A}" =~ ^[AaYy]$ ]]; then sudo touch-preset apply; fi
  read -r -p "Spustit fullscreen kalibrátor 3M nyní? [A/n] " ans
  [[ "${ans:-A}" =~ ^[AaYy]$ ]] && exec kalibrace || true
  exit 0
fi

echo "Nebyl nalezen známý dotykový panel eGalax 0eef:0001 ani 3M 0596:0001."
echo "Diagnostika: lsusb"
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
# Rozpoznání typu dotyku a příprava správné kalibrační cesty.
set -Eeuo pipefail
has_usb() { lsusb 2>/dev/null | grep -qi "$1"; }

if has_usb '0eef:0001'; then
  echo "Nalezen eGalax USB touchscreen (0eef:0001)."
  if ! command -v eCalib >/dev/null 2>&1; then
    read -r -p "Nainstalovat ověřený oficiální EETI eGTouch driver nyní? [A/n] " ans
    if [[ "${ans:-A}" =~ ^[AaYy]$ ]]; then
      sudo install-egalax-eeti
      echo "Driver je instalovaný. Nyní proveď reboot a potom spusť: kalibrace"
    fi
    exit 0
  fi
  echo "EETI eCalib je instalovaný."
  read -r -p "Spustit oficiální kalibraci eGalax nyní? [A/n] " ans
  [[ "${ans:-A}" =~ ^[AaYy]$ ]] && exec kalibrace || true
  exit 0
fi

if has_usb '0596:0001'; then
  echo "Nalezen 3M USB touchscreen (0596:0001)."
  read -r -p "Použít ověřenou výchozí orientaci 3M před kalibrací? [A/n] " ans
  if [[ "${ans:-A}" =~ ^[AaYy]$ ]]; then sudo touch-preset apply; fi
  read -r -p "Spustit fullscreen kalibrátor 3M nyní? [A/n] " ans
  [[ "${ans:-A}" =~ ^[AaYy]$ ]] && exec kalibrace || true
  exit 0
fi

echo "Nebyl nalezen známý dotykový panel eGalax 0eef:0001 ani 3M 0596:0001."
echo "Diagnostika: lsusb"
