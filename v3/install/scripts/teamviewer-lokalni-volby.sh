#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q # Lokalni preference TeamVieweru (jazyk, LAN, alias) se zalohou global.conf.
set -Eeuo pipefail
CONF="/opt/teamviewer/config/global.conf"
BACKUP_DIR="/opt/objednavka-ng/backups/teamviewer"
MODE="${1:-preview}"
ALIAS="${TEAMVIEWER_ALIAS:-}"
[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo: sudo teamviewer-lokalni-volby $MODE" >&2; exit 1; }
mkdir -p "$BACKUP_DIR"
case "$MODE" in
  preview)
    echo "Lokalni preference TeamVieweru (experimentalni patch global.conf)."
    echo '  [strng] LastSelectedLanguage = "cs"'
    echo '  [int32] General_DirectLAN = 1'
    [[ -n "$ALIAS" ]] && echo "  [strng] ClientAlias = \"$ALIAS\""
    echo "Soubor: $CONF"
    [[ -f "$CONF" ]] && grep -E '^\[(strng|int32)\][[:space:]]+(LastSelectedLanguage|General_DirectLAN|ClientAlias)[[:space:]]*=' "$CONF" || true
    ;;
  apply)
    [[ -f "$CONF" ]] || { echo "Nenalezen $CONF. Nejprve spust TeamViewer instalaci." >&2; exit 1; }
    backup="$BACKUP_DIR/global.conf.before-local-options.$(date +%Y%m%d_%H%M%S)"
    cp -a "$CONF" "$backup"
    systemctl stop teamviewerd 2>/dev/null || true
    python3 - "$CONF" "$ALIAS" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
alias = (sys.argv[2] if len(sys.argv) > 2 else "").strip()
s = p.read_text(errors="replace")
lines = [
    (r'^\[strng\]\s+LastSelectedLanguage\s*=.*$', '[strng] LastSelectedLanguage = "cs"'),
    (r'^\[int32\]\s+General_DirectLAN\s*=.*$', '[int32] General_DirectLAN = 1'),
]
if alias:
    esc = alias.replace("\\", "\\\\").replace('"', '\\"')
    lines.append((r'^\[strng\]\s+ClientAlias\s*=.*$', f'[strng] ClientAlias = "{esc}"'))
for pat, line in lines:
    if re.search(pat, s, flags=re.M):
        s = re.sub(pat, line, s, flags=re.M)
    else:
        s = s.rstrip() + "\n" + line + "\n"
p.write_text(s)
PY
    systemctl start teamviewerd 2>/dev/null || true
    echo "Lokalni preference zapsany. Zaloha: $backup"
    ;;
  restore)
    latest="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'global.conf.before-local-options.*' | sort | tail -1)"
    [[ -n "$latest" ]] || { echo "Zaloha nebyla nalezena." >&2; exit 1; }
    systemctl stop teamviewerd 2>/dev/null || true
    cp -a "$latest" "$CONF"
    systemctl start teamviewerd 2>/dev/null || true
    echo "Obnoveno ze zalohy: $latest"
    ;;
  *) echo "Pouziti: sudo teamviewer-lokalni-volby {preview|apply|restore}" >&2; exit 1 ;;
esac
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
# Lokalni preference TeamVieweru (jazyk, LAN, alias) se zalohou global.conf.
set -Eeuo pipefail
CONF="/opt/teamviewer/config/global.conf"
BACKUP_DIR="/opt/objednavka-ng/backups/teamviewer"
MODE="${1:-preview}"
ALIAS="${TEAMVIEWER_ALIAS:-}"
[[ "$EUID" -eq 0 ]] || { echo "Spust pres sudo: sudo teamviewer-lokalni-volby $MODE" >&2; exit 1; }
mkdir -p "$BACKUP_DIR"
case "$MODE" in
  preview)
    echo "Lokalni preference TeamVieweru (experimentalni patch global.conf)."
    echo '  [strng] LastSelectedLanguage = "cs"'
    echo '  [int32] General_DirectLAN = 1'
    [[ -n "$ALIAS" ]] && echo "  [strng] ClientAlias = \"$ALIAS\""
    echo "Soubor: $CONF"
    [[ -f "$CONF" ]] && grep -E '^\[(strng|int32)\][[:space:]]+(LastSelectedLanguage|General_DirectLAN|ClientAlias)[[:space:]]*=' "$CONF" || true
    ;;
  apply)
    [[ -f "$CONF" ]] || { echo "Nenalezen $CONF. Nejprve spust TeamViewer instalaci." >&2; exit 1; }
    backup="$BACKUP_DIR/global.conf.before-local-options.$(date +%Y%m%d_%H%M%S)"
    cp -a "$CONF" "$backup"
    systemctl stop teamviewerd 2>/dev/null || true
    python3 - "$CONF" "$ALIAS" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
alias = (sys.argv[2] if len(sys.argv) > 2 else "").strip()
s = p.read_text(errors="replace")
lines = [
    (r'^\[strng\]\s+LastSelectedLanguage\s*=.*$', '[strng] LastSelectedLanguage = "cs"'),
    (r'^\[int32\]\s+General_DirectLAN\s*=.*$', '[int32] General_DirectLAN = 1'),
]
if alias:
    esc = alias.replace("\\", "\\\\").replace('"', '\\"')
    lines.append((r'^\[strng\]\s+ClientAlias\s*=.*$', f'[strng] ClientAlias = "{esc}"'))
for pat, line in lines:
    if re.search(pat, s, flags=re.M):
        s = re.sub(pat, line, s, flags=re.M)
    else:
        s = s.rstrip() + "\n" + line + "\n"
p.write_text(s)
PY
    systemctl start teamviewerd 2>/dev/null || true
    echo "Lokalni preference zapsany. Zaloha: $backup"
    ;;
  restore)
    latest="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'global.conf.before-local-options.*' | sort | tail -1)"
    [[ -n "$latest" ]] || { echo "Zaloha nebyla nalezena." >&2; exit 1; }
    systemctl stop teamviewerd 2>/dev/null || true
    cp -a "$latest" "$CONF"
    systemctl start teamviewerd 2>/dev/null || true
    echo "Obnoveno ze zalohy: $latest"
    ;;
  *) echo "Pouziti: sudo teamviewer-lokalni-volby {preview|apply|restore}" >&2; exit 1 ;;
esac
