#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q # Interaktivní nastavení DB připojení aplikace ObjednávkaNG.
# Enter použije nabídnutou výchozí hodnotu.
set -Eeuo pipefail

CONFIG_LINK="/opt/objednavka-ng/config.json"
CONFIG="$(readlink -f "$CONFIG_LINK" 2>/dev/null || echo "$CONFIG_LINK")"
[[ -f "$CONFIG" ]] || { echo "Chybí config: $CONFIG" >&2; exit 1; }
[[ "$EUID" -ne 0 ]] || { echo "Spusť jako uživatel objng, bez sudo." >&2; exit 1; }

current() { python3 - "$CONFIG" "$1" <<'PY'
import json,sys
with open(sys.argv[1], encoding='utf-8') as f:
    c=json.load(f)
print(c.get(sys.argv[2], ''))
PY
}

CURRENT_HOST="$(current DATABASE_HOST)"
CURRENT_PORT="$(current DATABASE_PORT)"
CURRENT_DB="$(current DATABASE_NAME)"
CURRENT_PC="$(current PCBOX_NAME)"

# IP se jako výchozí převezme z dodaného config.json / aktuální konfigurace.
# Ostatní výchozí hodnoty jsou instalační standard projektu.
DEFAULT_HOST="$CURRENT_HOST"
DEFAULT_PORT="5432"
DEFAULT_DB="jidelna"
DEFAULT_PC="PCBOX"

echo "============================================================"
echo " ObjednávkaNG – nastavení connection"
echo "============================================================"
echo "Současné hodnoty v configu:"
echo "  IP_DB:       ${CURRENT_HOST:-nenastaveno}"
echo "  PORT:        ${CURRENT_PORT:-nenastaveno}"
echo "  DB_NAME:     ${CURRENT_DB:-nenastaveno}"
echo "  PCBOX_NAME:  ${CURRENT_PC:-nenastaveno}"
echo

echo "Stisknutím Enter použiješ hodnotu uvedenou v hranatých závorkách."
echo

while :; do
  if [[ -n "$DEFAULT_HOST" ]]; then
    read -r -p "IP_DB [$DEFAULT_HOST]: " IP_DB
    IP_DB="${IP_DB:-$DEFAULT_HOST}"
  else
    read -r -p "IP_DB [nenastaveno – zadej IP nebo hostname]: " IP_DB
  fi
  [[ -n "$IP_DB" ]] && break
  echo "IP_DB zatím nemá výchozí hodnotu; zadej adresu databázového serveru."
done

read -r -p "PORT [$DEFAULT_PORT]: " PORT
PORT="${PORT:-$DEFAULT_PORT}"
[[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )) || { echo "Neplatný port: $PORT" >&2; exit 1; }

read -r -p "DB_NAME [$DEFAULT_DB]: " DB_NAME
DB_NAME="${DB_NAME:-$DEFAULT_DB}"

read -r -p "PCBOX_NAME [$DEFAULT_PC]: " PCBOX_NAME
PCBOX_NAME="${PCBOX_NAME:-$DEFAULT_PC}"

BACKUP="${CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
cp -a "$CONFIG" "$BACKUP"
python3 - "$CONFIG" "$IP_DB" "$PORT" "$DB_NAME" "$PCBOX_NAME" <<'PY'
import json,sys
path, host, port, db, pc = sys.argv[1:]
with open(path, encoding='utf-8') as f:
    c=json.load(f)
c['DATABASE_HOST'] = host
c['DATABASE_PORT'] = int(port)
c['DATABASE_NAME'] = db
c['PCBOX_NAME'] = pc
with open(path, 'w', encoding='utf-8') as f:
    json.dump(c, f, ensure_ascii=False, indent=2)
    f.write('\n')
PY

echo
echo "Connection uložena:"
echo "  IP_DB:      $IP_DB"
echo "  PORT:       $PORT"
echo "  DB_NAME:    $DB_NAME"
echo "  PCBOX_NAME: $PCBOX_NAME"
echo "Záloha: $BACKUP"
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
# Interaktivní nastavení DB připojení aplikace ObjednávkaNG.
# Enter použije nabídnutou výchozí hodnotu.
set -Eeuo pipefail

CONFIG_LINK="/opt/objednavka-ng/config.json"
CONFIG="$(readlink -f "$CONFIG_LINK" 2>/dev/null || echo "$CONFIG_LINK")"
[[ -f "$CONFIG" ]] || { echo "Chybí config: $CONFIG" >&2; exit 1; }
[[ "$EUID" -ne 0 ]] || { echo "Spusť jako uživatel objng, bez sudo." >&2; exit 1; }

current() { python3 - "$CONFIG" "$1" <<'PY'
import json,sys
with open(sys.argv[1], encoding='utf-8') as f:
    c=json.load(f)
print(c.get(sys.argv[2], ''))
PY
}

CURRENT_HOST="$(current DATABASE_HOST)"
CURRENT_PORT="$(current DATABASE_PORT)"
CURRENT_DB="$(current DATABASE_NAME)"
CURRENT_PC="$(current PCBOX_NAME)"

# IP se jako výchozí převezme z dodaného config.json / aktuální konfigurace.
# Ostatní výchozí hodnoty jsou instalační standard projektu.
DEFAULT_HOST="$CURRENT_HOST"
DEFAULT_PORT="5432"
DEFAULT_DB="jidelna"
DEFAULT_PC="PCBOX"

echo "============================================================"
echo " ObjednávkaNG – nastavení connection"
echo "============================================================"
echo "Současné hodnoty v configu:"
echo "  IP_DB:       ${CURRENT_HOST:-nenastaveno}"
echo "  PORT:        ${CURRENT_PORT:-nenastaveno}"
echo "  DB_NAME:     ${CURRENT_DB:-nenastaveno}"
echo "  PCBOX_NAME:  ${CURRENT_PC:-nenastaveno}"
echo

echo "Stisknutím Enter použiješ hodnotu uvedenou v hranatých závorkách."
echo

while :; do
  if [[ -n "$DEFAULT_HOST" ]]; then
    read -r -p "IP_DB [$DEFAULT_HOST]: " IP_DB
    IP_DB="${IP_DB:-$DEFAULT_HOST}"
  else
    read -r -p "IP_DB [nenastaveno – zadej IP nebo hostname]: " IP_DB
  fi
  [[ -n "$IP_DB" ]] && break
  echo "IP_DB zatím nemá výchozí hodnotu; zadej adresu databázového serveru."
done

read -r -p "PORT [$DEFAULT_PORT]: " PORT
PORT="${PORT:-$DEFAULT_PORT}"
[[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )) || { echo "Neplatný port: $PORT" >&2; exit 1; }

read -r -p "DB_NAME [$DEFAULT_DB]: " DB_NAME
DB_NAME="${DB_NAME:-$DEFAULT_DB}"

read -r -p "PCBOX_NAME [$DEFAULT_PC]: " PCBOX_NAME
PCBOX_NAME="${PCBOX_NAME:-$DEFAULT_PC}"

BACKUP="${CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
cp -a "$CONFIG" "$BACKUP"
python3 - "$CONFIG" "$IP_DB" "$PORT" "$DB_NAME" "$PCBOX_NAME" <<'PY'
import json,sys
path, host, port, db, pc = sys.argv[1:]
with open(path, encoding='utf-8') as f:
    c=json.load(f)
c['DATABASE_HOST'] = host
c['DATABASE_PORT'] = int(port)
c['DATABASE_NAME'] = db
c['PCBOX_NAME'] = pc
with open(path, 'w', encoding='utf-8') as f:
    json.dump(c, f, ensure_ascii=False, indent=2)
    f.write('\n')
PY

echo
echo "Connection uložena:"
echo "  IP_DB:      $IP_DB"
echo "  PORT:       $PORT"
echo "  DB_NAME:    $DB_NAME"
echo "  PCBOX_NAME: $PCBOX_NAME"
echo "Záloha: $BACKUP"
