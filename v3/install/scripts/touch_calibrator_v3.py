#!/usr/bin/env python3
"""
ObjednávkaNG Touch Calibrator v3 for Raspberry Pi OS / Wayland / libinput

- Reads RAW touch coordinates directly from /dev/input/eventX via python-evdev.
- Draws calibration targets in fullscreen using tkinter.
- Fits a complete affine transform:
      screen_x = a * raw_x + b * raw_y + c
      screen_y = d * raw_x + e * raw_y + f
- Generates an udev rule with LIBINPUT_CALIBRATION_MATRIX="a b c d e f".

Designed for touchscreen devices exposed through Linux evdev/libinput.
Supported profile in this calibrator: 3M USB 0596:0001.\nFor eGalax 0eef:0001 use the official EETI eCalib utility via the command: kalibrace.
"""

from __future__ import annotations

import argparse
import math
import os
import queue
import shlex
import statistics
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

try:
    from evdev import InputDevice, ecodes, list_devices
except ImportError:
    print("Chybí modul python3-evdev. Spusť instalační skript.", file=sys.stderr)
    raise SystemExit(2)

try:
    import tkinter as tk
except ImportError:
    print("Chybí python3-tk. Spusť instalační skript.", file=sys.stderr)
    raise SystemExit(2)


VENDOR_ID = 0x0596
PRODUCT_ID = 0x0001
DEVICE_NAME_HINT = "touchscreen"
RULE_FILENAME = "99-objednavka-ng-touchscreen-calibration.rules"
STATE_DIR = Path.home() / ".local" / "state" / "objednavka-ng-touch-calibrator"


@dataclass
class AxisInfo:
    code: int
    minimum: int
    maximum: int


@dataclass
class Tap:
    raw_x: int
    raw_y: int
    samples: int


def fmt(value: float) -> str:
    """Format matrix numbers compactly while avoiding negative zero."""
    if abs(value) < 0.0000005:
        value = 0.0
    return f"{value:.6f}".rstrip("0").rstrip(".") or "0"


def find_touch_device(explicit_path: Optional[str] = None) -> InputDevice:
    if explicit_path:
        return InputDevice(explicit_path)

    usable: list[InputDevice] = []
    details: list[str] = []
    for path in list_devices():
        try:
            dev = InputDevice(path)
            choose_axes(dev)
        except (OSError, RuntimeError):
            continue

        name = dev.name.lower()
        keys = touch_keys(dev)
        looks_like_touch = bool(keys) or any(token in name for token in ("touch", "egalax", "eeti"))
        if looks_like_touch:
            usable.append(dev)
            details.append(f"{path}: {dev.name} ({dev.info.vendor:04x}:{dev.info.product:04x})")

    if len(usable) == 1:
        return usable[0]
    if len(usable) > 1:
        raise RuntimeError(
            "Nalezeno více dotykových zařízení. Spusť kalibraci s --device /dev/input/eventX.\n"
            + "\n".join(details)
        )
    raise RuntimeError(
        "Nebyl nalezen žádný použitelný touchscreen přes evdev/libinput.\n"
        "Pokud používáš proprietární EETI driver, bude možná nutná jeho vlastní kalibrace."
    )


def choose_axes(dev: InputDevice) -> tuple[AxisInfo, AxisInfo]:
    # absinfo=False je zásadní: jinak python-evdev vrací pro EV_ABS
    # dvojice (code, AbsInfo), a samotné kódy ABS_X/ABS_Y nelze najít.
    caps = dev.capabilities(absinfo=False)
    abs_codes = set(caps.get(ecodes.EV_ABS, []))

    candidates = [
        (ecodes.ABS_X, ecodes.ABS_Y),
        (ecodes.ABS_MT_POSITION_X, ecodes.ABS_MT_POSITION_Y),
    ]
    for x_code, y_code in candidates:
        if x_code in abs_codes and y_code in abs_codes:
            x_info = dev.absinfo(x_code)
            y_info = dev.absinfo(y_code)
            if x_info is None or y_info is None:
                continue
            if x_info.max == x_info.min or y_info.max == y_info.min:
                continue
            return (
                AxisInfo(x_code, x_info.min, x_info.max),
                AxisInfo(y_code, y_info.min, y_info.max),
            )
    raise RuntimeError("Zařízení neposkytuje použitelnou dvojici absolutních os X/Y.")


def touch_keys(dev: InputDevice) -> set[int]:
    caps = dev.capabilities()
    keys = set(caps.get(ecodes.EV_KEY, []))
    supported = {
        code for code in (
            getattr(ecodes, "BTN_TOUCH", -1),
            getattr(ecodes, "BTN_TOOL_FINGER", -1),
            getattr(ecodes, "BTN_LEFT", -1),
        )
        if code in keys
    }
    return supported


class RawTouchReader(threading.Thread):
    def __init__(
        self,
        dev: InputDevice,
        x_axis: AxisInfo,
        y_axis: AxisInfo,
        out_queue: "queue.Queue[tuple[str, object]]",
    ) -> None:
        super().__init__(daemon=True)
        self.dev = dev
        self.x_axis = x_axis
        self.y_axis = y_axis
        self.out_queue = out_queue
        self.stop_requested = threading.Event()
        self.key_codes = touch_keys(dev)
        self.current_x: Optional[int] = None
        self.current_y: Optional[int] = None
        self.touching = False
        self.samples: list[tuple[int, int]] = []
        self.grabbed = False

    def stop(self) -> None:
        self.stop_requested.set()
        try:
            if self.grabbed:
                self.dev.ungrab()
        except OSError:
            pass

    def _begin(self) -> None:
        self.touching = True
        self.samples = []

    def _sample(self) -> None:
        if self.touching and self.current_x is not None and self.current_y is not None:
            self.samples.append((self.current_x, self.current_y))

    def _finish(self) -> None:
        self._sample()
        self.touching = False
        if not self.samples:
            return
        xs = [p[0] for p in self.samples]
        ys = [p[1] for p in self.samples]
        tap = Tap(round(statistics.median(xs)), round(statistics.median(ys)), len(self.samples))
        self.out_queue.put(("tap", tap))
        self.samples = []

    def run(self) -> None:
        if not self.key_codes:
            self.out_queue.put((
                "error",
                "Touch zařízení neposílá BTN_TOUCH/BTN_TOOL_FINGER/BTN_LEFT; "
                "tento typ protokolu je potřeba doplnit do skriptu.",
            ))
            return

        try:
            self.dev.grab()
            self.grabbed = True
        except OSError as exc:
            self.out_queue.put((
                "warning",
                f"Nepodařilo se uzamknout touchscreen ({exc}). "
                "Kalibrace poběží, ale dotyky mohou současně klikat do desktopu.",
            ))

        try:
            for event in self.dev.read_loop():
                if self.stop_requested.is_set():
                    return

                if event.type == ecodes.EV_ABS:
                    if event.code == self.x_axis.code:
                        self.current_x = event.value
                    elif event.code == self.y_axis.code:
                        self.current_y = event.value

                elif event.type == ecodes.EV_KEY and event.code in self.key_codes:
                    if event.value == 1 and not self.touching:
                        self._begin()
                    elif event.value == 0 and self.touching:
                        self._finish()

                elif event.type == ecodes.EV_SYN and event.code == ecodes.SYN_REPORT:
                    self._sample()
        except OSError as exc:
            if not self.stop_requested.is_set():
                self.out_queue.put(("error", f"Čtení touchscreen selhalo: {exc}"))
        finally:
            try:
                if self.grabbed:
                    self.dev.ungrab()
            except OSError:
                pass


def solve_3x3(matrix: list[list[float]], vector: list[float]) -> list[float]:
    augmented = [row[:] + [value] for row, value in zip(matrix, vector)]
    n = 3
    for col in range(n):
        pivot = max(range(col, n), key=lambda row: abs(augmented[row][col]))
        if abs(augmented[pivot][col]) < 1e-12:
            raise RuntimeError("Kalibrační body netvoří řešitelnou matici.")
        augmented[col], augmented[pivot] = augmented[pivot], augmented[col]
        divisor = augmented[col][col]
        augmented[col] = [v / divisor for v in augmented[col]]
        for row in range(n):
            if row == col:
                continue
            factor = augmented[row][col]
            augmented[row] = [
                augmented[row][j] - factor * augmented[col][j]
                for j in range(n + 1)
            ]
    return [augmented[i][n] for i in range(n)]


def least_squares_affine(
    raw_points: list[tuple[float, float]],
    target_points: list[tuple[float, float]],
) -> list[float]:
    design = [[x, y, 1.0] for x, y in raw_points]

    ata = [[sum(row[i] * row[j] for row in design) for j in range(3)] for i in range(3)]
    at_x = [sum(row[i] * target[0] for row, target in zip(design, target_points)) for i in range(3)]
    at_y = [sum(row[i] * target[1] for row, target in zip(design, target_points)) for i in range(3)]

    x_coeff = solve_3x3(ata, at_x)
    y_coeff = solve_3x3(ata, at_y)
    return x_coeff + y_coeff


class CalibratorApp:
    def __init__(self, root: tk.Tk, dev: InputDevice, x_axis: AxisInfo, y_axis: AxisInfo) -> None:
        self.root = root
        self.dev = dev
        self.x_axis = x_axis
        self.y_axis = y_axis
        self.events: "queue.Queue[tuple[str, object]]" = queue.Queue()
        self.reader = RawTouchReader(dev, x_axis, y_axis, self.events)
        self.width = root.winfo_screenwidth()
        self.height = root.winfo_screenheight()
        self.canvas = tk.Canvas(root, bg="#10151d", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)

        margin = max(55, round(min(self.width, self.height) * 0.08))
        cx, cy = self.width // 2, self.height // 2
        self.targets_px: list[tuple[int, int]] = [
            (margin, margin),
            (cx, margin),
            (self.width - margin, margin),
            (self.width - margin, cy),
            (self.width - margin, self.height - margin),
            (cx, self.height - margin),
            (margin, self.height - margin),
            (margin, cy),
            (cx, cy),
        ]
        self.raw_taps: list[Tap] = []
        self.last_accept_time = 0.0
        self.finished = False

        root.title("ObjednávkaNG – Kalibrace 3M touchscreen")
        # labwc/Wayland: force a true borderless fullscreen surface, not only a window-manager hint.
        root.attributes("-fullscreen", True)
        root.overrideredirect(True)
        root.geometry(f"{root.winfo_screenwidth()}x{root.winfo_screenheight()}+0+0")
        root.attributes("-topmost", True)
        root.lift()
        root.focus_force()
        root.configure(cursor="none")
        root.bind("<Escape>", lambda _e: self.abort())
        root.bind("<BackSpace>", lambda _e: self.undo())
        root.bind("<Control-r>", lambda _e: self.restart())

        self.draw_target()
        self.reader.start()
        self.root.after(40, self.poll_events)

    def title_text(self, text: str, y: int, size: int = 18, fill: str = "#e8eef8") -> None:
        self.canvas.create_text(
            self.width // 2, y, text=text, fill=fill,
            font=("Sans", size, "bold"), justify="center"
        )

    def draw_target(self) -> None:
        self.canvas.delete("all")
        idx = len(self.raw_taps)
        if idx >= len(self.targets_px):
            return

        x, y = self.targets_px[idx]
        self.title_text("Kalibrace dotykové obrazovky 3M", 36, 22)
        self.canvas.create_text(
            self.width // 2, 72,
            text=f"Dotkni se středu křížku a uvolni prst  •  Bod {idx + 1} / {len(self.targets_px)}",
            fill="#bfcadb", font=("Sans", 14)
        )
        self.canvas.create_text(
            self.width // 2, self.height - 35,
            text="Esc = ukončit   |   Backspace = opakovat předchozí bod",
            fill="#8a98aa", font=("Sans", 12)
        )

        radius = 28
        self.canvas.create_oval(x - radius, y - radius, x + radius, y + radius, outline="#29d17d", width=3)
        self.canvas.create_line(x - 42, y, x + 42, y, fill="#29d17d", width=2)
        self.canvas.create_line(x, y - 42, x, y + 42, fill="#29d17d", width=2)
        self.canvas.create_oval(x - 4, y - 4, x + 4, y + 4, fill="#f6f8fc", outline="")

        for i, (px, py) in enumerate(self.targets_px[:idx]):
            self.canvas.create_oval(px - 7, py - 7, px + 7, py + 7, fill="#6f7f95", outline="")

    def normalize_tap(self, tap: Tap) -> tuple[float, float]:
        x = (tap.raw_x - self.x_axis.minimum) / (self.x_axis.maximum - self.x_axis.minimum)
        y = (tap.raw_y - self.y_axis.minimum) / (self.y_axis.maximum - self.y_axis.minimum)
        return x, y

    def normalized_targets(self) -> list[tuple[float, float]]:
        return [
            (x / (self.width - 1), y / (self.height - 1))
            for x, y in self.targets_px
        ]

    def accept_tap(self, tap: Tap) -> None:
        if self.finished:
            return
        now = time.monotonic()
        if now - self.last_accept_time < 0.18:
            return
        self.last_accept_time = now
        self.raw_taps.append(tap)
        if len(self.raw_taps) == len(self.targets_px):
            self.finish()
        else:
            self.draw_target()

    def undo(self) -> None:
        if self.finished:
            return
        if self.raw_taps:
            self.raw_taps.pop()
        self.draw_target()

    def restart(self) -> None:
        self.raw_taps = []
        self.finished = False
        self.draw_target()

    def abort(self) -> None:
        self.reader.stop()
        self.root.destroy()

    def show_error(self, message: str) -> None:
        self.reader.stop()
        self.canvas.delete("all")
        self.title_text("Kalibraci nelze dokončit", self.height // 2 - 40, 23, "#ff7878")
        self.canvas.create_text(
            self.width // 2, self.height // 2 + 15, text=message,
            fill="#e8eef8", font=("Sans", 14), width=self.width - 100, justify="center"
        )
        self.canvas.create_text(
            self.width // 2, self.height // 2 + 75, text="Stiskni Esc pro ukončení.",
            fill="#a4b0bf", font=("Sans", 13)
        )

    def finish(self) -> None:
        self.finished = True
        self.reader.stop()
        raw_norm = [self.normalize_tap(tap) for tap in self.raw_taps]
        targets = self.normalized_targets()
        try:
            matrix = least_squares_affine(raw_norm, targets)
        except RuntimeError as exc:
            self.show_error(str(exc))
            return

        predictions = [
            (
                matrix[0] * raw[0] + matrix[1] * raw[1] + matrix[2],
                matrix[3] * raw[0] + matrix[4] * raw[1] + matrix[5],
            )
            for raw in raw_norm
        ]
        pixel_errors = [
            math.hypot((pred[0] - target[0]) * (self.width - 1),
                       (pred[1] - target[1]) * (self.height - 1))
            for pred, target in zip(predictions, targets)
        ]
        rms = math.sqrt(sum(e * e for e in pixel_errors) / len(pixel_errors))
        max_error = max(pixel_errors)
        matrix_text = " ".join(fmt(v) for v in matrix)
        vendor = f"{self.dev.info.vendor:04x}"
        product = f"{self.dev.info.product:04x}"
        device_name = self.dev.name

        if "eGalaxTouch Virtual Device for Single" in device_name:
            # EETI vytváří virtuální zařízení hlášené jako pointer; USB ATTRS zde nemusí existovat.
            match = 'ATTRS{name}=="eGalaxTouch Virtual Device for Single*", '
        elif vendor == "0596" and product == "0001":
            match = 'ATTRS{idVendor}=="0596", ATTRS{idProduct}=="0001", '
        else:
            # Pro neznámý panel je bezpečnější pravidlo před aplikací ručně zkontrolovat.
            safe_name = device_name.replace('\\', '\\\\').replace('"', '\\\"')
            match = f'ATTRS{{name}}=="{safe_name}", '

        rule_text = (
            'ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", '
            + match
            + f'ENV{{LIBINPUT_CALIBRATION_MATRIX}}="{matrix_text}"\n'
        )
        apply_script = self.save_results(matrix_text, rule_text, rms, max_error)
        apply_ok, apply_message = self.apply_results(apply_script)

        self.canvas.delete("all")
        self.root.configure(cursor="")
        color = "#29d17d" if apply_ok and rms <= 18 else "#ffb84c"
        self.title_text("Kalibrace dokončena", 76, 28, color)
        self.canvas.create_text(
            self.width // 2, 140,
            text=f"Průměrná chyba: {rms:.1f} px   •   Největší chyba: {max_error:.1f} px",
            fill="#e8eef8", font=("Sans", 16)
        )
        self.canvas.create_text(
            self.width // 2, 212, text="Výsledná LIBINPUT_CALIBRATION_MATRIX:",
            fill="#a4b0bf", font=("Sans", 14)
        )
        self.canvas.create_text(
            self.width // 2, 255, text=matrix_text,
            fill="#f6f8fc", font=("Monospace", 17, "bold")
        )
        self.canvas.create_text(
            self.width // 2, 342,
            text="Výsledek je uložený a kalibrátor se automaticky zavře.",
            fill="#a4b0bf", font=("Sans", 14)
        )
        self.canvas.create_text(
            self.width // 2, 385, text=apply_message,
            fill="#29d17d" if apply_ok else "#ffb84c", font=("Sans", 15, "bold"),
            width=self.width - 120, justify="center"
        )
        self.canvas.create_text(
            self.width // 2, 460,
            text="Pro spolehlivé načtení ve Wayland relaci je nyní nutný restart zařízení.",
            fill="#d5deeb", font=("Sans", 14), justify="center"
        )
        self.canvas.create_text(
            self.width // 2, self.height - 45,
            text="Zavírám za 5 sekund...",
            fill="#8a98aa", font=("Sans", 12)
        )
        self.root.after(5000, self.root.destroy)

    def apply_results(self, apply_script: Path) -> tuple[bool, str]:
        try:
            completed = subprocess.run(
                ["sudo", "-n", str(apply_script)],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
        except OSError as exc:
            return False, f"Automaticka aplikace selhala: {exc}"

        if completed.returncode == 0:
            return True, "Kalibracni pravidlo bylo automaticky zapsano."
        output = (completed.stdout or "").strip().splitlines()
        tail = output[-1] if output else f"exit {completed.returncode}"
        return False, f"Automaticky zapis selhal ({tail}). Spust rucne: sudo {apply_script}"

    def save_results(self, matrix_text: str, rule_text: str, rms: float, max_error: float) -> Path:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        rule_file = STATE_DIR / RULE_FILENAME
        result_file = STATE_DIR / "last-result.txt"
        apply_file = STATE_DIR / "apply-calibration.sh"

        rule_file.write_text(rule_text, encoding="utf-8")
        result_file.write_text(
            f"Device: {self.dev.name}\n"
            f"Kernel: {self.dev.path}\n"
            f"Screen: {self.width}x{self.height}\n"
            f"Raw X: {self.x_axis.minimum}..{self.x_axis.maximum}\n"
            f"Raw Y: {self.y_axis.minimum}..{self.y_axis.maximum}\n"
            f"RMS error px: {rms:.2f}\n"
            f"Max error px: {max_error:.2f}\n"
            f"LIBINPUT_CALIBRATION_MATRIX: {matrix_text}\n\n"
            f"{rule_text}",
            encoding="utf-8",
        )

        rule_src = shlex.quote(str(rule_file))
        system_rule = f"/etc/udev/rules.d/{RULE_FILENAME}"
        apply_file.write_text(
            "#!/usr/bin/env bash\n"
            "set -Eeuo pipefail\n"
            "[[ $EUID -eq 0 ]] || { echo 'Spusť přes sudo.' >&2; exit 1; }\n"
            f"RULE={shlex.quote(system_rule)}\n"
            'if [[ -f "$RULE" ]]; then\n'
            '  cp -a "$RULE" "${RULE}.backup.$(date +%Y%m%d_%H%M%S)"\n'
            "fi\n"
            f"install -m 0644 {rule_src} \"$RULE\"\n"
            "udevadm control --reload-rules\n"
            "udevadm trigger --subsystem-match=input --action=change || true\n"
            "echo 'Nastavená matice:'\n"
            f"echo '  {matrix_text}'\n"
            "echo 'Pro spolehlivé načtení ve Wayland relaci spusť: sudo reboot'\n",
            encoding="utf-8",
        )
        apply_file.chmod(0o755)
        return apply_file

    def poll_events(self) -> None:
        try:
            while True:
                kind, payload = self.events.get_nowait()
                if kind == "tap":
                    self.accept_tap(payload)  # type: ignore[arg-type]
                elif kind == "warning":
                    print(f"VAROVÁNÍ: {payload}", file=sys.stderr)
                elif kind == "error":
                    self.show_error(str(payload))
        except queue.Empty:
            pass
        if self.root.winfo_exists():
            self.root.after(40, self.poll_events)


def print_devices() -> None:
    for path in list_devices():
        try:
            dev = InputDevice(path)
        except OSError:
            continue
        print(f"{path:20} {dev.info.vendor:04x}:{dev.info.product:04x}  {dev.name}")


def check_device(explicit_path: Optional[str] = None) -> int:
    try:
        dev = find_touch_device(explicit_path)
        x_axis, y_axis = choose_axes(dev)
        keys = touch_keys(dev)
        key_names = [ecodes.KEY.get(code, str(code)) for code in sorted(keys)]
        print("KONTROLA TOUCHSCREEN: OK")
        print(f"Zařízení: {dev.name}")
        print(f"Kernel:   {dev.path}")
        print(f"USB ID:   {dev.info.vendor:04x}:{dev.info.product:04x}")
        print(f"RAW X:    code={x_axis.code} rozsah={x_axis.minimum}..{x_axis.maximum}")
        print(f"RAW Y:    code={y_axis.code} rozsah={y_axis.minimum}..{y_axis.maximum}")
        print(f"Touch:    {', '.join(map(str, key_names)) if key_names else 'NENALEZEN BTN_TOUCH/BTN_LEFT'}")
        if not keys:
            print("\nVAROVÁNÍ: zařízení nemá rozpoznaný touch-button event; GUI zatím nebude umět potvrdit klepnutí.")
            return 2
        print("\nZařízení je vhodné pro spuštění grafického kalibrátoru.")
        return 0
    except (RuntimeError, PermissionError, OSError) as exc:
        print(f"KONTROLA TOUCHSCREEN: CHYBA: {exc}", file=sys.stderr)
        return 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Kalibrátor touchscreen pro Wayland/libinput.")
    parser.add_argument("--device", help="Volitelně explicitní cesta, např. /dev/input/event4")
    parser.add_argument("--list", action="store_true", help="Vypíše vstupní zařízení a skončí")
    parser.add_argument("--check", action="store_true", help="Ověří touchscreen a osy bez otevření grafického okna")
    args = parser.parse_args()

    if args.list:
        print_devices()
        return 0
    if args.check:
        return check_device(args.device)

    try:
        dev = find_touch_device(args.device)
        x_axis, y_axis = choose_axes(dev)
    except (RuntimeError, PermissionError, OSError) as exc:
        print(f"CHYBA: {exc}", file=sys.stderr)
        print("Zkontroluj přístupová práva a instalaci přes instalační skript.", file=sys.stderr)
        return 1

    print(f"Zařízení: {dev.name} ({dev.path})")
    print(f"USB ID:   {dev.info.vendor:04x}:{dev.info.product:04x}")
    print(f"RAW X:    {x_axis.minimum} .. {x_axis.maximum}")
    print(f"RAW Y:    {y_axis.minimum} .. {y_axis.maximum}")

    root = tk.Tk()
    CalibratorApp(root, dev, x_axis, y_axis)
    try:
        root.mainloop()
    finally:
        try:
            dev.close()
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
