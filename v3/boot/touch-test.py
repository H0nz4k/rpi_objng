#!/usr/bin/env python3
"""Fullscreen 4-point touch verification for ObjednavkaNG boot v2.1.7."""
from __future__ import annotations

import os
import sys
import tkinter as tk

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from labwc_tk_helper import schedule_labwc_fullscreen, setup_tk_fullscreen  # noqa: E402

WM_CLASS = "ObjngTouchTest"
WINDOW_TITLE = "ObjednavkaNG - test dotyku"


class TouchTest:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        setup_tk_fullscreen(root, title=WINDOW_TITLE, wm_class=WM_CLASS)
        root.bind("<Map>", self._on_map, add="+")

        self.canvas = tk.Canvas(root, bg="#10151d", highlightthickness=0, cursor="crosshair")
        self.canvas.pack(fill="both", expand=True)
        root.update()

        # Use the real mapped fullscreen canvas, not an early 1x1/default size.
        self.width = max(1, self.canvas.winfo_width())
        self.height = max(1, self.canvas.winfo_height())
        margin = max(70, round(min(self.width, self.height) * 0.09))
        self.targets = [
            (margin, margin),
            (self.width - margin, margin),
            (self.width - margin, self.height - margin),
            (margin, self.height - margin),
        ]
        self.index = 0
        self.misses = 0
        self.max_misses = 8
        self.tolerance = max(70, round(min(self.width, self.height) * 0.08))
        self.finished = False
        self.exit_code = 1

        root.bind("<Button-1>", self.on_click)
        root.bind("<Escape>", lambda _e: self.fail("Test byl prerusen."))
        root.after(90000, lambda: self.fail("Cas na test vyprsel."))
        root.lift()
        root.focus_force()
        self.draw()

    def _on_map(self, _event: tk.Event) -> None:
        schedule_labwc_fullscreen(self.root, title=WINDOW_TITLE, wm_class=WM_CLASS)

    def draw(self) -> None:
        self.canvas.delete("all")
        self.canvas.create_text(
            self.width // 2,
            42,
            text="TEST DOTYKOVEHO PANELU",
            fill="#f4f7fb",
            font=("Sans", 24, "bold"),
        )
        self.canvas.create_text(
            self.width // 2,
            82,
            text=f"Dotkni se stredu bodu {self.index + 1} / {len(self.targets)}",
            fill="#c6d0dc",
            font=("Sans", 16),
        )
        self.canvas.create_text(
            self.width // 2,
            self.height - 35,
            text=f"Fullscreen plocha: {self.width} x {self.height} px. Kurzor i misto kliku jsou viditelne.",
            fill="#8d9aab",
            font=("Sans", 13),
        )

        for i, (x, y) in enumerate(self.targets):
            if i < self.index:
                self.canvas.create_oval(x - 13, y - 13, x + 13, y + 13, fill="#2bd47d", outline="")
            elif i == self.index:
                r = 34
                self.canvas.create_oval(x - r, y - r, x + r, y + r, outline="#ffd24a", width=5)
                self.canvas.create_line(x - 48, y, x + 48, y, fill="#ffd24a", width=3)
                self.canvas.create_line(x, y - 48, x, y + 48, fill="#ffd24a", width=3)
                self.canvas.create_oval(x - 5, y - 5, x + 5, y + 5, fill="#ffffff", outline="")
            else:
                self.canvas.create_oval(x - 9, y - 9, x + 9, y + 9, outline="#657184", width=2)

    def on_click(self, event: tk.Event) -> None:
        if self.finished:
            return
        x, y = int(event.x), int(event.y)
        tx, ty = self.targets[self.index]
        ok = (x - tx) ** 2 + (y - ty) ** 2 <= self.tolerance ** 2

        color = "#2bd47d" if ok else "#ff5e69"
        self.canvas.create_oval(x - 10, y - 10, x + 10, y + 10, fill=color, outline="#ffffff", width=2)
        self.canvas.create_text(x + 18, y - 18, text=f"{x},{y}", fill=color, anchor="w", font=("Sans", 11, "bold"))
        self.canvas.update_idletasks()

        if ok:
            self.index += 1
            if self.index >= len(self.targets):
                self.pass_test()
            else:
                self.root.after(400, self.draw)
            return

        self.misses += 1
        if self.misses >= self.max_misses:
            self.root.after(500, lambda: self.fail("Kliky jsou prilis daleko od kontrolnich bodu."))

    def pass_test(self) -> None:
        if self.finished:
            return
        self.finished = True
        self.exit_code = 0
        self.canvas.delete("all")
        self.canvas.create_text(
            self.width // 2,
            self.height // 2 - 20,
            text="DOTYK FUNGUJE SPRAVNE",
            fill="#2bd47d",
            font=("Sans", 30, "bold"),
        )
        self.canvas.create_text(
            self.width // 2,
            self.height // 2 + 35,
            text="Pokracuji do instalacni faze...",
            fill="#dbe4ee",
            font=("Sans", 17),
        )
        self.root.after(1400, self.root.destroy)

    def fail(self, message: str) -> None:
        if self.finished:
            return
        self.finished = True
        self.exit_code = 1
        self.canvas.delete("all")
        self.canvas.create_text(
            self.width // 2,
            self.height // 2 - 25,
            text="TEST DOTYKU NEPROSEL",
            fill="#ff5e69",
            font=("Sans", 30, "bold"),
        )
        self.canvas.create_text(
            self.width // 2,
            self.height // 2 + 30,
            text=message + "\nAutomaticky se spusti nova kalibrace.",
            fill="#dbe4ee",
            font=("Sans", 16),
            justify="center",
        )
        self.root.after(2200, self.root.destroy)


root = tk.Tk()
app = TouchTest(root)
root.mainloop()
raise SystemExit(app.exit_code)
