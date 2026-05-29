#!/usr/bin/env bash
# Detekce čtečky v /dev/serial/by-id a zápis SERIAL_READER_PORT do config.json.
set -Eeuo pipefail

CONFIG="/opt/objednavka-ng/config.json"
MODE="${1:-ask}"

[[ -f "$CONFIG" ]] || { echo "Config nenalezen: $CONFIG" >&2; exit 1; }
command -v python3 >/dev/null || { echo "Chybí python3." >&2; exit 1; }

mapfile -t ALL_PORTS < <(find /dev/serial/by-id -maxdepth 1 -mindepth 1 -type l -print 2>/dev/null | sort || true)
mapfile -t TWN_PORTS < <(printf '%s\n' "${ALL_PORTS[@]:-}" | grep -Ei 'TWN4|ELATEC|OEM' || true)

if [[ "${#TWN_PORTS[@]}" -gt 0 ]]; then
    PORTS=("${TWN_PORTS[@]}")
else
    PORTS=("${ALL_PORTS[@]}")
fi

CURRENT="$(python3 - "$CONFIG" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    print(json.load(f).get("SERIAL_READER_PORT", ""))
PY
)"

echo "Aktuální SERIAL_READER_PORT: ${CURRENT:-<prázdný>}"

if [[ "${#PORTS[@]}" -eq 0 || -z "${PORTS[0]:-}" ]]; then
    echo "V /dev/serial/by-id/ nebyla nalezena žádná sériová čtečka."
    echo "Připoj čtečku a spusť později: nastavit-ctecku"
    exit 0
fi

echo
echo "Nalezená sériová zařízení:"
for i in "${!PORTS[@]}"; do
    printf '  %d) %s\n' "$((i+1))" "${PORTS[$i]}"
done

SELECTED=""
if [[ "${#PORTS[@]}" -eq 1 ]]; then
    SELECTED="${PORTS[0]}"
else
    if [[ "$MODE" == "--non-interactive" ]]; then
        echo "Nalezeno více zařízení; v neinteraktivním režimu nic neměním."
        exit 0
    fi
    read -r -p "Vyber číslo zařízení pro čtečku [1-${#PORTS[@]}] (Enter = nic neměnit): " choice
    [[ -z "$choice" ]] && exit 0
    [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#PORTS[@]} )) || {
        echo "Neplatná volba." >&2
        exit 1
    }
    SELECTED="${PORTS[$((choice-1))]}"
fi

if [[ "$MODE" == "--non-interactive" ]]; then
    echo "Nalezena čtečka: $SELECTED"
    echo "Neinteraktivní režim: config nebyl změněn. Spusť později: nastavit-ctecku"
    exit 0
fi

echo
echo "Navržená cesta čtečky:"
echo "  $SELECTED"
read -r -p "Doplnit tuto cestu do SERIAL_READER_PORT? [A/n] " confirm
if [[ ! "${confirm:-A}" =~ ^[AaYy]$ ]]; then
    echo "Config nebyl změněn."
    exit 0
fi

python3 - "$CONFIG" "$SELECTED" <<'PY'
import json, os, sys, tempfile
from pathlib import Path

config = Path(sys.argv[1]).resolve()
port = sys.argv[2]
data = json.loads(config.read_text(encoding="utf-8"))
data["SERIAL_READER_PORT"] = port

fd, tmp = tempfile.mkstemp(prefix=".config.", suffix=".json.tmp", dir=config.parent)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, config)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
PY

echo "Hotovo. SERIAL_READER_PORT byl nastaven na:"
echo "  $SELECTED"
