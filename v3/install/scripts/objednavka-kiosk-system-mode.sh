#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Spusť přes sudo." >&2; exit 1; }

MODE="${1:-}"
SYSTEM_AUTO="/etc/xdg/labwc/autostart"
[[ -f "$SYSTEM_AUTO" ]] || { echo "Nenalezen $SYSTEM_AUTO" >&2; exit 1; }
case "$MODE" in clean|desktop) ;; *) echo "Použití: sudo objednavka-kiosk-system-mode {clean|desktop}" >&2; exit 1 ;; esac

BACKUP="${SYSTEM_AUTO}.objednavka-backup.$(date +%Y%m%d_%H%M%S)"
cp -a "$SYSTEM_AUTO" "$BACKUP"

python3 - "$SYSTEM_AUTO" "$MODE" <<'PY'
from pathlib import Path
import re, sys
path = Path(sys.argv[1])
mode = sys.argv[2]
lines = path.read_text(encoding="utf-8").splitlines()
commands = {
    "pcmanfm": "/usr/bin/lwrespawn /usr/bin/pcmanfm-pi &",
    "panel": "/usr/bin/lwrespawn /usr/bin/wf-panel-pi &",
}
patterns = {
    k: re.compile(r"^\s*#?\s*" + re.escape(v[:-1]).replace(r"\ ", r"\s+") + r"\s*&?\s*$")
    for k, v in commands.items()
}
found = {k: False for k in commands}
result = []
for line in lines:
    for key, pattern in patterns.items():
        if pattern.match(line):
            found[key] = True
            result.append("# " + commands[key] if mode == "clean" else commands[key])
            break
    else:
        result.append(line)
for key, was_found in found.items():
    if not was_found:
        result.insert(0, "# " + commands[key] if mode == "clean" else commands[key])
path.write_text("\n".join(result).rstrip() + "\n", encoding="utf-8")
PY

echo "Systémová plocha po příštím startu: $([[ "$MODE" == clean ]] && echo SKRYTÁ || echo ZOBRAZENÁ)"
echo "Záloha: $BACKUP"
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Spusť přes sudo." >&2; exit 1; }

MODE="${1:-}"
SYSTEM_AUTO="/etc/xdg/labwc/autostart"
[[ -f "$SYSTEM_AUTO" ]] || { echo "Nenalezen $SYSTEM_AUTO" >&2; exit 1; }
case "$MODE" in clean|desktop) ;; *) echo "Použití: sudo objednavka-kiosk-system-mode {clean|desktop}" >&2; exit 1 ;; esac

BACKUP="${SYSTEM_AUTO}.objednavka-backup.$(date +%Y%m%d_%H%M%S)"
cp -a "$SYSTEM_AUTO" "$BACKUP"

python3 - "$SYSTEM_AUTO" "$MODE" <<'PY'
from pathlib import Path
import re, sys
path = Path(sys.argv[1])
mode = sys.argv[2]
lines = path.read_text(encoding="utf-8").splitlines()
commands = {
    "pcmanfm": "/usr/bin/lwrespawn /usr/bin/pcmanfm-pi &",
    "panel": "/usr/bin/lwrespawn /usr/bin/wf-panel-pi &",
}
patterns = {
    k: re.compile(r"^\s*#?\s*" + re.escape(v[:-1]).replace(r"\ ", r"\s+") + r"\s*&?\s*$")
    for k, v in commands.items()
}
found = {k: False for k in commands}
result = []
for line in lines:
    for key, pattern in patterns.items():
        if pattern.match(line):
            found[key] = True
            result.append("# " + commands[key] if mode == "clean" else commands[key])
            break
    else:
        result.append(line)
for key, was_found in found.items():
    if not was_found:
        result.insert(0, "# " + commands[key] if mode == "clean" else commands[key])
path.write_text("\n".join(result).rstrip() + "\n", encoding="utf-8")
PY

echo "Systémová plocha po příštím startu: $([[ "$MODE" == clean ]] && echo SKRYTÁ || echo ZOBRAZENÁ)"
echo "Záloha: $BACKUP"
