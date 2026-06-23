#!/usr/bin/env python3
"""Small centered Material-style Gmail account chooser.
LAlt+G opens it. Up/Down (or j/k) to move, Enter to open, Esc to cancel,
1/2/3 to jump straight to an account, mouse click also works.
"""
import subprocess
import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, Gdk, GLib  # noqa: E402

# (title, subtitle, url) — edit titles/urls here to taste
ACCOUNTS = [
    ("Account 1", "mail/u/0", "https://mail.google.com/mail/u/0/"),
    ("Account 2", "mail/u/1", "https://mail.google.com/mail/u/1/"),
    ("Account 3", "mail/u/2", "https://mail.google.com/mail/u/2/"),
]

CSS = b"""
window { background: transparent; }
.card {
    background-color: #1c1b1f;
    border-radius: 28px;
    padding: 18px;
    box-shadow: 0 12px 40px rgba(0,0,0,0.55);
    border: 1px solid rgba(255,255,255,0.06);
}
.heading {
    color: #e6e1e9;
    font-size: 16px;
    font-weight: 700;
    margin: 4px 6px 12px 6px;
}
.hint {
    color: #938f99;
    font-size: 11px;
    margin: 12px 6px 2px 6px;
}
row {
    border-radius: 18px;
    padding: 10px 12px;
    margin: 3px 0;
    transition: background-color 120ms ease;
}
row:selected {
    background-color: #4f378b;
}
row:selected .title { color: #ffffff; }
row:selected .subtitle { color: #d9ccff; }
.title { color: #e6e1e9; font-size: 14px; font-weight: 600; }
.subtitle { color: #938f99; font-size: 11px; }
.badge {
    background-color: #2b2930;
    color: #cfbcff;
    font-weight: 700;
    font-size: 14px;
    border-radius: 999px;
    min-width: 34px;
    min-height: 34px;
    margin-right: 12px;
}
row:selected .badge {
    background-color: #cfbcff;
    color: #381e72;
}
"""


class Chooser(Adw.Application):
    def __init__(self):
        super().__init__(application_id="com.pratik.gmailchooser")

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_title("Gmail")
        win.set_default_size(340, -1)
        win.set_resizable(False)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        card.add_css_class("card")

        heading = Gtk.Label(label="Open Gmail account", xalign=0)
        heading.add_css_class("heading")
        card.append(heading)

        self.listbox = Gtk.ListBox()
        self.listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.listbox.add_css_class("nav")
        for i, (title, sub, _url) in enumerate(ACCOUNTS):
            self.listbox.append(self._make_row(i, title, sub))
        self.listbox.connect("row-activated", self._on_activate)
        card.append(self.listbox)

        hint = Gtk.Label(label="↑ ↓ select   ⏎ open   esc cancel", xalign=0)
        hint.add_css_class("hint")
        card.append(hint)

        win.set_child(card)

        # select first row
        self.listbox.select_row(self.listbox.get_row_at_index(0))

        key = Gtk.EventControllerKey()
        key.connect("key-pressed", self._on_key)
        win.add_controller(key)

        win.present()

    def _make_row(self, idx, title, sub):
        row = Gtk.ListBoxRow()
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)

        badge = Gtk.Label(label=str(idx + 1))
        badge.add_css_class("badge")
        badge.set_valign(Gtk.Align.CENTER)
        box.append(badge)

        text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, valign=Gtk.Align.CENTER)
        t = Gtk.Label(label=title, xalign=0)
        t.add_css_class("title")
        s = Gtk.Label(label=sub, xalign=0)
        s.add_css_class("subtitle")
        text.append(t)
        text.append(s)
        box.append(text)

        row.set_child(box)
        return row

    def _open(self, idx):
        subprocess.Popen(
            ["xdg-open", ACCOUNTS[idx][2]],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        self.quit()

    def _on_activate(self, _listbox, row):
        self._open(row.get_index())

    def _on_key(self, _ctrl, keyval, _code, _state):
        name = Gdk.keyval_name(keyval)
        if name in ("Escape", "q"):
            self.quit()
            return True
        if name in ("Return", "KP_Enter", "space"):
            row = self.listbox.get_selected_row()
            if row:
                self._open(row.get_index())
            return True
        if name in ("1", "2", "3", "KP_1", "KP_2", "KP_3"):
            self._open(int(name[-1]) - 1)
            return True
        if name in ("Down", "j", "Tab"):
            self._move(1)
            return True
        if name in ("Up", "k", "ISO_Left_Tab"):
            self._move(-1)
            return True
        return False

    def _move(self, delta):
        row = self.listbox.get_selected_row()
        idx = row.get_index() if row else 0
        idx = (idx + delta) % len(ACCOUNTS)
        self.listbox.select_row(self.listbox.get_row_at_index(idx))


if __name__ == "__main__":
    Chooser().run(None)
