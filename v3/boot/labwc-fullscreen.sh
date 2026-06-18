#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q # Spusti GUI prikaz a vynuti labwc fullscreen pres wlrctl (tkinter/XWayland).
set -euo pipefail

TITLE="${1:-}"
WM_CLASS="${2:-}"
shift 2
[[ $# -gt 0 ]] || { echo "Pouziti: $0 <title> <wm_class> <cmd...>" >&2; exit 2; }

minimize_boot_terminal() {
  command -v wlrctl >/dev/null 2>&1 || return 0
  local spec
  for spec in \
    "app_id:objng-master-boot" \
    "identifier:objng-master-boot" \
    "title:ObjednavkaNG MASTER BOOT*"
  do
    if wlrctl toplevel find "$spec" >/dev/null 2>&1; then
      wlrctl toplevel minimize "$spec" 2>/dev/null || true
      return 0
    fi
  done
}

apply_fullscreen() {
  command -v wlrctl >/dev/null 2>&1 || return 1
  local spec
  for spec in "$@"; do
    if wlrctl toplevel find "$spec" >/dev/null 2>&1; then
      wlrctl toplevel fullscreen "$spec" 2>/dev/null || true
      wlrctl toplevel focus "$spec" 2>/dev/null || true
      return 0
    fi
  done
  return 1
}

build_specs() {
  SPECS=()
  [[ -n "$WM_CLASS" ]] && SPECS+=("app_id:$WM_CLASS" "identifier:$WM_CLASS")
  [[ -n "$TITLE" ]] && SPECS+=("title:$TITLE" "title:${TITLE}*" "title:ObjednavkaNG*")
}

minimize_boot_terminal
build_specs

"$@" &
pid=$!

if command -v wlrctl >/dev/null 2>&1; then
  for _ in $(seq 1 100); do
    apply_fullscreen "${SPECS[@]}" && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.2
  done
fi

wait "$pid"
exit $?
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
# Spusti GUI prikaz a vynuti labwc fullscreen pres wlrctl (tkinter/XWayland).
set -euo pipefail

TITLE="${1:-}"
WM_CLASS="${2:-}"
shift 2
[[ $# -gt 0 ]] || { echo "Pouziti: $0 <title> <wm_class> <cmd...>" >&2; exit 2; }

minimize_boot_terminal() {
  command -v wlrctl >/dev/null 2>&1 || return 0
  local spec
  for spec in \
    "app_id:objng-master-boot" \
    "identifier:objng-master-boot" \
    "title:ObjednavkaNG MASTER BOOT*"
  do
    if wlrctl toplevel find "$spec" >/dev/null 2>&1; then
      wlrctl toplevel minimize "$spec" 2>/dev/null || true
      return 0
    fi
  done
}

apply_fullscreen() {
  command -v wlrctl >/dev/null 2>&1 || return 1
  local spec
  for spec in "$@"; do
    if wlrctl toplevel find "$spec" >/dev/null 2>&1; then
      wlrctl toplevel fullscreen "$spec" 2>/dev/null || true
      wlrctl toplevel focus "$spec" 2>/dev/null || true
      return 0
    fi
  done
  return 1
}

build_specs() {
  SPECS=()
  [[ -n "$WM_CLASS" ]] && SPECS+=("app_id:$WM_CLASS" "identifier:$WM_CLASS")
  [[ -n "$TITLE" ]] && SPECS+=("title:$TITLE" "title:${TITLE}*" "title:ObjednavkaNG*")
}

minimize_boot_terminal
build_specs

"$@" &
pid=$!

if command -v wlrctl >/dev/null 2>&1; then
  for _ in $(seq 1 100); do
    apply_fullscreen "${SPECS[@]}" && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.2
  done
fi

wait "$pid"
exit $?
