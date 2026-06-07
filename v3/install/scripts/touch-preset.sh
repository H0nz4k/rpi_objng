#!/usr/bin/env bash
# ObjednávkaNG – ověřená výchozí orientace pro 3M USB touchscreen přes libinput.
set -Eeuo pipefail
RULE="/etc/udev/rules.d/99-objednavka-ng-touchscreen-calibration.rules"
MATRIX="0 -1 1 -1 0 1"
MODE="${1:-apply}"
AUTO_REBOOT=1
if [[ "${2:-}" == "--no-reboot" || "${OBJNG_NO_AUTO_REBOOT:-0}" == "1" ]]; then
  AUTO_REBOOT=0
fi
need_root() { [[ "$EUID" -eq 0 ]] || { echo "Spusť přes sudo: sudo touch-preset $MODE" >&2; exit 1; }; }
force_reboot() {
    if [[ "$AUTO_REBOOT" -ne 1 ]]; then
        echo "Reboot odložen volbou --no-reboot."
        return 0
    fi
    echo "Pro spolehlivé načtení změny ve Wayland relaci je nutný reboot."
    echo "Restartuji zařízení za 5 sekund..."
    sleep 5
    reboot
}
case "$MODE" in
  apply|on)
    need_root
    [[ -f "$RULE" ]] && cp -a "$RULE" "${RULE}.backup.$(date +%Y%m%d_%H%M%S)"
    cat > "$RULE" <<EOF
# Ověřená směrová korekce pro 3M 3M USB Touchscreen - EX II / USB 0596:0001
ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="0596", ATTRS{idProduct}=="0001", ENV{LIBINPUT_CALIBRATION_MATRIX}="${MATRIX}"
EOF
    chmod 0644 "$RULE"; udevadm control --reload-rules; udevadm trigger --subsystem-match=input --action=change || true
    echo "3M touch preset nastaven: LIBINPUT_CALIBRATION_MATRIX=\"${MATRIX}\""
    force_reboot
    ;;
  remove|off)
    need_root
    if [[ -f "$RULE" ]]; then cp -a "$RULE" "${RULE}.removed.$(date +%Y%m%d_%H%M%S)"; rm -f "$RULE"; fi
    udevadm control --reload-rules; udevadm trigger --subsystem-match=input --action=change || true
    echo "Vlastní libinput kalibrační pravidlo bylo odstraněno."
    force_reboot
    ;;
  status)
    echo "Pravidlo: $RULE"; [[ -f "$RULE" ]] && sed 's/^/  /' "$RULE" || echo "  neexistuje"; echo
    libinput list-devices 2>/dev/null | awk '/^Device:/ {show=($0 ~ /3M 3M USB Touchscreen - EX II/ || $0 ~ /eGalaxTouch Virtual Device for Single/)} show {print "  "$0} show && /^$/ {show=0; print ""}'
    ;;
  *) echo "Použití: touch-preset {apply|remove|status} [--no-reboot]" >&2; exit 1 ;;
esac
