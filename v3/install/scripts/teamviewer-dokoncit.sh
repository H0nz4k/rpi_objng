#!/usr/bin/env bash
# TeamViewer completion: prirazeni do spravy (Assignment ID).
set -Eeuo pipefail

[[ "$EUID" -ne 0 ]] || { echo "Spust jako uzivatel objng, bez sudo." >&2; exit 1; }
command -v teamviewer >/dev/null 2>&1 || { echo "TeamViewer neni nainstalovan." >&2; exit 1; }

CONFIG_LINK="/opt/objednavka-ng/config.json"
CONFIG="$(readlink -f "$CONFIG_LINK" 2>/dev/null || echo "$CONFIG_LINK")"
SECRETS="${TEAMVIEWER_SECRETS_DIR:-$HOME/bootstrap/v2/secrets}"
SECRET_FILE="${TEAMVIEWER_ASSIGNMENT_FILE:-$SECRETS/teamviewer-assignment-id}"
ALIAS_SECRET="$SECRETS/teamviewer-alias"
ASSIGNMENT_ID="${TEAMVIEWER_ASSIGNMENT_ID:-}"

if [[ -z "$ASSIGNMENT_ID" && -s "$SECRET_FILE" ]]; then
  ASSIGNMENT_ID="$(tr -d '\r\n' < "$SECRET_FILE")"
fi

resolve_alias() {
  local alias=""
  if [[ -s "$ALIAS_SECRET" ]]; then
    alias="$(tr -d '\r\n' < "$ALIAS_SECRET")"
    [[ -n "$alias" ]] && { echo "$alias"; return 0; }
  fi
  alias="$(hostname)"
  if [[ -f "$CONFIG" ]]; then
    cfg_alias="$(python3 - "$CONFIG" <<'PY'
import json, sys
try:
    v = str(json.load(open(sys.argv[1], encoding="utf-8")).get("PCBOX_NAME") or "").strip()
except Exception:
    v = ""
if v and "NASTAV" not in v.upper() and "SPRAVN" not in v.upper():
    print(v)
PY
)"
    [[ -n "$cfg_alias" ]] && alias="$cfg_alias"
  fi
  echo "$alias"
}

if [[ -z "$ASSIGNMENT_ID" ]]; then
  echo "Assignment ID nebylo vlozeno; prirazeni do spravy bylo preskoceno."
  echo "Lokalni nastaveni (jazyk, LAN, heslo) resi: sudo teamviewer-postinstall"
  echo "Pozdeji vloz ID do $SECRET_FILE a spust: teamviewer-dokoncit"
  exit 0
fi

DEFAULT_ALIAS="$(resolve_alias)"
help_text="$(teamviewer assignment --help 2>&1 || true)"
if grep -q -- '--device-alias' <<<"$help_text"; then
  alias_opt="--device-alias"
else
  alias_opt="--device_alias"
fi

echo "Prirazuji TeamViewer jako: $DEFAULT_ALIAS"
set +e
sudo -n teamviewer assignment \
  --id "$ASSIGNMENT_ID" \
  "$alias_opt" "$DEFAULT_ALIAS" \
  --offline
rc=$?
set -e
unset ASSIGNMENT_ID

if [[ "$rc" -eq 0 || "$rc" -eq 49 ]]; then
  echo "TeamViewer assignment byl prijat nebo je zarizeni jiz spravovane."
  exit 0
fi

if [[ "$rc" -eq 43 ]]; then
  echo "VAROVANI: TeamViewer assignment bez internetu (kod 43)."
  echo "Lokalni nastaveni je hotove. Spustte pozdeji: teamviewer-dokoncit"
  exit 0
fi

echo "TeamViewer assignment selhal, kod: $rc" >&2
exit "$rc"
