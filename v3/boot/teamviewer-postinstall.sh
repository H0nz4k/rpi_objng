#!/usr/bin/env bash
# TeamViewer lokalni nastaveni po instalaci (vzdy, i bez Assignment ID).
set -Eeuo pipefail

[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo." >&2; exit 1; }
command -v teamviewer >/dev/null 2>&1 || { echo "TeamViewer neni nainstalovan." >&2; exit 1; }

TARGET_USER="${OBJNG_USER:-objng}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
SECRETS="${TEAMVIEWER_SECRETS_DIR:-$TARGET_HOME/bootstrap/v2/secrets}"
ALIAS_SECRET="$SECRETS/teamviewer-alias"
PASSWORD_SECRET="$SECRETS/teamviewer-password"
CONFIG_LINK="/opt/objednavka-ng/config.json"

read_secret() {
  local file="$1"
  [[ -s "$file" ]] || return 1
  tr -d '\r\n' < "$file"
}

resolve_alias() {
  local helper="$TARGET_HOME/bin/teamviewer-resolve-alias.sh"
  if [[ -x "$helper" ]]; then
    TEAMVIEWER_ALIAS_SECRET="$ALIAS_SECRET" TEAMVIEWER_CONFIG="$(readlink -f "$CONFIG_LINK" 2>/dev/null || echo "$CONFIG_LINK")" \
      "$helper" && return 0
  fi
  hostname
}

systemctl enable --now teamviewerd.service 2>/dev/null || true

# Automaticke prijeti EULA/DPA – skryje dialog pri prvnim spusteni GUI.
set +e
teamviewer license accept >/dev/null 2>&1 || true
# Zapis primo do global.conf jako zalozni metoda.
for cfg in \
  /etc/teamviewer/global.conf \
  /opt/teamviewer/config/global.conf \
  /opt/teamviewer/tv_bin/script/../../../config/global.conf
do
  if [[ -f "$cfg" ]]; then
    if ! grep -q 'LicenseAgreementStatus' "$cfg" 2>/dev/null; then
      printf '\n[Global]\nLicenseAgreementStatus = 1\n' >> "$cfg" 2>/dev/null || true
    else
      sed -i 's/LicenseAgreementStatus\s*=.*/LicenseAgreementStatus = 1/' "$cfg" 2>/dev/null || true
    fi
  fi
done
set -e

export TEAMVIEWER_ALIAS="$(resolve_alias)"
if ! teamviewer-lokalni-volby apply; then
  echo "VAROVANI: teamviewer-lokalni-volby apply selhal." >&2
fi

if ! teamviewer-updates-off; then
  echo "VAROVANI: teamviewer-updates-off selhal." >&2
fi

if password="$(read_secret "$PASSWORD_SECRET" 2>/dev/null || true)"; then
  if [[ -n "$password" ]]; then
    rc=1
    set +e
    if teamviewer passwd "$password" >/dev/null 2>&1; then
      rc=0
    elif teamviewer --passwd "$password" >/dev/null 2>&1; then
      rc=0
    elif teamviewer help 2>&1 | grep -qi passwd; then
      teamviewer passwd <<<"$password" >/dev/null 2>&1 && rc=0
    fi
    set -e
    if [[ "$rc" -eq 0 ]]; then
      echo "TeamViewer heslo bylo nastaveno ze secret souboru."
    else
      echo "VAROVANI: nastaveni TeamViewer hesla selhalo; over verzi prikazu teamviewer passwd." >&2
    fi
  fi
else
  echo "TeamViewer heslo nebylo nastaveno (chybi $PASSWORD_SECRET)."
fi

echo "TeamViewer lokalni nastaveni dokonceno: jazyk cs, LAN, apt hold, alias=${TEAMVIEWER_ALIAS}."
