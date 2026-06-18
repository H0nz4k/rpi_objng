#!/usr/bin/env bash
# Guard: CRLF fix + zajistit bash (ne sh/dash)
if grep -q # Jednoducha automaticka obsluha touch pro firstboot.
set -Eeuo pipefail

USER_HOME="/home/objng"
STATE_DIR="$USER_HOME/.local/state/objng-master-bootstrap"
TYPE_FILE="$STATE_DIR/touch.type"
CALIBRATOR="$USER_HOME/bin/touch_calibrator_v3.py"
CAL_STATE="$USER_HOME/.local/state/objednavka-ng-touch-calibrator"
APPLY_3M="$CAL_STATE/apply-calibration.sh"
SUCCESS_3M="$CAL_STATE/calibration.success"
RULE_3M="/etc/udev/rules.d/99-objednavka-ng-touchscreen-calibration.rules"
DISPLAY_VALUE="${DISPLAY:-:0}"
XAUTHORITY_VALUE="${XAUTHORITY:-$USER_HOME/.Xauthority}"
mkdir -p "$STATE_DIR"

find_type() {
  local e=0 m=0
  lsusb 2>/dev/null | grep -qi '0eef:0001' && e=1 || true
  lsusb 2>/dev/null | grep -qi '0596:0001' && m=1 || true
  if [[ "$e" -eq 1 && "$m" -eq 1 ]]; then echo multiple; return; fi
  if [[ "$e" -eq 1 ]]; then echo egalax; return; fi
  if [[ "$m" -eq 1 ]]; then echo 3m; return; fi
  echo none
}

find_3m_event() {
  python3 - <<'PY'
from evdev import InputDevice, ecodes, list_devices

def touch_keys(dev):
    keys = set(dev.capabilities(absinfo=False).get(ecodes.EV_KEY, []))
    return any(code in keys for code in (
        getattr(ecodes, "BTN_TOUCH", -1),
        getattr(ecodes, "BTN_TOOL_FINGER", -1),
        getattr(ecodes, "BTN_LEFT", -1),
    ))

items = []
for path in list_devices():
    try:
        d = InputDevice(path)
        if d.info.vendor != 0x0596 or d.info.product != 0x0001:
            continue
        codes = set(d.capabilities(absinfo=False).get(ecodes.EV_ABS, []))
        if not ({ecodes.ABS_X, ecodes.ABS_Y} <= codes or {ecodes.ABS_MT_POSITION_X, ecodes.ABS_MT_POSITION_Y} <= codes):
            continue
        name = (d.name or "").lower()
        score = (100 if touch_keys(d) else 0) + (30 if "touchscreen" in name else 0) + (20 if "ex ii" in name else 0)
        items.append((score, path))
    except OSError:
        pass
if items:
    print(sorted(items, reverse=True)[0][1])
PY
}

verify_3m_loaded() {
  local event prop
  event="$(find_3m_event)"
  [[ -n "$event" && -s "$RULE_3M" ]] || return 1
  prop="$(udevadm info --query=property --name="$event" 2>/dev/null | grep '^LIBINPUT_CALIBRATION_MATRIX=' || true)"
  [[ -n "$prop" ]]
}

active_output() {
  command -v wlr-randr >/dev/null 2>&1 || return 0
  wlr-randr 2>/dev/null | awk '/^[^[:space:]]/{out=$1} /Enabled:[[:space:]]+yes/{print out; exit}'
}

fix_old_noop_mapping() {
  local rc="$USER_HOME/.config/labwc/rc.xml" out
  [[ -f "$rc" ]] || return 0
  out="$(active_output)"
  [[ -n "$out" ]] || return 0
  cp -a "$rc" "$rc.before-touch-bootstrap" 2>/dev/null || true
  sed -i "s/mapToOutput=\"NOOP-1\"/mapToOutput=\"$out\"/g" "$rc"
}

reset_3m() {
  sudo -n rm -f "$RULE_3M"
  rm -rf "$USER_HOME/.local/state/objednavka-ng-touch-calibrator"
  sudo -n udevadm control --reload-rules 2>/dev/null || true
}

reset_touch() {
  local t="$(find_type)"
  rm -f "$STATE_DIR/touch.calibration-pending" "$STATE_DIR/touch.done" "$STATE_DIR/phase3.ready"
  case "$t" in
    3m) reset_3m ;;
    egalax)
      # EETI driver zustava nainstalovany. Nova eCalib kalibrace stare hodnoty prepise.
      sudo -n pkill -x eCalib 2>/dev/null || true
      ;;
  esac
}

run_3m_calibration() {
  fix_old_noop_mapping
  reset_3m
  rm -f "$SUCCESS_3M"

  set +e
  timeout --signal=TERM --kill-after=5 240 \
    env DISPLAY="$DISPLAY_VALUE" XAUTHORITY="$XAUTHORITY_VALUE" \
    "$USER_HOME/bin/labwc-fullscreen.sh" "ObjednavkaNG - kalibrace 3M touch" ObjngTouchCalibrator \
    "$CALIBRATOR" --auto-close-seconds 1.2
  local rc=$?
  set -e

  # O dalsim kroku rozhoduje atomicky success marker, ne pouze GUI exit code.
  if [[ ! -s "$SUCCESS_3M" ]]; then
    echo "CHYBA: 3M kalibrator nedokoncil ulozeni (kod procesu $rc)." >&2
    return 1
  fi
  [[ -x "$APPLY_3M" ]] || { echo "CHYBA: chybi $APPLY_3M" >&2; return 1; }

  sudo -n "$APPLY_3M"
  echo 3m > "$TYPE_FILE"
  touch "$STATE_DIR/touch.calibration-pending"
  sync
  return 10
}

close_ecalib() {
  sudo -n pkill -TERM -x eCalib 2>/dev/null || true
  sleep 1
  sudo -n pkill -KILL -x eCalib 2>/dev/null || true
}

run_egalax_calibration() {
  if [[ ! -x /usr/bin/eCalib || ! -x /usr/bin/eGTouchD || ! -f /etc/eGTouchL.ini ]]; then
    local install_rc=0
    sudo -n "$USER_HOME/bin/install-egalax-eeti-bootstrap.sh" --accept-license || install_rc=$?
    if [[ "$install_rc" -ne 0 ]]; then
      echo "CHYBA: instalace EETI driveru selhala, kod $install_rc." >&2
      return "$install_rc"
    fi
    echo egalax > "$TYPE_FILE"
    return 20
  fi

  sudo -n systemctl enable --now eGTouchD.service 2>/dev/null || true
  local log="$STATE_DIR/ecalib.log"
  rm -f "$log"
  close_ecalib
  set +e
  printf '1\n' | sudo -n env DISPLAY="$DISPLAY_VALUE" XAUTHORITY="$XAUTHORITY_VALUE" \
    /usr/bin/script -qefc /usr/bin/eCalib "$log" &
  local pid=$!
  set -e

  local ok=0
  for _ in $(seq 1 900); do
    if grep -Eqi 'Calibration[[:space:]]+is[[:space:]]+ok|Calibration.*ok' "$log" 2>/dev/null; then
      ok=1
      break
    fi
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  close_ecalib
  set +e
  wait "$pid" 2>/dev/null
  set -e
  [[ "$ok" -eq 1 ]] || { echo "CHYBA: eCalib nepotvrdil uspesnou kalibraci." >&2; return 1; }
  echo egalax > "$TYPE_FILE"
  touch "$STATE_DIR/touch.calibration-pending"
  sync
  return 10
}

calibrate() {
  local t="$(find_type)" rc=0
  case "$t" in
    3m) run_3m_calibration || rc=$? ;;
    egalax) run_egalax_calibration || rc=$? ;;
    multiple) echo "CHYBA: současně připojen 3M i eGalax." >&2; return 1 ;;
    *) echo "CHYBA: podporovany touch nebyl nalezen." >&2; return 1 ;;
  esac
  return "$rc"
}

verify() {
  local t="$(cat "$TYPE_FILE" 2>/dev/null || find_type)"
  case "$t" in
    3m)
      sudo -n udevadm control --reload-rules 2>/dev/null || true
      sudo -n udevadm trigger --subsystem-match=input --action=change 2>/dev/null || true
      local attempt
      for attempt in $(seq 1 45); do
        verify_3m_loaded && return 0
        sleep 1
      done
      echo "CHYBA: udev matice se po rebootu nenacetla do 45 s." >&2
      return 1
      ;;
    egalax)
      [[ -x /usr/bin/eCalib && -x /usr/bin/eGTouchD && -f /etc/eGTouchL.ini ]] || return 1
      systemctl is-active --quiet eGTouchD.service || pgrep -x eGTouchD >/dev/null 2>&1 || return 1
      grep -qi 'eGalaxTouch Virtual Device' /proc/bus/input/devices
      ;;
    *) return 1 ;;
  esac
}

case "${1:-}" in
  --detect) find_type ;;
  --calibrate)
    rc=0
    calibrate || rc=$?
    exit "$rc"
    ;;
  --verify) verify ;;
  --reset) reset_touch ;;
  *) echo "Pouziti: $0 {--detect|--calibrate|--verify|--reset}" >&2; exit 2 ;;
esac
\r' "#!/usr/bin/env bash
" 2>/dev/null; then sed -i 's/\r//' "#!/usr/bin/env bash
"; exec bash "#!/usr/bin/env bash
" "$@"; fi
if [ -z "${BASH_VERSION:-}" ]; then exec bash "#!/usr/bin/env bash
" "$@"; fi
# Jednoducha automaticka obsluha touch pro firstboot.
set -Eeuo pipefail

USER_HOME="/home/objng"
STATE_DIR="$USER_HOME/.local/state/objng-master-bootstrap"
TYPE_FILE="$STATE_DIR/touch.type"
CALIBRATOR="$USER_HOME/bin/touch_calibrator_v3.py"
CAL_STATE="$USER_HOME/.local/state/objednavka-ng-touch-calibrator"
APPLY_3M="$CAL_STATE/apply-calibration.sh"
SUCCESS_3M="$CAL_STATE/calibration.success"
RULE_3M="/etc/udev/rules.d/99-objednavka-ng-touchscreen-calibration.rules"
DISPLAY_VALUE="${DISPLAY:-:0}"
XAUTHORITY_VALUE="${XAUTHORITY:-$USER_HOME/.Xauthority}"
mkdir -p "$STATE_DIR"

find_type() {
  local e=0 m=0
  lsusb 2>/dev/null | grep -qi '0eef:0001' && e=1 || true
  lsusb 2>/dev/null | grep -qi '0596:0001' && m=1 || true
  if [[ "$e" -eq 1 && "$m" -eq 1 ]]; then echo multiple; return; fi
  if [[ "$e" -eq 1 ]]; then echo egalax; return; fi
  if [[ "$m" -eq 1 ]]; then echo 3m; return; fi
  echo none
}

find_3m_event() {
  python3 - <<'PY'
from evdev import InputDevice, ecodes, list_devices

def touch_keys(dev):
    keys = set(dev.capabilities(absinfo=False).get(ecodes.EV_KEY, []))
    return any(code in keys for code in (
        getattr(ecodes, "BTN_TOUCH", -1),
        getattr(ecodes, "BTN_TOOL_FINGER", -1),
        getattr(ecodes, "BTN_LEFT", -1),
    ))

items = []
for path in list_devices():
    try:
        d = InputDevice(path)
        if d.info.vendor != 0x0596 or d.info.product != 0x0001:
            continue
        codes = set(d.capabilities(absinfo=False).get(ecodes.EV_ABS, []))
        if not ({ecodes.ABS_X, ecodes.ABS_Y} <= codes or {ecodes.ABS_MT_POSITION_X, ecodes.ABS_MT_POSITION_Y} <= codes):
            continue
        name = (d.name or "").lower()
        score = (100 if touch_keys(d) else 0) + (30 if "touchscreen" in name else 0) + (20 if "ex ii" in name else 0)
        items.append((score, path))
    except OSError:
        pass
if items:
    print(sorted(items, reverse=True)[0][1])
PY
}

verify_3m_loaded() {
  local event prop
  event="$(find_3m_event)"
  [[ -n "$event" && -s "$RULE_3M" ]] || return 1
  prop="$(udevadm info --query=property --name="$event" 2>/dev/null | grep '^LIBINPUT_CALIBRATION_MATRIX=' || true)"
  [[ -n "$prop" ]]
}

active_output() {
  command -v wlr-randr >/dev/null 2>&1 || return 0
  wlr-randr 2>/dev/null | awk '/^[^[:space:]]/{out=$1} /Enabled:[[:space:]]+yes/{print out; exit}'
}

fix_old_noop_mapping() {
  local rc="$USER_HOME/.config/labwc/rc.xml" out
  [[ -f "$rc" ]] || return 0
  out="$(active_output)"
  [[ -n "$out" ]] || return 0
  cp -a "$rc" "$rc.before-touch-bootstrap" 2>/dev/null || true
  sed -i "s/mapToOutput=\"NOOP-1\"/mapToOutput=\"$out\"/g" "$rc"
}

reset_3m() {
  sudo -n rm -f "$RULE_3M"
  rm -rf "$USER_HOME/.local/state/objednavka-ng-touch-calibrator"
  sudo -n udevadm control --reload-rules 2>/dev/null || true
}

reset_touch() {
  local t="$(find_type)"
  rm -f "$STATE_DIR/touch.calibration-pending" "$STATE_DIR/touch.done" "$STATE_DIR/phase3.ready"
  case "$t" in
    3m) reset_3m ;;
    egalax)
      # EETI driver zustava nainstalovany. Nova eCalib kalibrace stare hodnoty prepise.
      sudo -n pkill -x eCalib 2>/dev/null || true
      ;;
  esac
}

run_3m_calibration() {
  fix_old_noop_mapping
  reset_3m
  rm -f "$SUCCESS_3M"

  set +e
  timeout --signal=TERM --kill-after=5 240 \
    env DISPLAY="$DISPLAY_VALUE" XAUTHORITY="$XAUTHORITY_VALUE" \
    "$USER_HOME/bin/labwc-fullscreen.sh" "ObjednavkaNG - kalibrace 3M touch" ObjngTouchCalibrator \
    "$CALIBRATOR" --auto-close-seconds 1.2
  local rc=$?
  set -e

  # O dalsim kroku rozhoduje atomicky success marker, ne pouze GUI exit code.
  if [[ ! -s "$SUCCESS_3M" ]]; then
    echo "CHYBA: 3M kalibrator nedokoncil ulozeni (kod procesu $rc)." >&2
    return 1
  fi
  [[ -x "$APPLY_3M" ]] || { echo "CHYBA: chybi $APPLY_3M" >&2; return 1; }

  sudo -n "$APPLY_3M"
  echo 3m > "$TYPE_FILE"
  touch "$STATE_DIR/touch.calibration-pending"
  sync
  return 10
}

close_ecalib() {
  sudo -n pkill -TERM -x eCalib 2>/dev/null || true
  sleep 1
  sudo -n pkill -KILL -x eCalib 2>/dev/null || true
}

run_egalax_calibration() {
  if [[ ! -x /usr/bin/eCalib || ! -x /usr/bin/eGTouchD || ! -f /etc/eGTouchL.ini ]]; then
    local install_rc=0
    sudo -n "$USER_HOME/bin/install-egalax-eeti-bootstrap.sh" --accept-license || install_rc=$?
    if [[ "$install_rc" -ne 0 ]]; then
      echo "CHYBA: instalace EETI driveru selhala, kod $install_rc." >&2
      return "$install_rc"
    fi
    echo egalax > "$TYPE_FILE"
    return 20
  fi

  sudo -n systemctl enable --now eGTouchD.service 2>/dev/null || true
  local log="$STATE_DIR/ecalib.log"
  rm -f "$log"
  close_ecalib
  set +e
  printf '1\n' | sudo -n env DISPLAY="$DISPLAY_VALUE" XAUTHORITY="$XAUTHORITY_VALUE" \
    /usr/bin/script -qefc /usr/bin/eCalib "$log" &
  local pid=$!
  set -e

  local ok=0
  for _ in $(seq 1 900); do
    if grep -Eqi 'Calibration[[:space:]]+is[[:space:]]+ok|Calibration.*ok' "$log" 2>/dev/null; then
      ok=1
      break
    fi
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  close_ecalib
  set +e
  wait "$pid" 2>/dev/null
  set -e
  [[ "$ok" -eq 1 ]] || { echo "CHYBA: eCalib nepotvrdil uspesnou kalibraci." >&2; return 1; }
  echo egalax > "$TYPE_FILE"
  touch "$STATE_DIR/touch.calibration-pending"
  sync
  return 10
}

calibrate() {
  local t="$(find_type)" rc=0
  case "$t" in
    3m) run_3m_calibration || rc=$? ;;
    egalax) run_egalax_calibration || rc=$? ;;
    multiple) echo "CHYBA: současně připojen 3M i eGalax." >&2; return 1 ;;
    *) echo "CHYBA: podporovany touch nebyl nalezen." >&2; return 1 ;;
  esac
  return "$rc"
}

verify() {
  local t="$(cat "$TYPE_FILE" 2>/dev/null || find_type)"
  case "$t" in
    3m)
      sudo -n udevadm control --reload-rules 2>/dev/null || true
      sudo -n udevadm trigger --subsystem-match=input --action=change 2>/dev/null || true
      local attempt
      for attempt in $(seq 1 45); do
        verify_3m_loaded && return 0
        sleep 1
      done
      echo "CHYBA: udev matice se po rebootu nenacetla do 45 s." >&2
      return 1
      ;;
    egalax)
      [[ -x /usr/bin/eCalib && -x /usr/bin/eGTouchD && -f /etc/eGTouchL.ini ]] || return 1
      systemctl is-active --quiet eGTouchD.service || pgrep -x eGTouchD >/dev/null 2>&1 || return 1
      grep -qi 'eGalaxTouch Virtual Device' /proc/bus/input/devices
      ;;
    *) return 1 ;;
  esac
}

case "${1:-}" in
  --detect) find_type ;;
  --calibrate)
    rc=0
    calibrate || rc=$?
    exit "$rc"
    ;;
  --verify) verify ;;
  --reset) reset_touch ;;
  *) echo "Pouziti: $0 {--detect|--calibrate|--verify|--reset}" >&2; exit 2 ;;
esac
