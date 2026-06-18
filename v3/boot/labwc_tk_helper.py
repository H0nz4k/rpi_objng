"""Tkinter + labwc fullscreen helpers for XWayland on Raspberry Pi OS."""
from __future__ import annotations

import shutil
import subprocess
import tkinter as tk


def set_wm_class(root: tk.Misc, class_name: str) -> None:
    try:
        root.tk.call("wm", "class", root._w, class_name, class_name)
    except tk.TclError:
        pass


def _wlrctl(*args: str) -> bool:
    if not shutil.which("wlrctl"):
        return False
    try:
        subprocess.run(["wlrctl", *args], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except OSError:
        return False


def wlrctl_find(spec: str) -> bool:
    if not shutil.which("wlrctl"):
        return False
    try:
        return subprocess.run(
            ["wlrctl", "toplevel", "find", spec],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode == 0
    except OSError:
        return False


def wlrctl_fullscreen_focus(spec: str) -> None:
    _wlrctl("toplevel", "fullscreen", spec)
    _wlrctl("toplevel", "focus", spec)


def labwc_specs(title: str, wm_class: str) -> list[str]:
    specs: list[str] = []
    if wm_class:
        specs.extend((f"app_id:{wm_class}", f"identifier:{wm_class}"))
    if title:
        specs.extend((f"title:{title}", f"title:{title}*"))
    specs.append("title:ObjednavkaNG*")
    return specs


def apply_labwc_fullscreen(title: str, wm_class: str) -> bool:
    for spec in labwc_specs(title, wm_class):
        if wlrctl_find(spec):
            wlrctl_fullscreen_focus(spec)
            return True
    return False


def minimize_boot_terminal() -> None:
    for spec in (
        "app_id:objng-master-boot",
        "identifier:objng-master-boot",
        "title:ObjednavkaNG MASTER BOOT*",
    ):
        if wlrctl_find(spec):
            _wlrctl("toplevel", "minimize", spec)
            return


def schedule_labwc_fullscreen(
    root: tk.Misc,
    *,
    title: str,
    wm_class: str,
    attempts: int = 0,
    max_attempts: int = 60,
) -> None:
    if attempts == 0:
        minimize_boot_terminal()
    if apply_labwc_fullscreen(title, wm_class):
        if attempts < 8:
            root.after(400, lambda: schedule_labwc_fullscreen(
                root, title=title, wm_class=wm_class, attempts=attempts + 1, max_attempts=max_attempts
            ))
        return
    if attempts >= max_attempts:
        return
    root.after(200, lambda: schedule_labwc_fullscreen(
        root, title=title, wm_class=wm_class, attempts=attempts + 1, max_attempts=max_attempts
    ))


def setup_tk_fullscreen(
    root: tk.Tk,
    *,
    title: str,
    wm_class: str,
    bg: str = "#10151d",
    cursor: str = "crosshair",
) -> None:
    root.withdraw()
    set_wm_class(root, wm_class)
    root.title(title)
    root.configure(bg=bg, cursor=cursor)
    root.attributes("-topmost", True)

    sw = max(1, root.winfo_screenwidth())
    sh = max(1, root.winfo_screenheight())
    root.geometry(f"{sw}x{sh}+0+0")
    root.attributes("-fullscreen", True)
    try:
        root.state("zoomed")
    except tk.TclError:
        pass
    root.deiconify()
    schedule_labwc_fullscreen(root, title=title, wm_class=wm_class)
