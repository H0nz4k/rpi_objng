#!/usr/bin/env bash
# Obnovi focus firstboot terminalu po fullscreen GUI (kalibrace, test touch).
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

command -v wlrctl >/dev/null 2>&1 || exit 0

for spec in \
  "app_id:objng-master-boot" \
  "identifier:objng-master-boot" \
  "title:ObjednavkaNG MASTER BOOT*"
do
  if wlrctl toplevel find "$spec" >/dev/null 2>&1; then
    wlrctl toplevel focus "$spec" state:minimized 2>/dev/null || \
      wlrctl toplevel focus "$spec" 2>/dev/null || true
    wlrctl toplevel focus "$spec" 2>/dev/null || true
    exit 0
  fi
done
