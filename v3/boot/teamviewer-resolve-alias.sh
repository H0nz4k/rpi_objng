#!/usr/bin/env bash
# Sestavi nazev zarizeni pro TeamViewer: "<lokalita>, RPIbox"
set -Eeuo pipefail

format_teamviewer_alias() {
  local raw="${1:-}" suffix="RPIbox"
  raw="${raw//$'\r'/}"
  raw="${raw//$'\n'/}"
  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"
  [[ -n "$raw" ]] || return 1
  if [[ "$raw" == *","* ]]; then
    echo "$raw"
    return 0
  fi
  if [[ "${raw,,}" == "rpibox" ]]; then
    echo "RPIbox"
    return 0
  fi
  echo "${raw}, ${suffix}"
}

# Vypis alias na stdout; pri neuspechu vrati 1.
resolve_teamviewer_alias() {
  local preset="" config="" loc=""
  if [[ -n "${TEAMVIEWER_ALIAS:-}" ]]; then
    format_teamviewer_alias "$TEAMVIEWER_ALIAS" && return 0
  fi
  if [[ -s "${TEAMVIEWER_ALIAS_FILE:-}" ]]; then
    preset="$(tr -d '\r\n' < "${TEAMVIEWER_ALIAS_FILE}")"
    if formatted="$(format_teamviewer_alias "$preset" 2>/dev/null)"; then
      echo "$formatted"
      return 0
    fi
  fi
  if [[ -s "${TEAMVIEWER_ALIAS_SECRET:-}" ]]; then
    preset="$(tr -d '\r\n' < "${TEAMVIEWER_ALIAS_SECRET}")"
    if formatted="$(format_teamviewer_alias "$preset" 2>/dev/null)"; then
      echo "$formatted"
      return 0
    fi
  fi
  if [[ -n "${TEAMVIEWER_LOCATION:-}" ]]; then
    format_teamviewer_alias "$TEAMVIEWER_LOCATION" && return 0
  fi
  config="${TEAMVIEWER_CONFIG:-/opt/objednavka-ng/config.json}"
  if [[ -f "$config" ]]; then
    preset="$(python3 - "$config" <<'PY'
import json, sys
try:
    v = str(json.load(open(sys.argv[1], encoding="utf-8")).get("PCBOX_NAME") or "").strip()
except Exception:
    v = ""
if v and "NASTAV" not in v.upper() and "SPRAVN" not in v.upper():
    print(v)
PY
)"
    if [[ -n "$preset" ]] && formatted="$(format_teamviewer_alias "$preset" 2>/dev/null)"; then
      echo "$formatted"
      return 0
    fi
  fi
  loc="$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)"
  [[ -n "$loc" ]] || return 1
  echo "$loc"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  resolve_teamviewer_alias
fi
