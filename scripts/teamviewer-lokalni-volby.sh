#!/usr/bin/env bash
# Experimentální patch dvou lokálních preferencí TeamVieweru se zálohou.
set -Eeuo pipefail
CONF="/opt/teamviewer/config/global.conf"; BACKUP_DIR="/opt/objednavka-ng/backups/teamviewer"; MODE="${1:-preview}"
[[ "$EUID" -eq 0 ]] || { echo "Spusť přes sudo: sudo teamviewer-lokalni-volby $MODE" >&2; exit 1; }
mkdir -p "$BACKUP_DIR"
case "$MODE" in
  preview)
    echo "Tento krok je EXPERIMENTÁLNÍ; oficiálně ověřuj volby v TeamViewer GUI."
    echo 'Navržené hodnoty: [strng] LastSelectedLanguage = "cs"'; echo '                  [int32] General_DirectLAN = 1'; echo "Soubor: $CONF"
    [[ -f "$CONF" ]] && grep -E '^\[(strng|int32)\][[:space:]]+(LastSelectedLanguage|General_DirectLAN)[[:space:]]*=' "$CONF" || true
    ;;
  apply)
    [[ -f "$CONF" ]] || { echo "Nenalezen $CONF. Nejprve spusť/dokonči TeamViewer." >&2; exit 1; }
    backup="$BACKUP_DIR/global.conf.before-local-options.$(date +%Y%m%d_%H%M%S)"; cp -a "$CONF" "$backup"; systemctl stop teamviewerd 2>/dev/null || true
    python3 - "$CONF" <<'PY'
from pathlib import Path
import re, sys
p=Path(sys.argv[1]); s=p.read_text(errors='replace')
for pat, line in [(r'^\[strng\]\s+LastSelectedLanguage\s*=.*$', '[strng] LastSelectedLanguage = "cs"'), (r'^\[int32\]\s+General_DirectLAN\s*=.*$', '[int32] General_DirectLAN = 1')]:
    if re.search(pat, s, flags=re.M): s=re.sub(pat, line, s, flags=re.M)
    else: s=s.rstrip()+'\n'+line+'\n'
p.write_text(s)
PY
    systemctl start teamviewerd 2>/dev/null || true; echo "Experimentální preference zapsány. Záloha: $backup"; echo "Nyní zkontroluj LAN připojení a jazyk přímo v TeamViewer GUI."
    ;;
  restore)
    latest="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'global.conf.before-local-options.*' | sort | tail -1)"; [[ -n "$latest" ]] || { echo "Záloha nebyla nalezena." >&2; exit 1; }
    systemctl stop teamviewerd 2>/dev/null || true; cp -a "$latest" "$CONF"; systemctl start teamviewerd 2>/dev/null || true; echo "Obnoveno ze zálohy: $latest"
    ;;
  *) echo "Použití: sudo teamviewer-lokalni-volby {preview|apply|restore}" >&2; exit 1 ;;
esac
