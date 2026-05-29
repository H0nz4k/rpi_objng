#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
echo "Kontroluji shell skripty..."; find . -type f -name '*.sh' -print0 | while IFS= read -r -d '' f; do bash -n "$f"; done
echo "Kontroluji Python kalibrátor..."; python3 -m py_compile scripts/touch_calibrator_v3.py; rm -rf scripts/__pycache__
for f in README.md CHANGELOG.md VERSION install.sh files/config.example.json files/splash-image.tga; do [[ -f "$f" ]] || { echo "Chybí: $f" >&2; exit 1; }; done
echo "OK: zdrojový projekt je připravený pro Git."
