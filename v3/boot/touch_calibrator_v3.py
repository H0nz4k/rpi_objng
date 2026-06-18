#!/usr/bin/env python3
"""ObjednavkaNG 3M calibrator v4.1.

Calibrates 3M 0596:0001 using a full-range affine mapping limited to
swap/invert + independent scale/offset. This corrects panels whose real raw
range occupies only part of the kernel-advertised ABS range, while avoiding
shear and unstable arbitrary affine transforms.
"""
from __future__ import annotations

import argparse
import math
import os
import queue
import shlex
import statistics
import sys
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Optional

from evdev import InputDevice, ecodes, list_devices
import tkinter as tk

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from labwc_tk_helper import restore_boot_terminal, schedule_labwc_fullscreen, setup_tk_fullscreen  # noqa: E402

WM_CLASS = "ObjngTouchCalibrator"
WINDOW_TITLE = "ObjednavkaNG - kalibrace 3M touch"

VENDOR_ID = 0x0596
PRODUCT_ID = 0x0001
RULE_FILENAME = "99-objednavka-ng-touchscreen-calibration.rules"
STATE_DIR = Path.home() / ".local" / "state" / "objednavka-ng-touch-calibrator"


@dataclass(frozen=True)
class AxisInfo:
    code: int
    minimum: int
    maximum: int


@dataclass(frozen=True)
class Tap:
    raw_x: int
    raw_y: int
    samples: int


@dataclass(frozen=True)
class Orientation:
    name: str
    matrix: tuple[float, float, float, float, float, float]
    transform: Callable[[float, float], tuple[float, float]]


ORIENTATIONS = (
    Orientation("normal", (1, 0, 0, 0, 1, 0), lambda x, y: (x, y)),
    Orientation("invert-x", (-1, 0, 1, 0, 1, 0), lambda x, y: (1 - x, y)),
    Orientation("invert-y", (1, 0, 0, 0, -1, 1), lambda x, y: (x, 1 - y)),
    Orientation("invert-both", (-1, 0, 1, 0, -1, 1), lambda x, y: (1 - x, 1 - y)),
    Orientation("swap", (0, 1, 0, 1, 0, 0), lambda x, y: (y, x)),
    Orientation("swap-invert-x", (0, -1, 1, 1, 0, 0), lambda x, y: (1 - y, x)),
    Orientation("swap-invert-y", (0, 1, 0, -1, 0, 1), lambda x, y: (y, 1 - x)),
    Orientation("swap-invert-both", (0, -1, 1, -1, 0, 1), lambda x, y: (1 - y, 1 - x)),
)


def fmt(value: float) -> str:
    if abs(value) < 0.0000005:
        value = 0.0
    return f"{value:.7f}".rstrip("0").rstrip(".") or "0"


def choose_axes(dev: InputDevice) -> tuple[AxisInfo, AxisInfo]:
    codes = set(dev.capabilities(absinfo=False).get(ecodes.EV_ABS, []))
    for x_code, y_code in (
        (ecodes.ABS_X, ecodes.ABS_Y),
        (ecodes.ABS_MT_POSITION_X, ecodes.ABS_MT_POSITION_Y),
    ):
        if x_code in codes and y_code in codes:
            xi = dev.absinfo(x_code)
            yi = dev.absinfo(y_code)
            if xi and yi and xi.max != xi.min and yi.max != yi.min:
                return AxisInfo(x_code, xi.min, xi.max), AxisInfo(y_code, yi.min, yi.max)
    raise RuntimeError("Touch nema pouzitelne absolutni osy X/Y.")


def touch_keys(dev: InputDevice) -> set[int]:
    keys = set(dev.capabilities(absinfo=False).get(ecodes.EV_KEY, []))
    return {
        code for code in (
            getattr(ecodes, "BTN_TOUCH", -1),
            getattr(ecodes, "BTN_TOOL_FINGER", -1),
            getattr(ecodes, "BTN_LEFT", -1),
        ) if code in keys
    }


def find_touch_device(explicit: Optional[str] = None) -> InputDevice:
    if explicit:
        dev = InputDevice(explicit)
        choose_axes(dev)
        return dev

    candidates: list[tuple[int, str]] = []
    for path in list_devices():
        try:
            dev = InputDevice(path)
            if dev.info.vendor != VENDOR_ID or dev.info.product != PRODUCT_ID:
                continue
            choose_axes(dev)
            name = (dev.name or "").lower()
            score = 0
            if touch_keys(dev):
                score += 100
            if "touchscreen" in name:
                score += 30
            if "ex ii" in name:
                score += 20
            candidates.append((score, path))
        except (OSError, RuntimeError):
            continue
    if not candidates:
        raise RuntimeError("Nebyl nalezen 3M touchscreen 0596:0001.")
    candidates.sort(reverse=True)
    return InputDevice(candidates[0][1])


class RawTouchReader(threading.Thread):
    def __init__(self, dev: InputDevice, x_axis: AxisInfo, y_axis: AxisInfo,
                 events: "queue.Queue[tuple[str, object]]") -> None:
        super().__init__(daemon=True)
        self.dev = dev
        self.x_axis = x_axis
        self.y_axis = y_axis
        self.events = events
        self.stop_event = threading.Event()
        self.keys = touch_keys(dev)
        self.current_x: Optional[int] = None
        self.current_y: Optional[int] = None
        self.touching = False
        self.samples: list[tuple[int, int]] = []
        self.grabbed = False

    def stop(self) -> None:
        self.stop_event.set()
        try:
            if self.grabbed:
                self.dev.ungrab()
                self.grabbed = False
        except OSError:
            pass

    def finish_tap(self) -> None:
        if self.current_x is not None and self.current_y is not None:
            self.samples.append((self.current_x, self.current_y))
        if self.samples:
            xs = [p[0] for p in self.samples]
            ys = [p[1] for p in self.samples]
            self.events.put(("tap", Tap(round(statistics.median(xs)), round(statistics.median(ys)), len(self.samples))))
        self.samples = []
        self.touching = False

    def run(self) -> None:
        if not self.keys:
            self.events.put(("error", "Touch neposila BTN_TOUCH/BTN_LEFT."))
            return
        try:
            self.dev.grab()
            self.grabbed = True
        except OSError as exc:
            self.events.put(("warning", f"Nelze uzamknout touch: {exc}"))
        try:
            for event in self.dev.read_loop():
                if self.stop_event.is_set():
                    break
                if event.type == ecodes.EV_ABS:
                    if event.code == self.x_axis.code:
                        self.current_x = event.value
                    elif event.code == self.y_axis.code:
                        self.current_y = event.value
                elif event.type == ecodes.EV_KEY and event.code in self.keys:
                    if event.value == 1 and not self.touching:
                        self.touching = True
                        self.samples = []
                    elif event.value == 0 and self.touching:
                        self.finish_tap()
                elif event.type == ecodes.EV_SYN and event.code == ecodes.SYN_REPORT:
                    if self.touching and self.current_x is not None and self.current_y is not None:
                        self.samples.append((self.current_x, self.current_y))
        except OSError as exc:
            if not self.stop_event.is_set():
                self.events.put(("error", f"Cteni touch selhalo: {exc}"))
        finally:
            try:
                if self.grabbed:
                    self.dev.ungrab()
            except OSError:
                pass


def fit_line(values: list[float], targets: list[float]) -> tuple[float, float]:
    mean_v = sum(values) / len(values)
    mean_t = sum(targets) / len(targets)
    variance = sum((v - mean_v) ** 2 for v in values)
    if variance < 1e-9:
        raise RuntimeError("Kalibracni body nemaji dostatecny rozsah.")
    scale = sum((v - mean_v) * (t - mean_t) for v, t in zip(values, targets)) / variance
    offset = mean_t - scale * mean_v
    return scale, offset


def compose(orientation: Orientation, sx: float, ox: float, sy: float, oy: float) -> tuple[float, ...]:
    a, b, c, d, e, f = orientation.matrix
    return (
        sx * a,
        sx * b,
        sx * c + ox,
        sy * d,
        sy * e,
        sy * f + oy,
    )


class Calibrator:
    def __init__(self, root: tk.Tk, dev: InputDevice, x_axis: AxisInfo,
                 y_axis: AxisInfo, auto_close: float) -> None:
        self.root = root
        self.dev = dev
        self.x_axis = x_axis
        self.y_axis = y_axis
        self.auto_close = max(0.5, auto_close)
        self.events: "queue.Queue[tuple[str, object]]" = queue.Queue()
        self.reader = RawTouchReader(dev, x_axis, y_axis, self.events)
        self.raw_taps: list[Tap] = []
        self.exit_code = 1
        self.finished = False
        self.last_tap_time = 0.0

        setup_tk_fullscreen(root, title=WINDOW_TITLE, wm_class=WM_CLASS, cursor="none")
        root.bind("<Map>", self._on_map, add="+")

        self.canvas = tk.Canvas(root, bg="#10151d", highlightthickness=0, cursor="none")
        self.canvas.pack(fill="both", expand=True)
        root.update()
        self.width = max(1, self.canvas.winfo_width())
        self.height = max(1, self.canvas.winfo_height())

        margin = max(35, round(min(self.width, self.height) * 0.045))
        self.targets_px = [
            (margin, margin),
            (self.width - margin, margin),
            (self.width - margin, self.height - margin),
            (margin, self.height - margin),
        ]

        root.bind("<Escape>", lambda _e: self.abort())
        root.lift()
        root.focus_force()
        self.draw()
        self.reader.start()
        root.after(35, self.poll)
        root.after(240000, lambda: self.error("Vyprsel cas kalibrace."))

    def _on_map(self, _event: tk.Event) -> None:
        schedule_labwc_fullscreen(self.root, title=WINDOW_TITLE, wm_class=WM_CLASS)

    def normalize(self, tap: Tap) -> tuple[float, float]:
        x = (tap.raw_x - self.x_axis.minimum) / (self.x_axis.maximum - self.x_axis.minimum)
        y = (tap.raw_y - self.y_axis.minimum) / (self.y_axis.maximum - self.y_axis.minimum)
        return x, y

    def target_norm(self) -> list[tuple[float, float]]:
        return [(x / max(1, self.width - 1), y / max(1, self.height - 1)) for x, y in self.targets_px]

    def solve(self) -> tuple[Orientation, tuple[float, ...], float]:
        raw = [self.normalize(t) for t in self.raw_taps]
        targets = self.target_norm()
        candidates: list[tuple[float, Orientation, tuple[float, ...]]] = []
        for orientation in ORIENTATIONS:
            uv = [orientation.transform(x, y) for x, y in raw]
            try:
                sx, ox = fit_line([p[0] for p in uv], [p[0] for p in targets])
                sy, oy = fit_line([p[1] for p in uv], [p[1] for p in targets])
            except RuntimeError:
                continue
            if not (0.35 <= sx <= 4.0 and 0.35 <= sy <= 4.0):
                continue
            matrix = compose(orientation, sx, ox, sy, oy)
            errors = []
            for (rx, ry), (tx, ty) in zip(raw, targets):
                px = matrix[0] * rx + matrix[1] * ry + matrix[2]
                py = matrix[3] * rx + matrix[4] * ry + matrix[5]
                errors.append(math.hypot((px - tx) * self.width, (py - ty) * self.height))
            rms = math.sqrt(sum(e * e for e in errors) / len(errors))
            candidates.append((rms, orientation, matrix))
        if not candidates:
            raise RuntimeError("Nepodarilo se vypocitat kalibracni matici.")
        candidates.sort(key=lambda item: item[0])
        return candidates[0][1], candidates[0][2], candidates[0][0]

    def draw(self) -> None:
        self.canvas.delete("all")
        idx = len(self.raw_taps)
        self.canvas.create_text(self.width // 2, 42, text="KALIBRACE 3M DOTYKOVEHO PANELU",
                                fill="#f2f6fb", font=("Sans", 23, "bold"))
        self.canvas.create_text(self.width // 2, 80,
                                text=f"Dotkni se stredu krize a uvolni prst  -  bod {idx + 1}/4",
                                fill="#c4ceda", font=("Sans", 15))
        self.canvas.create_text(self.width // 2, self.height - 28,
                                text=f"Fullscreen {self.width} x {self.height} px",
                                fill="#8795a8", font=("Sans", 12))
        for i, (x, y) in enumerate(self.targets_px):
            if i < idx:
                self.canvas.create_oval(x - 10, y - 10, x + 10, y + 10, fill="#29d17d", outline="")
            elif i == idx:
                self.canvas.create_oval(x - 30, y - 30, x + 30, y + 30, outline="#ffd34e", width=4)
                self.canvas.create_line(x - 45, y, x + 45, y, fill="#ffd34e", width=3)
                self.canvas.create_line(x, y - 45, x, y + 45, fill="#ffd34e", width=3)
                self.canvas.create_oval(x - 5, y - 5, x + 5, y + 5, fill="#ffffff", outline="")
            else:
                self.canvas.create_oval(x - 8, y - 8, x + 8, y + 8, outline="#637084", width=2)

    def accept(self, tap: Tap) -> None:
        if self.finished:
            return
        now = time.monotonic()
        if now - self.last_tap_time < 0.20:
            return
        self.last_tap_time = now
        self.raw_taps.append(tap)
        if len(self.raw_taps) >= 4:
            self.finish()
        else:
            self.draw()

    def finish(self) -> None:
        self.finished = True
        self.reader.stop()
        try:
            orientation, matrix, rms = self.solve()
            matrix_text = " ".join(fmt(v) for v in matrix)
            self.save(orientation, matrix_text, rms)
        except Exception as exc:  # noqa: BLE001
            self.error(str(exc))
            return
        self.exit_code = 0
        self.canvas.delete("all")
        self.root.configure(cursor="")
        self.canvas.create_text(self.width // 2, self.height // 2 - 45,
                                text="KALIBRACE ULOZENA", fill="#29d17d",
                                font=("Sans", 30, "bold"))
        self.canvas.create_text(self.width // 2, self.height // 2 + 15,
                                text=f"Profil: {orientation.name}\nMatice: {matrix_text}\nRMS: {rms:.1f} px",
                                fill="#dfe7f1", font=("Sans", 15), justify="center")
        self.root.after(int(self.auto_close * 1000), self.close_success)

    def save(self, orientation: Orientation, matrix_text: str, rms: float) -> None:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        rule_file = STATE_DIR / RULE_FILENAME
        result_file = STATE_DIR / "last-result.txt"
        apply_file = STATE_DIR / "apply-calibration.sh"
        success_file = STATE_DIR / "calibration.success"
        success_file.unlink(missing_ok=True)

        rule_text = (
            '# ObjednavkaNG 3M full-range calibration.\n'
            'ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", '
            'ENV{ID_INPUT_TOUCHSCREEN}=="1", '
            'ATTRS{idVendor}=="0596", ATTRS{idProduct}=="0001", '
            f'ENV{{LIBINPUT_CALIBRATION_MATRIX}}="{matrix_text}"\n'
        )
        rule_file.write_text(rule_text, encoding="utf-8")
        result_file.write_text(
            f"Device: {self.dev.name}\nKernel: {self.dev.path}\n"
            f"Screen: {self.width}x{self.height}\n"
            f"Raw X declared: {self.x_axis.minimum}..{self.x_axis.maximum}\n"
            f"Raw Y declared: {self.y_axis.minimum}..{self.y_axis.maximum}\n"
            f"Profile: {orientation.name}\nRMS px: {rms:.2f}\n"
            f"LIBINPUT_CALIBRATION_MATRIX: {matrix_text}\n\n{rule_text}",
            encoding="utf-8",
        )
        target = f"/etc/udev/rules.d/{RULE_FILENAME}"
        apply_file.write_text(
            "#!/usr/bin/env bash\nset -Eeuo pipefail\n"
            "[[ $EUID -eq 0 ]] || { echo 'Spust pres sudo.' >&2; exit 1; }\n"
            f"TARGET={shlex.quote(target)}\n"
            '[[ -f "$TARGET" ]] && cp -a "$TARGET" "${TARGET}.backup.$(date +%Y%m%d_%H%M%S)" || true\n'
            "rm -f /etc/udev/rules.d/99-objng-3m-calibration.rules\n"
            "rm -f /etc/udev/rules.d/99-3m-touch-calibration.rules\n"
            f"install -m 0644 {shlex.quote(str(rule_file))} \"$TARGET\"\n"
            "udevadm control --reload-rules\n"
            "udevadm trigger --subsystem-match=input --action=change || true\n"
            f"echo 'Nastavena matice: {matrix_text}'\n",
            encoding="utf-8",
        )
        apply_file.chmod(0o755)
        success_file.write_text("ok\n", encoding="utf-8")

    def close_success(self) -> None:
        self.reader.stop()
        restore_boot_terminal()
        try:
            self.root.quit()
        finally:
            self.root.destroy()

    def abort(self) -> None:
        self.reader.stop()
        restore_boot_terminal()
        self.exit_code = 1
        self.root.quit()
        self.root.destroy()

    def error(self, message: str) -> None:
        if self.finished and self.exit_code == 0:
            return
        self.finished = True
        self.reader.stop()
        self.exit_code = 1
        self.canvas.delete("all")
        self.canvas.create_text(self.width // 2, self.height // 2,
                                text="KALIBRACE SELHALA\n" + message,
                                fill="#ff6b75", font=("Sans", 20, "bold"), justify="center")
        self.root.after(3000, self.abort)

    def poll(self) -> None:
        try:
            while True:
                kind, payload = self.events.get_nowait()
                if kind == "tap":
                    self.accept(payload)  # type: ignore[arg-type]
                elif kind == "warning":
                    print(f"VAROVANI: {payload}", file=sys.stderr)
                elif kind == "error":
                    self.error(str(payload))
        except queue.Empty:
            pass
        try:
            if self.root.winfo_exists():
                self.root.after(35, self.poll)
        except tk.TclError:
            pass


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--device")
    parser.add_argument("--auto-close-seconds", type=float, default=1.2)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        dev = find_touch_device(args.device)
        x_axis, y_axis = choose_axes(dev)
    except (RuntimeError, OSError, PermissionError) as exc:
        print(f"CHYBA: {exc}", file=sys.stderr)
        return 1
    if args.check:
        print(f"OK: {dev.path} {dev.name}")
        print(f"RAW X: {x_axis.minimum}..{x_axis.maximum}")
        print(f"RAW Y: {y_axis.minimum}..{y_axis.maximum}")
        return 0
    print(f"3M touch: {dev.path} {dev.name}")
    root = tk.Tk()
    app = Calibrator(root, dev, x_axis, y_axis, args.auto_close_seconds)
    try:
        root.mainloop()
    finally:
        try:
            dev.close()
        except OSError:
            pass
    return app.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
