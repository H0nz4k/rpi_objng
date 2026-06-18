#!/usr/bin/env bash
# Reliable TeamViewer Host install for ObjednavkaNG MASTER BOOT FINAL v2.1.8.
set -Eeuo pipefail

TARGET_USER="${OBJNG_USER:-objng}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
PAYLOAD_DIR="${OBJNG_PAYLOAD:-$TARGET_HOME/bootstrap/v2/payload/teamviewer}"
OFFICIAL_URL="https://download.teamviewer.com/download/linux/teamviewer-host_arm64.deb"
LOG="$TARGET_HOME/objng_teamviewer_install.log"

[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo." >&2; exit 1; }
exec > >(tee -a "$LOG") 2>&1

fix_hosts_for_sudo() {
  local hn
  hn="$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)"
  [[ -n "$hn" ]] || return 0
  if grep -qE '^127\.0\.1\.1[[:space:]]' /etc/hosts 2>/dev/null; then
    sed -i "s/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t${hn}/" /etc/hosts 2>/dev/null || true
  elif ! grep -qE "[[:space:]]${hn}([[:space:]]|$)" /etc/hosts 2>/dev/null; then
    printf '127.0.1.1\t%s\n' "$hn" >> /etc/hosts
  fi
}

stop_packagekit() {
  systemctl stop packagekit.service 2>/dev/null || true
  pkill -x packagekitd 2>/dev/null || true
  sleep 1
}

teamviewer_ready() {
  command -v teamviewer >/dev/null 2>&1 || return 1
  dpkg-query -W -f='${Status}\n' teamviewer-host 2>/dev/null | grep -q 'install ok installed' || \
    dpkg-query -W -f='${Status}\n' 'teamviewer*' 2>/dev/null | grep -q 'install ok installed' || return 1
  pgrep -x teamviewerd >/dev/null 2>&1 && return 0
  systemctl is-active --quiet teamviewerd.service 2>/dev/null && return 0
  systemctl is-active teamviewerd.service 2>/dev/null | grep -qE '^(active|activating)$'
}

verify_teamviewer() {
  teamviewer_ready
}

if verify_teamviewer; then
  echo "TeamViewer uz je nainstalovany a sluzba bezi."
  teamviewer info 2>/dev/null || true
  exit 0
fi

fix_hosts_for_sudo

mkdir -p "$PAYLOAD_DIR"
DEB="$(find "$PAYLOAD_DIR" -maxdepth 1 -type f \
  \( -name 'teamviewer*.deb' -o -name 'teamviewer-host*.deb' \) \
  -print -quit 2>/dev/null || true)"

if [[ -z "$DEB" ]]; then
  DEB="$PAYLOAD_DIR/teamviewer-host_arm64.deb"
  echo "Lokalni TeamViewer DEB chybi; stahuji oficialni ARM64 Host."
  rm -f "$DEB.tmp"
  wget --timeout=60 --tries=3 -O "$DEB.tmp" "$OFFICIAL_URL"
  mv "$DEB.tmp" "$DEB"
  chown "$TARGET_USER:$(id -gn "$TARGET_USER")" "$DEB"
fi

dpkg-deb --info "$DEB" >/dev/null 2>&1 || { echo "Neplatny TeamViewer DEB: $DEB" >&2; exit 1; }
arch="$(dpkg-deb -f "$DEB" Architecture 2>/dev/null || true)"
[[ "$arch" == "arm64" || "$arch" == "all" ]] || { echo "Spatna architektura TeamViewer baliku: $arch" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
APT_OPTS=(
  -o Dpkg::Options::=--force-confdef
  -o Dpkg::Options::=--force-confold
)

stop_packagekit
if ! apt-get update; then
  echo "VAROVANI: apt-get update selhal."
  if [[ ! -f "$DEB" ]]; then
    echo "CHYBA: bez site a bez lokalniho DEB nelze TeamViewer nainstalovat." >&2
    exit 1
  fi
  echo "Pokracuji s lokalnim DEB bez obnovy seznamu baliku: $DEB"
fi

if apt-get "${APT_OPTS[@]}" install -y "$DEB"; then
  :
else
  echo "apt install selhal; zkousim prime nainstalovani DEB."
  dpkg -i "$DEB" || true
  apt-get "${APT_OPTS[@]}" -f install -y || {
    echo "CHYBA: TeamViewer DEB nelze nainstalovat (mozna chybi site pro zavislosti)." >&2
    exit 1
  }
fi

systemctl daemon-reload
systemctl enable teamviewerd.service
systemctl restart teamviewerd.service

for _ in $(seq 1 45); do
  if verify_teamviewer; then
    echo "TeamViewer byl uspesne nainstalovan a sluzba teamviewerd bezi."
    teamviewer info 2>/dev/null || true
    exit 0
  fi
  sleep 1
done

if pgrep -x teamviewerd >/dev/null 2>&1 || \
   dpkg-query -W -f='${Status}\n' teamviewer-host 2>/dev/null | grep -q 'install ok installed'; then
  echo "VAROVANI: teamviewerd nespustil is-active v casovem limitu, ale balik/proces existuje – pokracuji."
  systemctl start teamviewerd.service 2>/dev/null || true
  teamviewer info 2>/dev/null || true
  exit 0
fi

echo "CHYBA: TeamViewer se nepodarilo spustit." >&2
systemctl status teamviewerd.service --no-pager || true
exit 1
