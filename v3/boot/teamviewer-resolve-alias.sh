#!/usr/bin/env bash
# Sestavi nazev zarizeni pro TeamViewer: "<lokalita>, RPIbox"
# Postfix ", RPIbox" je VZDY – uzivatel zadava jen zacatek (lokalitu).
set -Eeuo pipefail

TV_ALIAS_SUFFIX=", RPIbox"

format_teamviewer_alias() {
  local raw="${1:-}"
  raw="${raw//$'\r'/}"
  raw="${raw//$'\n'/}"
  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"
  [[ -n "$raw" ]] || return 1

  # Uz kompletni tvar (Liberec, RPIbox)
  if [[ "$raw" == *", "* ]]; then
    echo "$raw"
    return 0
  fi

  # Jen zacatek bez postfixu -> doplnit ", RPIbox"
  echo "${raw}${TV_ALIAS_SUFFIX}"
}

resolve_teamviewer_alias() {
  local preset="" config=""

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
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  resolve_teamviewer_alias
fi
