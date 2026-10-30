#!/usr/bin/env python3
"""
Carbon Pomodoro & Focus Tracker
A sleek, modern GTK4 + Libadwaita application linked with Carbon Shell's Pomodoro timer,
tasks, and shared state across ~/.config/carbon/ and ~/.config/hypr/.
Features signature Carbon Lewis Dot splash animation, interactive circular timer,
a floating draggable PiP capsule when closed while running, transition sound effects,
auto-silencing of notifications & Discord/Serein chat sounds during focus sessions,
customizable daily goals, per-task time tracking, and GNOME Focus-style total activity analytics.
"""

import os
import sys
import json
import math
import time
import subprocess
import threading
import atexit
import signal
from datetime import datetime, date

# Ensure user site-packages are accessible across environments
user_site = os.path.expanduser(f"~/.local/lib/python{sys.version_info.major}.{sys.version_info.minor}/site-packages")
if os.path.exists(user_site) and user_site not in sys.path:
    sys.path.insert(0, user_site)

# Ensure instant GTK4 launch without Vulkan GPU enumeration stalls
os.environ.setdefault("GSK_RENDERER", "cairo")

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")
from gi.repository import Gtk, Adw, Gio, GLib, Pango, Gdk, PangoCairo

try:
    import cairo
except ImportError:
    try:
        from gi.repository import cairo
    except ImportError as e:
        subprocess.run([
            "notify-send", "-a", "Carbon Pomodoro", "-u", "critical",
            "Missing Cairo Dependency",
            "python-cairo is required to render the Carbon Pomodoro progress ring."
        ], check=False)
        raise e


def _resolve_config_dirs():
    dirs = []
    env_dir = os.environ.get("CARBON_CONFIG_DIR")
    if env_dir:
        dirs.append(os.path.abspath(os.path.expanduser(env_dir)))
    for p in ["~/.config/carbon", "~/.config/hypr"]:
        full = os.path.abspath(os.path.expanduser(p))
        if full not in dirs:
            dirs.append(full)
    return dirs


CONFIG_DIRS = _resolve_config_dirs()


def get_read_path(filename):
    for d in CONFIG_DIRS:
        p = os.path.join(d, filename)
        if os.path.exists(p):
            return p
    for d in CONFIG_DIRS:
        if os.path.isdir(d):
            return os.path.join(d, filename)
    return os.path.join(CONFIG_DIRS[0], filename)


def get_write_paths(filename):
    paths = []
    for d in CONFIG_DIRS:
        if os.path.isdir(d):
            paths.append(os.path.join(d, filename))
    if not paths:
        paths.append(os.path.expanduser(f"~/.config/hypr/{filename}"))
    return paths


POMO_STATE_PATH = get_read_path("carbon-pomodoro.json")
TODOS_PATH = get_read_path("carbon-todos.json")
THEME_JSON_PATH = get_read_path("theme.json")


def load_theme():
    theme = {}
    theme_path = get_read_path("theme.json")
    if os.path.exists(theme_path):
        try:
            with open(theme_path, "r", encoding="utf-8") as f:
                theme = json.load(f)
        except Exception:
            pass
    return {
        "bg": theme.get("bg", "#121214"),
        "accent": theme.get("accent", "#00F0FF"),
        "accentLit": theme.get("accentLit", "#FFFFFF"),
        "fg": theme.get("fg", "#e5e5e5"),
        "fgDim": theme.get("fgDim", "#ababab"),
        "fgFaint": theme.get("fgFaint", "#767676"),
        "isDark": theme.get("isDark", True)
    }


_last_sound_time = 0.0

def play_sound(sound_name="complete"):
    """
    Play a clean notification sound using paplay / canberra-gtk-play.
    Debounced so it cannot fire multiple times in rapid succession,
    and runs in a daemon thread so it never leaves zombie defunct processes.
    """
    global _last_sound_time
    now = time.time()
    if now - _last_sound_time < 2.0:
        return
    _last_sound_time = now

    def _worker():
        sound_map = {
            "complete": "/usr/share/sounds/freedesktop/stereo/complete.oga",
            "bell": "/usr/share/sounds/freedesktop/stereo/bell.oga",
        }
        fpath = sound_map.get(sound_name)
        if fpath and os.path.exists(fpath):
            try:
                subprocess.run(
                    ["paplay", fpath],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=3
                )
                return
            except Exception:
                pass
        try:
            subprocess.run(
                ["canberra-gtk-play", "-i", sound_name],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=3
            )
        except Exception:
            pass

    threading.Thread(target=_worker, daemon=True).start()


# ── Distraction & Audio Manager ──────────────────────────────────────────────
CHAT_PATTERNS = {"discord", "vesktop", "webcord", "serein", "cz.viceverse.serein", "equibop", "legcord"}

class DistractionManager:
    """
    Manages muting of notifications (DND) and chat applications (Discord, Serein)
    during active focus sessions, and restoring them during breaks or session ends.
    Uses pactl subscribe in a daemon thread to catch dynamic notification audio streams.
    """
    def __init__(self):
        self.focus_active = False
        self.muted_sink_inputs = set()
        self._lock = threading.Lock()
        self._sub_proc = None
        self._sub_thread = threading.Thread(target=self._subscriber_loop, daemon=True)
        self._sub_thread.start()

    def get_chat_pids(self):
        pids = set()
        for name in ("serein", "discord", "vesktop", "webcord", "equibop", "legcord"):
            try:
                out = subprocess.check_output(["pgrep", "-i", name], text=True, stderr=subprocess.DEVNULL)
                for line in out.strip().split():
                    if line:
                        pids.add(line)
            except Exception:
                pass
        return pids

    def _is_chat_stream(self, item, chat_pids):
        props = item.get("properties", {})
        pid = str(props.get("application.process.id", ""))
        app_name = str(props.get("application.name", "")).lower()
        binary = str(props.get("application.process.binary", "")).lower()
        node_name = str(props.get("node.name", "")).lower()
        media_name = str(props.get("media.name", "")).lower()

        if pid and pid in chat_pids:
            return True
        for pat in CHAT_PATTERNS:
            if pat in app_name or pat in binary or pat in node_name or pat in media_name:
                return True
        if "cpal-pulseaudio" in app_name or "cpal-pulseaudio" in node_name:
            for cpid in chat_pids:
                if f"cpal-pulseaudio-{cpid}" in app_name or f"cpal-pulseaudio-{cpid}" in node_name:
                    return True
            if chat_pids:
                return True
        return False

    def mute_chat_streams(self):
        chat_pids = self.get_chat_pids()
        try:
            res = subprocess.run(["pactl", "-f", "json", "list", "sink-inputs"], capture_output=True, text=True, timeout=2)
            if not res.stdout.strip():
                return
            inputs = json.loads(res.stdout)
            for item in inputs:
                idx = item.get("index")
                if idx is None:
                    continue
                if self._is_chat_stream(item, chat_pids):
                    if not item.get("mute", False):
                        subprocess.run(["pactl", "set-sink-input-mute", str(idx), "1"], check=False)
                    with self._lock:
                        self.muted_sink_inputs.add(idx)
        except Exception:
            pass

    def unmute_chat_streams(self):
        with self._lock:
            to_unmute = set(self.muted_sink_inputs)
            self.muted_sink_inputs.clear()

        chat_pids = self.get_chat_pids()
        try:
            res = subprocess.run(["pactl", "-f", "json", "list", "sink-inputs"], capture_output=True, text=True, timeout=2)
            if res.stdout.strip():
                inputs = json.loads(res.stdout)
                for item in inputs:
                    idx = item.get("index")
                    if idx is not None and self._is_chat_stream(item, chat_pids):
                        to_unmute.add(idx)
        except Exception:
            pass

        for idx in to_unmute:
            try:
                subprocess.run(["pactl", "set-sink-input-mute", str(idx), "0"], check=False)
            except Exception:
                pass

    def _apply_dnd(self, enabled: bool):
        # 1. Update carbon-notifications.json across all config paths
        for path in get_write_paths("carbon-notifications.json"):
            try:
                data = {}
                if os.path.exists(path):
                    with open(path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                data["dnd"] = enabled
                with open(path, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)
            except Exception:
                pass

        # 2. Touch / remove /tmp/carbon-dnd.on flag file
        dnd_flag = "/tmp/carbon-dnd.on"
        if enabled:
            try:
                open(dnd_flag, "a").close()
            except Exception:
                pass
        else:
            try:
                if os.path.exists(dnd_flag):
                    os.remove(dnd_flag)
            except Exception:
                pass

        # 3. Notification daemon toggles (swaync, mako, dunst)
        try:
            if enabled:
                subprocess.run(["swaync-client", "-dn"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
                subprocess.run(["makoctl", "mode", "-a", "dnd"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
                subprocess.run(["dunstctl", "set-paused", "true"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            else:
                subprocess.run(["swaync-client", "-df"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
                subprocess.run(["makoctl", "mode", "-r", "dnd"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
                subprocess.run(["dunstctl", "set-paused", "false"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        except Exception:
            pass

    def set_focus_active(self, active: bool):
        with self._lock:
            if self.focus_active == active:
                return
            self.focus_active = active

        if active:
            self._apply_dnd(True)
            self.mute_chat_streams()
        else:
            self._apply_dnd(False)
            self.unmute_chat_streams()

    def _subscriber_loop(self):
        while True:
            try:
                proc = subprocess.Popen(["pactl", "subscribe"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
                self._sub_proc = proc
                for line in proc.stdout:
                    if "sink-input" in line:
                        with self._lock:
                            active = self.focus_active
                        if active and ("new" in line or "change" in line):
                            self.mute_chat_streams()
            except Exception:
                time.sleep(1)


# Global singleton distraction manager
distraction_mgr = DistractionManager()
atexit.register(lambda: distraction_mgr.set_focus_active(False))


# ── Opening Splash Animation ──────────────────────────────────────────────────
class CarbonSplashWidget(Gtk.DrawingArea):
    """
    Signature Carbon Lewis dot opening animation:
    1. Central 'C' with 4 valence dots smoothly fade in.
    2. The 4 dots glide outward toward the 4 window corners with cubic ease-out.
    3. The central 'C' dissolves gracefully.
    4. The dark splash backdrop dissolves smoothly, unveiling the application.
    """
    def __init__(self, accent_hex="#00F0FF", accent_lit_hex="#FFFFFF", bg_hex="#121214", on_finish=None):
        super().__init__()
        self.set_hexpand(True)
        self.set_vexpand(True)
        self.set_can_target(False)
        self.on_finish = on_finish
        self.start_time = None
        self.current_elapsed = 0.0
        self.tick_id = None
        self.is_finished = False

        def hex_to_rgb(h):
            h = h.lstrip("#")
            if len(h) == 8:
                return int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0, int(h[6:8], 16) / 255.0
            elif len(h) == 6:
                return int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0
            return 0.07, 0.07, 0.08

        self.accent_rgb = hex_to_rgb(accent_hex)
        self.accent_lit_rgb = hex_to_rgb(accent_lit_hex)
        self.bg_rgb = hex_to_rgb(bg_hex)

        self.font_desc = Pango.FontDescription("Valley Sans Bold 44")
        self.pango_layout = None
        self.c_w = 0
        self.c_h = 0

        self.set_draw_func(self.on_draw)
        self.connect("map", self.on_map)

    def on_map(self, widget):
        if not self.is_finished:
            self.start()

    def start(self):
        if self.is_finished:
            return
        self.start_time = None
        self.current_elapsed = 0.0
        self.set_visible(True)
        if self.tick_id is None:
            self.tick_id = self.add_tick_callback(self.on_tick)

    def on_tick(self, widget, frame_clock):
        t = frame_clock.get_frame_time() / 1_000_000.0
        if self.start_time is None:
            self.start_time = t

        elapsed = t - self.start_time
        self.current_elapsed = elapsed
        self.queue_draw()

        if elapsed >= 0.70:
            self.is_finished = True
            self.tick_id = None
            self.set_visible(False)
            if self.on_finish:
                self.on_finish()
            return GLib.SOURCE_REMOVE
        return GLib.SOURCE_CONTINUE

    def on_draw(self, area, cr, width, height):
        if self.is_finished:
            return

        elapsed = max(0.0, self.current_elapsed)
        cx = width / 2.0
        cy = height / 2.0

        bg_alpha = 1.0
        if elapsed > 0.46:
            bg_alpha = max(0.0, 1.0 - (elapsed - 0.46) / 0.24)

        br, bg, bb = self.bg_rgb
        cr.set_source_rgba(br, bg, bb, bg_alpha)
        cr.paint()

        if bg_alpha <= 0.001:
            return

        ar, ag, ab = self.accent_rgb
        alr, alg, alb = self.accent_lit_rgb

        c_alpha = 1.0
        if elapsed < 0.12:
            c_alpha = elapsed / 0.12
        elif elapsed > 0.18:
            c_alpha = max(0.0, 1.0 - (elapsed - 0.18) / 0.20)

        if c_alpha > 0.005:
            if self.pango_layout is None:
                self.pango_layout = PangoCairo.create_layout(cr)
                self.pango_layout.set_font_description(self.font_desc)
                self.pango_layout.set_text("C", -1)
                ink, log = self.pango_layout.get_pixel_extents()
                self.c_w = log.width
                self.c_h = log.height
            else:
                PangoCairo.update_layout(cr, self.pango_layout)

            c_scale = 1.0
            if elapsed > 0.18:
                c_scale = 1.0 - 0.10 * min(1.0, (elapsed - 0.18) / 0.20)

            cr.save()
            cr.translate(cx, cy)
            cr.scale(c_scale, c_scale)
            cr.set_source_rgba(alr, alg, alb, c_alpha * bg_alpha)
            cr.move_to(-self.c_w / 2.0, -self.c_h / 2.0)
            PangoCairo.show_layout(cr, self.pango_layout)
            cr.restore()

        r0 = 42.0
        pad = 32.0
        start_dots = [
            (cx, cy - r0),
            (cx + r0, cy),
            (cx, cy + r0),
            (cx - r0, cy)
        ]
        target_dots = [
            (pad, pad),
            (width - pad, pad),
            (width - pad, height - pad),
            (pad, height - pad)
        ]

        t_travel = max(0.0, min(1.0, (elapsed - 0.12) / 0.36))
        ease = 1.0 - math.pow(1.0 - t_travel, 3)

        dot_alpha = 1.0
        if elapsed < 0.12:
            dot_alpha = elapsed / 0.12
        elif t_travel > 0.70:
            dot_alpha = max(0.0, 1.0 - (t_travel - 0.70) / 0.30)

        dot_alpha *= bg_alpha

        if dot_alpha > 0.005:
            for i in range(4):
                sx, sy = start_dots[i]
                tx, ty = target_dots[i]
                cur_x = sx + (tx - sx) * ease
                cur_y = sy + (ty - sy) * ease

                cr.set_source_rgba(ar, ag, ab, 0.35 * dot_alpha)
                cr.arc(cur_x, cur_y, 8.5, 0, 2 * math.pi)
                cr.fill()

                cr.set_source_rgba(alr, alg, alb, dot_alpha)
                cr.arc(cur_x, cur_y, 5.5, 0, 2 * math.pi)
                cr.fill()


# ── Interactive Circular Timer Ring Widget ────────────────────────────────────
class CircularTimerWidget(Gtk.DrawingArea):
    """
    Interactive Cairo Timer Circle:
    - Click anywhere on the circle to Start / Pause
    - Scroll up / down with mouse wheel to adjust minutes (+/- 1 min)
    - Hover glow indication
    - Displays progress arc, pulsing bead, and crisp typography
    """
    def __init__(self, accent_hex="#00F0FF", accent_lit_hex="#FFFFFF", on_click=None, on_scroll=None):
        super().__init__()
        self.set_hexpand(True)
        self.set_vexpand(True)
        self.set_size_request(200, 200)
        self.set_cursor(Gdk.Cursor.new_from_name("pointer", None))

        self.on_click_callback = on_click
        self.on_scroll_callback = on_scroll

        self.progress = 1.0
        self.time_str = "25:00"
        self.phase_str = "FOCUS"
        self.session_str = "Session 1 of 8"
        self.is_running = False
        self.is_hovered = False

        def hex_to_rgb(h):
            h = h.lstrip("#")
            if len(h) >= 6:
                return int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0
            return 0.0, 0.94, 1.0

        self.accent_rgb = hex_to_rgb(accent_hex)
        self.accent_lit_rgb = hex_to_rgb(accent_lit_hex)

        self.font_time = Pango.FontDescription("Valley Sans Bold 34")
        self.font_phase = Pango.FontDescription("Valley Sans Bold 10")
        self.font_sub = Pango.FontDescription("Valley Sans 10")
        self.set_draw_func(self.on_draw)

        # Click gesture
        click_gesture = Gtk.GestureClick.new()
        click_gesture.connect("released", self._on_gesture_released)
        self.add_controller(click_gesture)

        # Scroll controller
        scroll_controller = Gtk.EventControllerScroll.new(Gtk.EventControllerScrollFlags.VERTICAL)
        scroll_controller.connect("scroll", self._on_scroll_event)
        self.add_controller(scroll_controller)

        # Motion / Hover controller
        motion_controller = Gtk.EventControllerMotion.new()
        motion_controller.connect("enter", self._on_motion_enter)
        motion_controller.connect("leave", self._on_motion_leave)
        self.add_controller(motion_controller)

    def _on_gesture_released(self, gesture, n_press, x, y):
        if self.on_click_callback:
            self.on_click_callback()

    def _on_scroll_event(self, controller, dx, dy):
        if self.on_scroll_callback:
            delta = -1 if dy > 0 else 1
            self.on_scroll_callback(delta)
        return True

    def _on_motion_enter(self, controller, x, y):
        self.is_hovered = True
        self.queue_draw()

    def _on_motion_leave(self, controller):
        self.is_hovered = False
        self.queue_draw()

    def update_state(self, progress, time_str, phase_str, session_str, is_running):
        self.progress = max(0.0, min(1.0, progress))
        self.time_str = time_str
        self.phase_str = phase_str
        self.session_str = session_str
        self.is_running = is_running
        self.queue_draw()

    def on_draw(self, area, cr, width, height):
        cx = width / 2.0
        cy = height / 2.0
        radius = min(cx, cy) - 18.0
        if radius < 30:
            return

        ar, ag, ab = self.accent_rgb
        alr, alg, alb = self.accent_lit_rgb

        if self.is_hovered:
            cr.set_source_rgba(ar, ag, ab, 0.05)
            cr.arc(cx, cy, radius, 0, 2 * math.pi)
            cr.fill()

        cr.set_line_width(7.0)
        cr.set_source_rgba(1.0, 1.0, 1.0, 0.07 if not self.is_hovered else 0.12)
        cr.arc(cx, cy, radius, 0, 2 * math.pi)
        cr.stroke()

        if self.progress > 0.001:
            cr.set_line_cap(cairo.LINE_CAP_ROUND)
            start_angle = -math.pi / 2.0
            end_angle = start_angle + (2 * math.pi * self.progress)

            if self.is_running or self.is_hovered:
                cr.set_line_width(12.0)
                cr.set_source_rgba(ar, ag, ab, 0.25 if self.is_running else 0.15)
                cr.arc(cx, cy, radius, start_angle, end_angle)
                cr.stroke()

            cr.set_line_width(6.5)
            cr.set_source_rgba(ar, ag, ab, 0.95)
            cr.arc(cx, cy, radius, start_angle, end_angle)
            cr.stroke()

            head_x = cx + radius * math.cos(end_angle)
            head_y = cy + radius * math.sin(end_angle)

            cr.set_source_rgba(alr, alg, alb, 1.0)
            cr.arc(head_x, head_y, 4.0, 0, 2 * math.pi)
            cr.fill()

            cr.set_source_rgba(ar, ag, ab, 0.45)
            cr.arc(head_x, head_y, 7.0, 0, 2 * math.pi)
            cr.fill()

        phase_layout = PangoCairo.create_layout(cr)
        phase_layout.set_font_description(self.font_phase)
        phase_layout.set_text(self.phase_str, -1)
        ink, log = phase_layout.get_pixel_extents()
        cr.set_source_rgba(ar, ag, ab, 0.95)
        cr.move_to(cx - log.width / 2.0, cy - 38.0)
        PangoCairo.show_layout(cr, phase_layout)

        time_layout = PangoCairo.create_layout(cr)
        time_layout.set_font_description(self.font_time)
        time_layout.set_text(self.time_str, -1)
        ink, log = time_layout.get_pixel_extents()
        cr.set_source_rgba(alr, alg, alb, 1.0)
        cr.move_to(cx - log.width / 2.0, cy - log.height / 2.0 + 2.0)
        PangoCairo.show_layout(cr, time_layout)

        sub_layout = PangoCairo.create_layout(cr)
        sub_layout.set_font_description(self.font_sub)
        sub_txt = "Click to Start • Scroll to adjust" if (not self.is_running and self.is_hovered) else self.session_str
        sub_layout.set_text(sub_txt, -1)
        ink, log = sub_layout.get_pixel_extents()
        cr.set_source_rgba(0.75, 0.75, 0.78, 0.75 if not self.is_hovered else 0.95)
        cr.move_to(cx - log.width / 2.0, cy + 28.0)
        PangoCairo.show_layout(cr, sub_layout)


# ── Floating Draggable PiP Digits Window ──────────────────────────────────────
class FloatingPipWindow(Gtk.Window):
    """
    Mini floating digits HUD that appears when main window is closed while a timer is active.
    - Contains ONLY the countdown digits (e.g. 24:59).
    - Floating & Pinned above all windows in Hyprland.
    - Double-click restores the main focus tracker app.
    """
    def __init__(self, app):
        super().__init__(application=app, title="Carbon Focus Mini")
        self.app = app
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(170, 58)
        self.add_css_class("pip-window")

        root_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        root_box.add_css_class("pip-capsule-digits")
        root_box.set_halign(Gtk.Align.CENTER)
        root_box.set_valign(Gtk.Align.CENTER)

        self.lbl_time = Gtk.Label(label="25:00")
        self.lbl_time.add_css_class("pip-digits-only")
        root_box.append(self.lbl_time)

        click = Gtk.GestureClick.new()
        click.connect("pressed", self.on_clicked)
        root_box.add_controller(click)

        self.set_child(root_box)

    def on_clicked(self, gesture, n_press, x, y):
        if n_press >= 2:
            self.app.restore_main_window()

    def update_display(self, state, todos):
        mode = state.get("mode", "pomo")
        if mode == "pomo":
            rem = state.get("remaining", state.get("workSec", 1500))
            m = rem // 60
            sec = rem % 60
            time_str = f"{m:02d}:{sec:02d}"
        else:
            elapsed = state.get("elapsed", 0)
            m = elapsed // 60
            sec = elapsed % 60
            time_str = f"{m:02d}:{sec:02d}"

        self.lbl_time.set_label(time_str)


# ── Main Pomodoro & Tracker Window ───────────────────────────────────────────
class PomodoroWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Carbon Focus & Tracker")
        self.app = app
        self.distraction_mgr = distraction_mgr
        self.history_scope = "all"  # Default to All-Time Total History
        self.current_toast = None
        self.set_default_size(980, 610)

        self.theme = load_theme()
        accent = self.theme["accent"]
        accent_lit = self.theme["accentLit"]

        # Intercept window close to minimize to PiP if running
        self.connect("close-request", self.on_close_request)

        # Load state & todos
        self.state = self.load_state()
        self.todos = self.load_todos()

        # Style manager dark scheme
        try:
            sm = Adw.StyleManager.get_default()
            sm.set_color_scheme(Adw.ColorScheme.FORCE_DARK if self.theme.get("isDark", True) else Adw.ColorScheme.FORCE_LIGHT)
        except Exception:
            pass

        # Custom CSS for Carbon Aesthetics
        def hex_to_rgb(h):
            h = h.lstrip("#")
            if len(h) >= 6:
                return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
            return 0, 240, 255

        ar, ag, ab = hex_to_rgb(accent)
        css = f"""
        @define-color accent_color {accent};
        @define-color accent_bg_color {accent};

        .suggested-action {{
            background-color: {accent};
            color: #121214;
            font-weight: 700;
            border-radius: 9999px;
            padding: 7px 22px;
            font-size: 13px;
        }}
        .suggested-action:hover {{
            background-color: {accent_lit};
            color: #121214;
        }}
        .circular-btn {{
            border-radius: 9999px;
            padding: 7px 16px;
            font-size: 12px;
            font-weight: 600;
        }}
        .glass-card {{
            background-color: rgba(255, 255, 255, 0.04);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 10px;
            padding: 10px 12px;
        }}
        .glass-card:hover {{
            background-color: rgba(255, 255, 255, 0.06);
            border-color: rgba({ar}, {ag}, {ab}, 0.35);
        }}
        .task-row-active {{
            background-color: rgba({ar}, {ag}, {ab}, 0.12);
            border: 1px solid rgba({ar}, {ag}, {ab}, 0.4);
            border-radius: 8px;
        }}
        .badge-active {{
            background-color: rgba({ar}, {ag}, {ab}, 0.18);
            color: {accent};
            border-radius: 9999px;
            font-weight: bold;
            font-size: 11px;
            padding: 3px 10px;
        }}
        .stat-val {{
            font-family: 'Valley Sans', sans-serif;
            font-size: 18px;
            font-weight: 800;
            color: {accent_lit};
        }}
        .stat-lbl {{
            font-size: 10px;
            color: #888892;
            text-transform: uppercase;
            letter-spacing: 0.6px;
        }}
        .stepper-btn {{
            border-radius: 9999px;
            padding: 1px 7px;
            min-height: 20px;
            min-width: 20px;
            font-size: 11px;
            font-weight: 800;
        }}
        .task-badge-time {{
            background-color: rgba(255, 255, 255, 0.06);
            border: 1px solid rgba(255, 255, 255, 0.10);
            border-radius: 6px;
            padding: 2px 7px;
            font-size: 11px;
            color: #ababab;
            font-weight: 600;
        }}
        .distraction-pill {{
            border-radius: 9999px;
            padding: 4px 14px;
            font-size: 11px;
            font-weight: 700;
        }}
        .distraction-active {{
            background-color: rgba(255, 100, 100, 0.15);
            color: #ff7b72;
            border: 1px solid rgba(255, 100, 100, 0.35);
        }}
        .distraction-idle {{
            background-color: rgba(255, 255, 255, 0.05);
            color: #8b949e;
            border: 1px solid rgba(255, 255, 255, 0.08);
        }}
        .finished-task-text {{
            text-decoration: line-through;
            color: #767676;
        }}
        .history-metric-val {{
            font-family: 'Valley Sans', sans-serif;
            font-size: 18px;
            font-weight: 800;
            color: {accent_lit};
        }}
        .history-metric-lbl {{
            font-size: 9px;
            color: #888892;
            text-transform: uppercase;
            letter-spacing: 0.6px;
        }}
        .preset-btn {{
            font-size: 11px;
            font-weight: 600;
            padding: 4px 10px;
            border-radius: 6px;
        }}
        .preset-btn-active {{
            background-color: rgba({ar}, {ag}, {ab}, 0.22);
            color: {accent};
            border: 1px solid rgba({ar}, {ag}, {ab}, 0.5);
            font-size: 11px;
            font-weight: 700;
            padding: 4px 10px;
            border-radius: 6px;
        }}
        /* PiP Transparent Digits-Only HUD CSS */
        window.pip-window {{
            background-color: transparent;
            background: none;
            border: none;
            box-shadow: none;
        }}
        .pip-capsule-digits {{
            background-color: transparent;
            background: none;
            border: none;
            box-shadow: none;
            padding: 0;
            margin: 0;
        }}
        .pip-digits-only {{
            font-family: 'Valley Sans Bold', sans-serif;
            font-size: 38px;
            font-weight: 800;
            color: #ffffff;
            letter-spacing: 1px;
            text-shadow: 0 2px 12px rgba(0, 0, 0, 0.9), 0 0 24px rgba(0, 0, 0, 0.75);
        }}
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER + 50
        )

        # Root Overlay holding Main Content + Splash Animation
        self.root_overlay = Gtk.Overlay()
        outer_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.toast_overlay = Adw.ToastOverlay.new()
        self.toast_overlay.set_child(outer_box)
        self.root_overlay.set_child(self.toast_overlay)

        # Splash Widget covering window with exact Carbon Lewis Dot animation
        self.splash_widget = CarbonSplashWidget(
            accent_hex=accent,
            accent_lit_hex=accent_lit,
            bg_hex=self.theme.get("bg", "#121214"),
            on_finish=self.on_splash_finished
        )
        self.root_overlay.add_overlay(self.splash_widget)
        self.set_content(self.root_overlay)

        # Header Bar
        header = Adw.HeaderBar()
        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        title_lbl = Gtk.Label(label="Carbon Focus")
        title_lbl.add_css_class("title")
        subtitle_lbl = Gtk.Label(label="Pomodoro & Study Tracker")
        subtitle_lbl.add_css_class("subtitle")
        title_box.append(title_lbl)
        title_box.append(subtitle_lbl)
        header.set_title_widget(title_box)

        # Mode switch in Header
        mode_switcher = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        mode_switcher.add_css_class("linked")
        self.btn_pomo = Gtk.ToggleButton(label="Pomodoro", active=(self.state.get("mode", "pomo") == "pomo"))
        self.btn_stop = Gtk.ToggleButton(label="Stopwatch", active=(self.state.get("mode") == "stop"))
        self.btn_pomo.connect("toggled", self.on_mode_toggled, "pomo")
        self.btn_stop.connect("toggled", self.on_mode_toggled, "stop")
        mode_switcher.append(self.btn_pomo)
        mode_switcher.append(self.btn_stop)
        header.pack_start(mode_switcher)

        # Active Session Pill & Mini Float button in header
        right_header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.phase_badge = Gtk.Label(label="⚡ Focus Session")
        self.phase_badge.add_css_class("badge-active")
        btn_pip_mode = Gtk.Button(label="⤢ Float")
        btn_pip_mode.set_tooltip_text("Minimize into floating PiP capsule (holds on top)")
        btn_pip_mode.add_css_class("flat")
        btn_pip_mode.connect("clicked", lambda b: self.app.show_pip_window())
        right_header_box.append(self.phase_badge)
        right_header_box.append(btn_pip_mode)
        header.pack_end(right_header_box)

        outer_box.append(header)

        # Balanced Main Content Box (2 Columns)
        content_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
        content_box.set_hexpand(True)
        content_box.set_vexpand(True)
        content_box.set_margin_top(12)
        content_box.set_margin_bottom(12)
        content_box.set_margin_start(16)
        content_box.set_margin_end(16)
        outer_box.append(content_box)

        # ── Left Column: Timer & Controls ──
        left_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        left_box.set_hexpand(True)
        left_box.set_vexpand(True)
        content_box.append(left_box)

        # Active Task Banner
        self.active_task_banner = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.active_task_banner.add_css_class("glass-card")
        self.task_banner_icon = Gtk.Label(label="🎯")
        self.task_banner_lbl = Gtk.Label(label="Pick a task on the right to focus", hexpand=True, xalign=0)
        self.task_banner_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        self.active_task_banner.append(self.task_banner_icon)
        self.active_task_banner.append(self.task_banner_lbl)
        left_box.append(self.active_task_banner)

        # Interactive Circular Timer Display
        self.timer_widget = CircularTimerWidget(
            accent_hex=accent,
            accent_lit_hex=accent_lit,
            on_click=self.on_timer_clicked,
            on_scroll=self.on_timer_scrolled
        )
        left_box.append(self.timer_widget)

        # Dynamic Session Target Dots (matches user daily goal, no hardcoded 4!)
        self.dots_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.dots_box.set_halign(Gtk.Align.CENTER)
        left_box.append(self.dots_box)

        # Primary Controls Row
        controls_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        controls_row.set_halign(Gtk.Align.CENTER)

        self.btn_reset = Gtk.Button(label="Reset")
        self.btn_reset.add_css_class("circular-btn")
        self.btn_reset.connect("clicked", self.on_reset_clicked)

        self.btn_start = Gtk.Button(label="START FOCUS")
        self.btn_start.add_css_class("suggested-action")
        self.btn_start.connect("clicked", self.on_start_pause_clicked)

        self.btn_skip = Gtk.Button(label="Skip Phase")
        self.btn_skip.add_css_class("circular-btn")
        self.btn_skip.connect("clicked", self.on_skip_clicked)

        self.btn_end = Gtk.Button(label="End Session")
        self.btn_end.add_css_class("circular-btn")
        self.btn_end.set_tooltip_text("End current focus session, log progress, and unmute sounds")
        self.btn_end.connect("clicked", self.on_end_session_clicked)

        controls_row.append(self.btn_reset)
        controls_row.append(self.btn_start)
        controls_row.append(self.btn_skip)
        controls_row.append(self.btn_end)
        left_box.append(controls_row)

        # Distraction & Sound Status Pill
        self.distraction_pill = Gtk.Label(label="🔔 Alerts & Sounds Active")
        self.distraction_pill.add_css_class("distraction-pill")
        self.distraction_pill.add_css_class("distraction-idle")
        self.distraction_pill.set_halign(Gtk.Align.CENTER)
        left_box.append(self.distraction_pill)

        # Quick Interval Adjuster row (25m / 50m / 5m / 15m)
        self.interval_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.interval_box.set_halign(Gtk.Align.CENTER)

        self.btn_25 = Gtk.Button(label="25m Focus")
        self.btn_25.connect("clicked", self.on_set_work_min, 25)
        self.btn_50 = Gtk.Button(label="50m Focus")
        self.btn_50.connect("clicked", self.on_set_work_min, 50)
        self.btn_5 = Gtk.Button(label="5m Break")
        self.btn_5.connect("clicked", self.on_set_break_min, 5)
        self.btn_15 = Gtk.Button(label="15m Long")
        self.btn_15.connect("clicked", self.on_set_long_break_min, 15)

        for b in (self.btn_25, self.btn_50, self.btn_5, self.btn_15):
            b.add_css_class("preset-btn")
            self.interval_box.append(b)

        left_box.append(self.interval_box)

        # Separator line between columns
        sep = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        content_box.append(sep)

        # ── Right Column: Linked Tracker, Tasks & Total History ──
        right_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        right_box.set_hexpand(True)
        right_box.set_vexpand(True)
        content_box.append(right_box)

        # Stats Cards Row (3 Cards with interactive daily goal target stepper)
        stats_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        stats_row.set_homogeneous(True)

        card1 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        card1.add_css_class("glass-card")
        self.lbl_stat_sessions = Gtk.Label(label="0", xalign=0)
        self.lbl_stat_sessions.add_css_class("stat-val")
        lbl1_desc = Gtk.Label(label="COMPLETED TODAY", xalign=0)
        lbl1_desc.add_css_class("stat-lbl")
        card1.append(self.lbl_stat_sessions)
        card1.append(lbl1_desc)
        stats_row.append(card1)

        card2 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        card2.add_css_class("glass-card")
        self.lbl_stat_time = Gtk.Label(label="0m", xalign=0)
        self.lbl_stat_time.add_css_class("stat-val")
        lbl2_desc = Gtk.Label(label="TODAY'S FOCUS", xalign=0)
        lbl2_desc.add_css_class("stat-lbl")
        card2.append(self.lbl_stat_time)
        card2.append(lbl2_desc)
        stats_row.append(card2)

        card3 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        card3.add_css_class("glass-card")
        card3_header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        self.lbl_stat_target = Gtk.Label(label="0 / 8", xalign=0, hexpand=True)
        self.lbl_stat_target.add_css_class("stat-val")

        stepper_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        btn_goal_dec = Gtk.Button(label="−")
        btn_goal_dec.add_css_class("flat")
        btn_goal_dec.add_css_class("stepper-btn")
        btn_goal_dec.set_tooltip_text("Decrease daily goal target")
        btn_goal_dec.connect("clicked", lambda b: self.on_adjust_goal(-1))

        btn_goal_inc = Gtk.Button(label="+")
        btn_goal_inc.add_css_class("flat")
        btn_goal_inc.add_css_class("stepper-btn")
        btn_goal_inc.set_tooltip_text("Increase daily goal target")
        btn_goal_inc.connect("clicked", lambda b: self.on_adjust_goal(1))

        stepper_box.append(btn_goal_dec)
        stepper_box.append(btn_goal_inc)

        card3_header.append(self.lbl_stat_target)
        card3_header.append(stepper_box)

        self.lbl3_desc = Gtk.Label(label="DAILY GOAL", xalign=0)
        self.lbl3_desc.add_css_class("stat-lbl")
        card3.append(card3_header)
        card3.append(self.lbl3_desc)
        stats_row.append(card3)

        right_box.append(stats_row)

        # Daily Goal Progress Bar
        self.progress_bar = Gtk.ProgressBar()
        self.progress_bar.set_fraction(0.0)
        right_box.append(self.progress_bar)

        # View Switcher (Tasks vs Activity & History)
        switcher_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        switcher_box.add_css_class("linked")
        switcher_box.set_halign(Gtk.Align.FILL)

        self.btn_view_tasks = Gtk.ToggleButton(label="📋 Tasks & Goals", active=True, hexpand=True)
        self.btn_view_history = Gtk.ToggleButton(label="📊 Activity & History", active=False, hexpand=True)
        self.btn_view_tasks.connect("toggled", self.on_view_switcher_toggled, "tasks")
        self.btn_view_history.connect("toggled", self.on_view_switcher_toggled, "history")
        switcher_box.append(self.btn_view_tasks)
        switcher_box.append(self.btn_view_history)
        right_box.append(switcher_box)

        # Gtk.Stack containing Tasks View and History View
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_hexpand(True)
        self.stack.set_vexpand(True)

        # ── Page 1: Tasks View ──
        page_tasks = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        page_tasks.set_hexpand(True)
        page_tasks.set_vexpand(True)

        add_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.task_entry = Gtk.Entry()
        self.task_entry.set_placeholder_text("Add a new task or focus goal (press Enter)...")
        self.task_entry.set_hexpand(True)
        self.task_entry.connect("activate", self.on_add_task_entered)
        btn_add_task = Gtk.Button(label="Add")
        btn_add_task.connect("clicked", self.on_add_task_entered)
        add_box.append(self.task_entry)
        add_box.append(btn_add_task)
        page_tasks.append(add_box)

        scrolled_tasks = Gtk.ScrolledWindow()
        scrolled_tasks.set_vexpand(True)
        scrolled_tasks.set_hexpand(True)
        self.task_list_box = Gtk.ListBox()
        self.task_list_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.task_list_box.add_css_class("boxed-list")
        self.task_list_box.connect("row-activated", self.on_task_row_activated)
        scrolled_tasks.set_child(self.task_list_box)
        page_tasks.append(scrolled_tasks)

        self.stack.add_named(page_tasks, "tasks")

        # ── Page 2: Total History & Activity View ──
        page_history = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        page_history.set_hexpand(True)
        page_history.set_vexpand(True)

        # Scope Selector (All-Time History vs Today Only)
        scope_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        scope_box.add_css_class("linked")
        scope_box.set_halign(Gtk.Align.CENTER)
        scope_box.set_margin_top(2)
        scope_box.set_margin_bottom(4)

        self.btn_scope_all = Gtk.ToggleButton(label="🌐 All-Time History", active=(self.history_scope == "all"))
        self.btn_scope_today = Gtk.ToggleButton(label="📅 Today Only", active=(self.history_scope == "today"))
        self.btn_scope_all.connect("toggled", self.on_history_scope_toggled, "all")
        self.btn_scope_today.connect("toggled", self.on_history_scope_toggled, "today")
        scope_box.append(self.btn_scope_all)
        scope_box.append(self.btn_scope_today)
        page_history.append(scope_box)

        scrolled_history = Gtk.ScrolledWindow()
        scrolled_history.set_vexpand(True)
        scrolled_history.set_hexpand(True)
        self.history_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.history_container.set_margin_top(4)
        self.history_container.set_margin_bottom(8)
        self.history_container.set_margin_start(4)
        self.history_container.set_margin_end(4)
        scrolled_history.set_child(self.history_container)
        page_history.append(scrolled_history)

        self.stack.add_named(page_history, "history")
        right_box.append(self.stack)

        # Render Task List and UI initially
        self.render_task_list()
        self.render_all(skip_tasks=True)

        read_path = get_read_path("carbon-pomodoro.json")
        self.last_saved_mtime = os.path.getmtime(read_path) if os.path.exists(read_path) else 0.0

        # Periodic timer tick (1 second)
        GLib.timeout_add(1000, self.on_second_tick)

    def on_view_switcher_toggled(self, btn, view_name):
        if not btn.get_active():
            return
        if view_name == "tasks":
            self.btn_view_history.handler_block_by_func(self.on_view_switcher_toggled)
            self.btn_view_history.set_active(False)
            self.btn_view_history.handler_unblock_by_func(self.on_view_switcher_toggled)
            self.stack.set_visible_child_name("tasks")
        else:
            self.btn_view_tasks.handler_block_by_func(self.on_view_switcher_toggled)
            self.btn_view_tasks.set_active(False)
            self.btn_view_tasks.handler_unblock_by_func(self.on_view_switcher_toggled)
            self.render_history_view()
            self.stack.set_visible_child_name("history")

    def on_history_scope_toggled(self, btn, scope_name):
        if not btn.get_active():
            return
        self.history_scope = scope_name
        if scope_name == "all":
            self.btn_scope_today.handler_block_by_func(self.on_history_scope_toggled)
            self.btn_scope_today.set_active(False)
            self.btn_scope_today.handler_unblock_by_func(self.on_history_scope_toggled)
        else:
            self.btn_scope_all.handler_block_by_func(self.on_history_scope_toggled)
            self.btn_scope_all.set_active(False)
            self.btn_scope_all.handler_unblock_by_func(self.on_history_scope_toggled)
        self.render_history_view()

    def on_adjust_goal(self, delta):
        cur = self.state.get("targetSessions", 8)
        new_val = max(1, min(50, cur + delta))
        self.state["targetSessions"] = new_val
        self.save_state()
        self.render_all(skip_tasks=True)
        self.debounce_toast(f"Daily Goal set to {new_val} sessions", delay_ms=250)

    def on_close_request(self, window):
        """
        When user closes the window:
        - If timer is running -> hide main window & pop up mini floating PiP capsule!
        - If timer is not running (paused) -> hide main window (app stays in background ready for Super+P).
        """
        self.save_state()
        self.set_visible(False)
        if self.state.get("running", False):
            self.app.show_pip_window()
        else:
            if hasattr(self.app, "pip_win") and self.app.pip_win:
                self.app.pip_win.hide()
        return True

    def on_splash_finished(self):
        try:
            self.root_overlay.remove_overlay(self.splash_widget)
        except Exception:
            pass
        self.splash_widget.set_visible(False)
        self.splash_widget.set_can_target(False)

    def show_toast(self, text):
        """
        Display an in-app toast notification.
        If a toast is already active, dismisses it immediately and displays
        the latest change so toasts never stack or queue.
        """
        if getattr(self, "current_toast", None):
            try:
                self.current_toast.dismiss()
            except Exception:
                pass
            self.current_toast = None

        toast = Adw.Toast.new(text)
        toast.set_timeout(2)
        self.current_toast = toast

        def on_dismissed(t):
            if getattr(self, "current_toast", None) == t:
                self.current_toast = None

        toast.connect("dismissed", on_dismissed)
        self.toast_overlay.add_toast(toast)

    def debounce_toast(self, text, delay_ms=150):
        """
        Debounce rapid successive changes (e.g. scrolling wheel or stepping goals)
        so only the final/latest change triggers a toast notification.
        """
        if getattr(self, "_toast_timer_id", None):
            try:
                GLib.source_remove(self._toast_timer_id)
            except Exception:
                pass
            self._toast_timer_id = None

        def _fire():
            self._toast_timer_id = None
            self.show_toast(text)
            return False

        self._toast_timer_id = GLib.timeout_add(delay_ms, _fire)

    # ── State Storage ─────────────────────────────────────────────────────────
    def reload_state_from_disk(self):
        disk_state = self.load_state()
        self.state.update(disk_state)
        self.todos = self.load_todos()

    def load_state(self):
        default_state = {
            "running": False,
            "mode": "pomo",
            "phase": "work",
            "remaining": 25 * 60,
            "elapsed": 0,
            "workSec": 25 * 60,
            "breakSec": 5 * 60,
            "longBreakSec": 15 * 60,
            "cycles": 0,
            "activeTaskId": None,
            "todayDate": str(date.today()),
            "todaySessions": 0,
            "todayFocusSeconds": 0,
            "totalSessions": 0,
            "totalFocusSeconds": 0,
            "targetSessions": 8,
            "history": []
        }
        read_path = get_read_path("carbon-pomodoro.json")
        if os.path.exists(read_path):
            try:
                self.last_saved_mtime = os.path.getmtime(read_path)
                with open(read_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    default_state.update(data)
            except Exception:
                pass

        today_str = str(date.today())
        if default_state.get("todayDate") != today_str:
            default_state["todayDate"] = today_str
            default_state["todaySessions"] = 0
            default_state["todayFocusSeconds"] = 0

        # Auto-compute lifetime metrics if missing
        hist_sec = sum(h.get("duration", 0) for h in default_state.get("history", []))
        default_state["totalFocusSeconds"] = max(
            default_state.get("totalFocusSeconds", 0),
            hist_sec,
            default_state.get("todayFocusSeconds", 0)
        )
        hist_count = sum(1 for h in default_state.get("history", []) if h.get("status") == "completed")
        default_state["totalSessions"] = max(
            default_state.get("totalSessions", 0),
            hist_count,
            default_state.get("todaySessions", 0)
        )

        return default_state

    def save_state(self):
        latest_mtime = 0.0
        for p in get_write_paths("carbon-pomodoro.json"):
            try:
                os.makedirs(os.path.dirname(p), exist_ok=True)
                with open(p, "w", encoding="utf-8") as f:
                    json.dump(self.state, f, indent=2)
                latest_mtime = max(latest_mtime, os.path.getmtime(p))
            except Exception as e:
                print(f"Error saving pomodoro state to {p}:", e)
        if latest_mtime > 0.0:
            self.last_saved_mtime = latest_mtime

    def load_todos(self):
        read_path = get_read_path("carbon-todos.json")
        if os.path.exists(read_path):
            try:
                with open(read_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return []

    def save_todos(self):
        for p in get_write_paths("carbon-todos.json"):
            try:
                os.makedirs(os.path.dirname(p), exist_ok=True)
                with open(p, "w", encoding="utf-8") as f:
                    json.dump(self.todos, f, indent=2)
            except Exception as e:
                print(f"Error saving todos to {p}:", e)

    def get_total_focus_seconds(self):
        from_state = self.state.get("totalFocusSeconds", 0)
        from_hist = sum(h.get("duration", 0) for h in self.state.get("history", []))
        from_todos = sum(t.get("spent_seconds", 0) for t in getattr(self, "todos", []))
        today_sec = self.state.get("todayFocusSeconds", 0)
        return max(from_state, from_hist, from_todos, today_sec)

    def get_total_sessions_count(self):
        from_state = self.state.get("totalSessions", 0)
        from_hist = sum(1 for h in self.state.get("history", []) if h.get("status") == "completed")
        today_sess = self.state.get("todaySessions", 0)
        return max(from_state, from_hist, today_sess)

    # ── UI Rendering ──────────────────────────────────────────────────────────
    def fmt_time(self, s):
        m = s // 60
        sec = s % 60
        if m >= 60:
            h = m // 60
            rm = m % 60
            return f"{h:02d}:{rm:02d}:{sec:02d}"
        return f"{m:02d}:{sec:02d}"

    def format_duration_short(self, sec):
        if sec <= 0:
            return "0m"
        m = sec // 60
        if m < 60:
            return f"{max(1, m)}m" if m > 0 else f"{sec}s"
        h = m // 60
        rm = m % 60
        if rm == 0:
            return f"{h}h"
        return f"{h}h {rm}m"

    def format_date_header(self, date_str):
        try:
            d = datetime.strptime(date_str, "%Y-%m-%d").date()
            today = date.today()
            if d == today:
                return f"Today ({d.strftime('%b %d')})"
            elif (today - d).days == 1:
                return f"Yesterday ({d.strftime('%b %d')})"
            else:
                return d.strftime("%A, %b %d, %Y")
        except Exception:
            return date_str

    def update_cycle_dots(self):
        while True:
            child = self.dots_box.get_first_child()
            if child is None:
                break
            self.dots_box.remove(child)

        target = max(1, self.state.get("targetSessions", 8))
        today_sessions = self.state.get("todaySessions", 0)
        running = self.state.get("running", False)
        phase = self.state.get("phase", "work")

        if target <= 12:
            for idx in range(target):
                dot = Gtk.Label()
                if idx < today_sessions:
                    dot.set_label("●")
                    dot.add_css_class("stat-val")
                elif idx == today_sessions and running and phase == "work":
                    dot.set_label("◉")
                    dot.add_css_class("badge-active")
                else:
                    dot.set_label("○")
                    dot.add_css_class("dim-label")
                self.dots_box.append(dot)
        else:
            lbl = Gtk.Label(label=f"● {today_sessions} of {target} target sessions")
            lbl.add_css_class("dim-label")
            self.dots_box.append(lbl)

    def render_all(self, skip_tasks=False):
        mode = self.state.get("mode", "pomo")
        running = self.state.get("running", False)
        phase = self.state.get("phase", "work")
        today_sessions = self.state.get("todaySessions", 0)
        today_sec = self.state.get("todayFocusSeconds", 0)
        target = self.state.get("targetSessions", 8)

        self.btn_pomo.handler_block_by_func(self.on_mode_toggled)
        self.btn_stop.handler_block_by_func(self.on_mode_toggled)
        self.btn_pomo.set_active(mode == "pomo")
        self.btn_stop.set_active(mode == "stop")
        self.btn_pomo.handler_unblock_by_func(self.on_mode_toggled)
        self.btn_stop.handler_unblock_by_func(self.on_mode_toggled)

        active_id = self.state.get("activeTaskId")
        active_task = next((t for t in self.todos if t.get("id") == active_id), None)

        if mode == "pomo":
            rem = self.state.get("remaining", self.state.get("workSec", 1500))
            if phase == "work":
                tot = self.state.get("workSec", 1500)
                phase_label = "FOCUS"
            elif phase == "short_break":
                tot = self.state.get("breakSec", 300)
                phase_label = "SHORT BREAK"
            else:
                tot = self.state.get("longBreakSec", 900)
                phase_label = "LONG BREAK"

            progress = rem / max(1, tot) if tot > 0 else 0.0
            time_display = self.fmt_time(rem)

            if active_task:
                task_text = active_task.get("text", "")
                if len(task_text) > 24:
                    task_text = task_text[:22] + "…"
                session_display = f"🎯 {task_text}"
            else:
                session_display = f"Session {today_sessions + 1} of {target}" if target > 0 else f"Session #{today_sessions + 1}"
        else:
            elapsed = self.state.get("elapsed", 0)
            progress = (elapsed % 60) / 60.0
            time_display = self.fmt_time(elapsed)
            phase_label = "STOPWATCH"
            session_display = f"Elapsed {elapsed}s"

        self.timer_widget.update_state(progress, time_display, phase_label, session_display, running)

        if running:
            self.btn_start.set_label("PAUSE")
            self.btn_start.remove_css_class("suggested-action")
        else:
            self.btn_start.set_label("START FOCUS" if mode == "pomo" else "START TIMER")
            self.btn_start.add_css_class("suggested-action")

        # Header Badge: dynamic, clear, NO hardcoded '4/4'
        if mode == "stop":
            self.phase_badge.set_label("⏱️ Stopwatch")
        elif phase == "work":
            if active_task:
                t_title = active_task.get("text", "")
                if len(t_title) > 20:
                    t_title = t_title[:18] + "…"
                self.phase_badge.set_label(f"⚡ Focus: {t_title}")
            else:
                self.phase_badge.set_label(f"⚡ Focus Session #{today_sessions + 1}")
        elif phase == "short_break":
            self.phase_badge.set_label("☕ Short Break")
        else:
            self.phase_badge.set_label("🌴 Long Break")

        # Distraction status pill
        is_focus_active = (mode == "pomo" and running and phase == "work")
        self.distraction_pill.remove_css_class("distraction-active")
        self.distraction_pill.remove_css_class("distraction-idle")
        if is_focus_active:
            self.distraction_pill.set_label("🔕 Distractions Silenced (DND & Chat Muted)")
            self.distraction_pill.add_css_class("distraction-active")
        else:
            if mode == "pomo" and phase in ("short_break", "long_break"):
                self.distraction_pill.set_label("☕ Break Mode (Alerts & Sounds Restored)")
            else:
                self.distraction_pill.set_label("🔔 Alerts & Sounds Active")
            self.distraction_pill.add_css_class("distraction-idle")

        work_m = self.state.get("workSec", 1500) // 60
        break_m = self.state.get("breakSec", 300) // 60
        long_m = self.state.get("longBreakSec", 900) // 60

        def update_btn_style(btn, active):
            btn.remove_css_class("preset-btn-active")
            btn.remove_css_class("preset-btn")
            btn.add_css_class("preset-btn-active" if active else "preset-btn")

        update_btn_style(self.btn_25, phase == "work" and work_m == 25)
        update_btn_style(self.btn_50, phase == "work" and work_m == 50)
        update_btn_style(self.btn_5, phase == "short_break" and break_m == 5)
        update_btn_style(self.btn_15, phase == "long_break" and long_m == 15)

        # Dynamic cycle dots matching daily goal target
        self.update_cycle_dots()

        if active_task:
            self.task_banner_lbl.set_label(f"Focusing on: {active_task.get('text', '')}")
            self.task_banner_icon.set_label("🎯")
        else:
            self.task_banner_lbl.set_label("No active target — Click any task on the right")
            self.task_banner_icon.set_label("💡")

        self.lbl_stat_sessions.set_label(str(today_sessions))
        mins = today_sec // 60
        if mins >= 60:
            hrs = mins // 60
            rm = mins % 60
            self.lbl_stat_time.set_label(f"{hrs}h {rm}m")
        else:
            self.lbl_stat_time.set_label(f"{mins}m")

        if today_sessions >= target and target > 0:
            self.lbl_stat_target.set_label(f"🎉 {today_sessions} / {target}")
            self.lbl3_desc.set_label("GOAL ACHIEVED!")
        else:
            self.lbl_stat_target.set_label(f"{today_sessions} / {target}")
            self.lbl3_desc.set_label("DAILY GOAL")

        self.progress_bar.set_fraction(min(1.0, today_sessions / max(1, target)))

        if not skip_tasks:
            self.render_task_list()

        # Update History view if visible
        if getattr(self, "stack", None) and self.stack.get_visible_child_name() == "history":
            self.render_history_view()

        # Also update floating pip window if open
        if hasattr(self.app, "pip_win") and self.app.pip_win and self.app.pip_win.get_visible():
            self.app.pip_win.update_display(self.state, self.todos)

    def render_task_list(self):
        while True:
            child = self.task_list_box.get_first_child()
            if child is None:
                break
            self.task_list_box.remove(child)

        active_id = self.state.get("activeTaskId")
        today_str = str(date.today())

        active_tasks = []
        finished_today_tasks = []
        other_finished_tasks = []

        for idx, item in enumerate(self.todos):
            if not item.get("done", False):
                active_tasks.append((idx, item))
            elif item.get("completed_date") == today_str:
                finished_today_tasks.append((idx, item))
            else:
                other_finished_tasks.append((idx, item))

        if not self.todos:
            empty_row = Gtk.ListBoxRow()
            empty_lbl = Gtk.Label(label="No tasks yet. Type above to add one!", margin_top=14, margin_bottom=14)
            empty_lbl.add_css_class("dim-label")
            empty_row.set_child(empty_lbl)
            self.task_list_box.append(empty_row)
            return

        # Render Active Tasks
        for idx, item in active_tasks:
            row = Gtk.ListBoxRow()
            row.item_idx = idx
            row.task_id = item.get("id")

            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            box.set_margin_top(5)
            box.set_margin_bottom(5)
            box.set_margin_start(10)
            box.set_margin_end(10)

            is_active = (item.get("id") == active_id)
            if is_active:
                box.add_css_class("task-row-active")

            check = Gtk.CheckButton()
            check.set_active(False)
            check.connect("toggled", self.on_task_check_toggled, idx)
            box.append(check)

            lbl = Gtk.Label(label=item.get("text", ""), hexpand=True, xalign=0)
            lbl.set_ellipsize(Pango.EllipsizeMode.END)
            box.append(lbl)

            spent_sec = item.get("spent_seconds", 0)
            spent_str = self.format_duration_short(spent_sec)
            time_badge = Gtk.Label(label=f"⏱️ {spent_str}")
            time_badge.add_css_class("task-badge-time")
            box.append(time_badge)

            btn_target = Gtk.Button(label="🎯 Active" if is_active else "Focus")
            btn_target.add_css_class("suggested-action" if is_active else "flat")
            btn_target.connect("clicked", self.on_task_focus_clicked, item.get("id"))
            box.append(btn_target)

            btn_del = Gtk.Button(icon_name="user-trash-symbolic")
            btn_del.add_css_class("flat")
            btn_del.connect("clicked", self.on_task_delete_clicked, idx)
            box.append(btn_del)

            row.set_child(box)
            self.task_list_box.append(row)

        # Render Finished Today Section
        if finished_today_tasks:
            header_row = Gtk.ListBoxRow()
            header_row.set_selectable(False)
            header_row.set_activatable(False)
            h_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            h_box.set_margin_top(14)
            h_box.set_margin_bottom(4)
            h_box.set_margin_start(10)
            h_lbl = Gtk.Label(label=f"✓ Finished Today ({len(finished_today_tasks)})", xalign=0)
            h_lbl.add_css_class("heading")
            h_lbl.add_css_class("dim-label")
            h_box.append(h_lbl)
            header_row.set_child(h_box)
            self.task_list_box.append(header_row)

            for idx, item in finished_today_tasks:
                row = Gtk.ListBoxRow()
                row.item_idx = idx
                row.task_id = item.get("id")

                box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
                box.set_margin_top(4)
                box.set_margin_bottom(4)
                box.set_margin_start(10)
                box.set_margin_end(10)

                check = Gtk.CheckButton()
                check.set_active(True)
                check.connect("toggled", self.on_task_check_toggled, idx)
                box.append(check)

                lbl = Gtk.Label(label=item.get("text", ""), hexpand=True, xalign=0)
                lbl.set_ellipsize(Pango.EllipsizeMode.END)
                lbl.add_css_class("finished-task-text")
                box.append(lbl)

                comp_time = item.get("completed_at", "")
                spent_sec = item.get("spent_seconds", 0)
                spent_str = self.format_duration_short(spent_sec)
                fin_info = f"✓ {comp_time} • ⏱️ {spent_str}" if comp_time else f"⏱️ {spent_str}"
                fin_badge = Gtk.Label(label=fin_info)
                fin_badge.add_css_class("task-badge-time")
                box.append(fin_badge)

                btn_del = Gtk.Button(icon_name="user-trash-symbolic")
                btn_del.add_css_class("flat")
                btn_del.connect("clicked", self.on_task_delete_clicked, idx)
                box.append(btn_del)

                row.set_child(box)
                self.task_list_box.append(row)

        # Render Older Completed Tasks
        if other_finished_tasks and not finished_today_tasks:
            header_row = Gtk.ListBoxRow()
            header_row.set_selectable(False)
            header_row.set_activatable(False)
            h_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            h_box.set_margin_top(14)
            h_box.set_margin_bottom(4)
            h_box.set_margin_start(10)
            h_lbl = Gtk.Label(label=f"Completed Earlier ({len(other_finished_tasks)})", xalign=0)
            h_lbl.add_css_class("dim-label")
            h_box.append(h_lbl)
            header_row.set_child(h_box)
            self.task_list_box.append(header_row)

            for idx, item in other_finished_tasks:
                row = Gtk.ListBoxRow()
                row.item_idx = idx
                row.task_id = item.get("id")

                box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
                box.set_margin_top(4)
                box.set_margin_bottom(4)
                box.set_margin_start(10)
                box.set_margin_end(10)

                check = Gtk.CheckButton()
                check.set_active(True)
                check.connect("toggled", self.on_task_check_toggled, idx)
                box.append(check)

                lbl = Gtk.Label(label=item.get("text", ""), hexpand=True, xalign=0)
                lbl.set_ellipsize(Pango.EllipsizeMode.END)
                lbl.add_css_class("finished-task-text")
                box.append(lbl)

                btn_del = Gtk.Button(icon_name="user-trash-symbolic")
                btn_del.add_css_class("flat")
                btn_del.connect("clicked", self.on_task_delete_clicked, idx)
                box.append(btn_del)

                row.set_child(box)
                self.task_list_box.append(row)

    def render_history_view(self):
        while True:
            child = self.history_container.get_first_child()
            if child is None:
                break
            self.history_container.remove(child)

        is_all_time = (getattr(self, "history_scope", "all") == "all")
        today_str = str(date.today())
        target = self.state.get("targetSessions", 8)

        # 1. Summary Cards (4 Metrics)
        summary_grid = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        summary_grid.set_homogeneous(True)

        if is_all_time:
            total_sec = self.get_total_focus_seconds()
            total_sess = self.get_total_sessions_count()
            total_tasks_done = sum(1 for t in self.todos if t.get("done"))

            # Calculate active days from history
            history_dates = set()
            for h in self.state.get("history", []):
                d = h.get("date")
                if not d and h.get("timestamp"):
                    try:
                        d = datetime.fromtimestamp(h["timestamp"]).strftime("%Y-%m-%d")
                    except Exception:
                        pass
                if d:
                    history_dates.add(d)
            if total_sec > 0:
                history_dates.add(today_str)
            active_days_count = max(1, len(history_dates))
            daily_avg_sec = total_sec // active_days_count

            # Card 1: Total Focus Time
            c1 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            c1.add_css_class("glass-card")
            lbl_c1_val = Gtk.Label(label=self.format_duration_short(total_sec), xalign=0)
            lbl_c1_val.add_css_class("history-metric-val")
            lbl_c1_desc = Gtk.Label(label="TOTAL FOCUS TIME", xalign=0)
            lbl_c1_desc.add_css_class("history-metric-lbl")
            c1.append(lbl_c1_val)
            c1.append(lbl_c1_desc)
            summary_grid.append(c1)

            # Card 2: Total Sessions
            c2 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            c2.add_css_class("glass-card")
            lbl_c2_val = Gtk.Label(label=str(total_sess), xalign=0)
            lbl_c2_val.add_css_class("history-metric-val")
            lbl_c2_desc = Gtk.Label(label="TOTAL SESSIONS", xalign=0)
            lbl_c2_desc.add_css_class("history-metric-lbl")
            c2.append(lbl_c2_val)
            c2.append(lbl_c2_desc)
            summary_grid.append(c2)

            # Card 3: Total Finished Tasks
            c3 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            c3.add_css_class("glass-card")
            lbl_c3_val = Gtk.Label(label=str(total_tasks_done), xalign=0)
            lbl_c3_val.add_css_class("history-metric-val")
            lbl_c3_desc = Gtk.Label(label="TASKS FINISHED", xalign=0)
            lbl_c3_desc.add_css_class("history-metric-lbl")
            c3.append(lbl_c3_val)
            c3.append(lbl_c3_desc)
            summary_grid.append(c3)

            # Card 4: Daily Average / Active Days
            c4 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            c4.add_css_class("glass-card")
            lbl_c4_val = Gtk.Label(label=self.format_duration_short(daily_avg_sec), xalign=0)
            lbl_c4_val.add_css_class("history-metric-val")
            lbl_c4_desc = Gtk.Label(label=f"DAILY AVG ({active_days_count}D)", xalign=0)
            lbl_c4_desc.add_css_class("history-metric-lbl")
            c4.append(lbl_c4_val)
            c4.append(lbl_c4_desc)
            summary_grid.append(c4)

        else:
            today_sessions = self.state.get("todaySessions", 0)
            today_sec = self.state.get("todayFocusSeconds", 0)
            finished_today_count = sum(1 for t in self.todos if t.get("done") and t.get("completed_date") == today_str)
            pct = int((today_sessions / max(1, target)) * 100)

            c1 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            c1.add_css_class("glass-card")
            lbl_c1_val = Gtk.Label(label=self.format_duration_short(today_sec), xalign=0)
            lbl_c1_val.add_css_class("history-metric-val")
            lbl_c1_desc = Gtk.Label(label="TODAY'S FOCUS", xalign=0)
            lbl_c1_desc.add_css_class("history-metric-lbl")
            c1.append(lbl_c1_val)
            c1.append(lbl_c1_desc)
            summary_grid.append(c1)

            c2 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            c2.add_css_class("glass-card")
            lbl_c2_val = Gtk.Label(label=str(today_sessions), xalign=0)
            lbl_c2_val.add_css_class("history-metric-val")
            lbl_c2_desc = Gtk.Label(label="TODAY SESSIONS", xalign=0)
            lbl_c2_desc.add_css_class("history-metric-lbl")
            c2.append(lbl_c2_val)
            c2.append(lbl_c2_desc)
            summary_grid.append(c2)

            c3 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            c3.add_css_class("glass-card")
            lbl_c3_val = Gtk.Label(label=str(finished_today_count), xalign=0)
            lbl_c3_val.add_css_class("history-metric-val")
            lbl_c3_desc = Gtk.Label(label="FINISHED TODAY", xalign=0)
            lbl_c3_desc.add_css_class("history-metric-lbl")
            c3.append(lbl_c3_val)
            c3.append(lbl_c3_desc)
            summary_grid.append(c3)

            c4 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            c4.add_css_class("glass-card")
            lbl_c4_val = Gtk.Label(label=f"{pct}%", xalign=0)
            lbl_c4_val.add_css_class("history-metric-val")
            lbl_c4_desc = Gtk.Label(label=f"GOAL ({target})", xalign=0)
            lbl_c4_desc.add_css_class("history-metric-lbl")
            c4.append(lbl_c4_val)
            c4.append(lbl_c4_desc)
            summary_grid.append(c4)

        self.history_container.append(summary_grid)

        # 2. Activity Breakdown by Task
        breakdown_header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        breakdown_header.set_margin_top(12)
        heading_title = "All-Time Activity Breakdown by Task" if is_all_time else "Today's Activity Breakdown by Task"
        lbl_breakdown = Gtk.Label(label=heading_title, hexpand=True, xalign=0)
        lbl_breakdown.add_css_class("heading")
        breakdown_header.append(lbl_breakdown)
        self.history_container.append(breakdown_header)

        task_totals = {}
        if is_all_time:
            for t in self.todos:
                sec = t.get("spent_seconds", 0)
                if sec > 0:
                    task_totals[t.get("text", "Unnamed Task")] = sec
            for h in self.state.get("history", []):
                t_name = h.get("task", "General Focus")
                task_totals[t_name] = max(task_totals.get(t_name, 0), h.get("duration", 0))
        else:
            for t in self.todos:
                sec = t.get("today_seconds", 0)
                if sec <= 0 and t.get("last_date") == today_str:
                    sec = t.get("spent_seconds", 0)
                if sec > 0:
                    task_totals[t.get("text", "Unnamed Task")] = sec
            for h in self.state.get("history", []):
                if h.get("date") == today_str or (h.get("timestamp") and datetime.fromtimestamp(h["timestamp"]).strftime("%Y-%m-%d") == today_str):
                    t_name = h.get("task", "General Focus")
                    task_totals[t_name] = max(task_totals.get(t_name, 0), h.get("duration", 0))

        task_time_list = sorted(task_totals.items(), key=lambda x: x[1], reverse=True)
        total_tracked_sec = sum(x[1] for x in task_time_list)

        if not task_time_list:
            empty_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            empty_box.add_css_class("glass-card")
            empty_box.set_margin_top(4)
            lbl_empty = Gtk.Label(
                label="No task activity recorded yet.\nSelect a task on the left and start focus to see your time breakdown!",
                xalign=0.5,
                justify=Gtk.Justification.CENTER
            )
            lbl_empty.add_css_class("dim-label")
            empty_box.append(lbl_empty)
            self.history_container.append(empty_box)
        else:
            breakdown_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            breakdown_card.add_css_class("glass-card")
            breakdown_card.set_margin_top(4)

            denom = max(1, total_tracked_sec)
            for name, sec in task_time_list:
                row_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)

                top_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
                lbl_name = Gtk.Label(label=name, hexpand=True, xalign=0)
                lbl_name.set_ellipsize(Pango.EllipsizeMode.END)
                top_row.append(lbl_name)

                pct_val = int((sec / denom) * 100)
                dur_str = self.format_duration_short(sec)
                lbl_stat = Gtk.Label(label=f"{dur_str} ({pct_val}%)", xalign=1)
                lbl_stat.add_css_class("dim-label")
                top_row.append(lbl_stat)
                row_box.append(top_row)

                pbar = Gtk.ProgressBar()
                pbar.set_fraction(min(1.0, sec / denom))
                row_box.append(pbar)

                breakdown_card.append(row_box)

            self.history_container.append(breakdown_card)

        # 3. Session Log (Grouped by Date for All-Time)
        log_header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        log_header.set_margin_top(14)
        heading_log = "Full Session History" if is_all_time else "Today's Session Log"
        lbl_log = Gtk.Label(label=heading_log, hexpand=True, xalign=0)
        lbl_log.add_css_class("heading")
        log_header.append(lbl_log)
        self.history_container.append(log_header)

        all_history = self.state.get("history", [])

        if is_all_time:
            grouped_history = {}
            for h in all_history:
                d = h.get("date")
                if not d and h.get("timestamp"):
                    try:
                        d = datetime.fromtimestamp(h["timestamp"]).strftime("%Y-%m-%d")
                    except Exception:
                        d = today_str
                if not d:
                    d = today_str
                grouped_history.setdefault(d, []).append(h)

            sorted_dates = sorted(grouped_history.keys(), reverse=True)

            if not sorted_dates:
                empty_log_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
                empty_log_box.add_css_class("glass-card")
                empty_log_box.set_margin_top(4)
                lbl_log_empty = Gtk.Label(label="Completed sessions will appear here in chronological order.", xalign=0.5)
                lbl_log_empty.add_css_class("dim-label")
                empty_log_box.append(lbl_log_empty)
                self.history_container.append(empty_log_box)
            else:
                for d in sorted_dates:
                    day_sessions = grouped_history[d]
                    tot_day_sec = sum(s.get("duration", 0) for s in day_sessions)
                    tot_day_str = self.format_duration_short(tot_day_sec)

                    date_section = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
                    date_section.set_margin_top(10)
                    date_section.set_margin_bottom(4)

                    date_lbl = Gtk.Label(label=self.format_date_header(d), hexpand=True, xalign=0)
                    date_lbl.add_css_class("heading")
                    date_lbl.add_css_class("dim-label")
                    date_section.append(date_lbl)

                    day_summary_lbl = Gtk.Label(label=f"⏱️ {tot_day_str} ({len(day_sessions)} sessions)", xalign=1)
                    day_summary_lbl.add_css_class("dim-label")
                    date_section.append(day_summary_lbl)

                    self.history_container.append(date_section)

                    day_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
                    for sess in reversed(day_sessions):
                        s_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
                        s_card.add_css_class("glass-card")

                        ts = sess.get("timestamp", 0)
                        time_str = datetime.fromtimestamp(ts).strftime("%H:%M") if ts else "--:--"

                        lbl_time = Gtk.Label(label=time_str)
                        lbl_time.add_css_class("dim-label")
                        s_card.append(lbl_time)

                        task_lbl = Gtk.Label(label=sess.get("task", "General Focus"), hexpand=True, xalign=0)
                        task_lbl.set_ellipsize(Pango.EllipsizeMode.END)
                        s_card.append(task_lbl)

                        dur = sess.get("duration", 1500)
                        dur_str = self.format_duration_short(dur)
                        dur_pill = Gtk.Label(label=f"⏱️ {dur_str}")
                        dur_pill.add_css_class("task-badge-time")
                        s_card.append(dur_pill)

                        status = sess.get("status", "completed")
                        status_lbl = Gtk.Label(label="✓ Finished" if status == "completed" else "⏹️ Ended")
                        if status == "completed":
                            status_lbl.add_css_class("badge-active")
                        else:
                            status_lbl.add_css_class("dim-label")
                        s_card.append(status_lbl)

                        day_box.append(s_card)

                    self.history_container.append(day_box)

        else:
            today_history = []
            for h in all_history:
                d = h.get("date")
                ts = h.get("timestamp")
                if d == today_str:
                    today_history.append(h)
                elif ts:
                    try:
                        if datetime.fromtimestamp(ts).strftime("%Y-%m-%d") == today_str:
                            today_history.append(h)
                    except Exception:
                        pass

            if not today_history:
                empty_log_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
                empty_log_box.add_css_class("glass-card")
                empty_log_box.set_margin_top(4)
                lbl_log_empty = Gtk.Label(label="No sessions recorded yet today.", xalign=0.5)
                lbl_log_empty.add_css_class("dim-label")
                empty_log_box.append(lbl_log_empty)
                self.history_container.append(empty_log_box)
            else:
                log_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
                log_box.set_margin_top(4)

                for sess in reversed(today_history):
                    s_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
                    s_card.add_css_class("glass-card")

                    ts = sess.get("timestamp", 0)
                    time_str = datetime.fromtimestamp(ts).strftime("%H:%M") if ts else "--:--"

                    lbl_time = Gtk.Label(label=time_str)
                    lbl_time.add_css_class("dim-label")
                    s_card.append(lbl_time)

                    task_lbl = Gtk.Label(label=sess.get("task", "General Focus"), hexpand=True, xalign=0)
                    task_lbl.set_ellipsize(Pango.EllipsizeMode.END)
                    s_card.append(task_lbl)

                    dur = sess.get("duration", 1500)
                    dur_str = self.format_duration_short(dur)
                    dur_pill = Gtk.Label(label=f"⏱️ {dur_str}")
                    dur_pill.add_css_class("task-badge-time")
                    s_card.append(dur_pill)

                    status = sess.get("status", "completed")
                    status_lbl = Gtk.Label(label="✓ Finished" if status == "completed" else "⏹️ Ended")
                    if status == "completed":
                        status_lbl.add_css_class("badge-active")
                    else:
                        status_lbl.add_css_class("dim-label")
                    s_card.append(status_lbl)

                    log_box.append(s_card)

                self.history_container.append(log_box)

    # ── Interactive Handlers ──────────────────────────────────────────────────
    def on_timer_clicked(self):
        was_running = self.state.get("running", False)
        new_running = not was_running
        self.state["running"] = new_running

        is_focus = (self.state.get("mode") == "pomo" and new_running and self.state.get("phase") == "work")
        self.distraction_mgr.set_focus_active(is_focus)

        self.save_state()
        self.render_all(skip_tasks=True)
        status = "Started" if new_running else "Paused"
        self.show_toast(f"Timer {status}")

    def on_timer_scrolled(self, delta):
        if self.state.get("mode") == "stop":
            return
        phase = self.state.get("phase", "work")
        if phase == "work":
            curr_min = self.state.get("workSec", 1500) // 60
            new_min = max(1, min(180, curr_min + delta))
            self.state["workSec"] = new_min * 60
            if not self.state.get("running", False):
                self.state["remaining"] = self.state["workSec"]
            msg = f"Focus time: {new_min} min"
        elif phase == "short_break":
            curr_min = self.state.get("breakSec", 300) // 60
            new_min = max(1, min(60, curr_min + delta))
            self.state["breakSec"] = new_min * 60
            if not self.state.get("running", False):
                self.state["remaining"] = self.state["breakSec"]
            msg = f"Short break: {new_min} min"
        else:
            curr_min = self.state.get("longBreakSec", 900) // 60
            new_min = max(5, min(90, curr_min + delta))
            self.state["longBreakSec"] = new_min * 60
            if not self.state.get("running", False):
                self.state["remaining"] = self.state["longBreakSec"]
            msg = f"Long break: {new_min} min"

        self.save_state()
        self.render_all(skip_tasks=True)
        self.debounce_toast(msg, delay_ms=150)

    def on_task_row_activated(self, listbox, row):
        task_id = getattr(row, "task_id", None)
        if task_id:
            if self.state.get("activeTaskId") == task_id:
                self.state["activeTaskId"] = None
            else:
                self.state["activeTaskId"] = task_id
            self.save_state()
            self.render_all(skip_tasks=False)

    def on_second_tick(self):
        # Check if external source (e.g. TimerPane in Carbon Shell) modified the state
        try:
            read_path = get_read_path("carbon-pomodoro.json")
            if os.path.exists(read_path):
                mtime = os.path.getmtime(read_path)
                if mtime > getattr(self, "last_saved_mtime", 0.0) + 0.1:
                    with open(read_path, "r", encoding="utf-8") as f:
                        external = json.load(f)
                    self.last_saved_mtime = mtime
                    self.state.update(external)
                    self.render_all(skip_tasks=True)
        except Exception:
            pass

        # Sync distraction manager with current focus state
        is_focus_active = (self.state.get("mode") == "pomo" and self.state.get("running", False) and self.state.get("phase") == "work")
        self.distraction_mgr.set_focus_active(is_focus_active)

        if not self.state.get("running", False):
            return True

        mode = self.state.get("mode", "pomo")
        if mode == "stop":
            self.state["elapsed"] = self.state.get("elapsed", 0) + 1
        else:
            rem = self.state.get("remaining", self.state.get("workSec", 1500)) - 1
            if rem <= 0:
                self.on_phase_finished()
            else:
                self.state["remaining"] = rem
                if self.state.get("phase") == "work":
                    self.state["todayFocusSeconds"] = self.state.get("todayFocusSeconds", 0) + 1
                    self.state["totalFocusSeconds"] = self.state.get("totalFocusSeconds", 0) + 1

                    # Per-task focus time tracking
                    active_id = self.state.get("activeTaskId")
                    if active_id is not None:
                        active_task = next((t for t in self.todos if t.get("id") == active_id), None)
                        if active_task is not None:
                            today_str = str(date.today())
                            active_task["spent_seconds"] = active_task.get("spent_seconds", 0) + 1
                            if active_task.get("last_date") == today_str:
                                active_task["today_seconds"] = active_task.get("today_seconds", 0) + 1
                            else:
                                active_task["last_date"] = today_str
                                active_task["today_seconds"] = 1

                            self._todos_save_counter = getattr(self, "_todos_save_counter", 0) + 1
                            if self._todos_save_counter >= 5:
                                self._todos_save_counter = 0
                                self.save_todos()

        self.save_state()
        self.render_all(skip_tasks=True)
        return True

    def on_phase_finished(self):
        phase = self.state.get("phase", "work")
        cycles = self.state.get("cycles", 0)
        today_sessions = self.state.get("todaySessions", 0)
        total_sessions = self.state.get("totalSessions", 0)

        # Stop timer so it does not loop automatically
        self.state["running"] = False
        self.distraction_mgr.set_focus_active(False)

        if phase == "work":
            cycles += 1
            today_sessions += 1
            total_sessions += 1
            self.state["cycles"] = cycles
            self.state["todaySessions"] = today_sessions
            self.state["totalSessions"] = total_sessions

            active_id = self.state.get("activeTaskId")
            active_task = next((t for t in self.todos if t.get("id") == active_id), None)
            task_name = active_task.get("text") if active_task else "General Focus"

            self.state.setdefault("history", []).append({
                "timestamp": int(time.time()),
                "task": task_name,
                "duration": self.state.get("workSec", 1500),
                "status": "completed",
                "date": str(date.today())
            })

            # Long break interval
            long_break_int = self.state.get("longBreakInterval", 4)
            if cycles % long_break_int == 0:
                self.state["phase"] = "long_break"
                self.state["remaining"] = self.state.get("longBreakSec", 900)
                msg = f"Pomodoro session {today_sessions} complete! Take a well-deserved 15-minute long break."
            else:
                self.state["phase"] = "short_break"
                self.state["remaining"] = self.state.get("breakSec", 300)
                msg = f"Pomodoro session {today_sessions} complete! Time for a 5-minute break."

            # Play gentle break notification sound ONCE
            play_sound("complete")

            subprocess.run([
                "notify-send", "-a", "Carbon Focus",
                "☕ Break Period Ready", msg
            ], check=False)
            self.show_toast("☕ Break Period Ready! (Sounds & Alerts Restored)")
        else:
            # Break just completed -> FOCUS PERIOD READY!
            self.state["phase"] = "work"
            self.state["remaining"] = self.state.get("workSec", 1500)

            # Play gentle focus notification sound ONCE
            play_sound("bell")

            subprocess.run([
                "notify-send", "-a", "Carbon Focus",
                "⚡ Focus Period Ready", "Break finished! Ready to concentrate on your next session?"
            ], check=False)
            self.show_toast("⚡ Focus Period Ready!")

        self.save_todos()

    def on_start_pause_clicked(self, btn):
        was_running = self.state.get("running", False)
        new_running = not was_running
        self.state["running"] = new_running

        is_focus = (self.state.get("mode") == "pomo" and new_running and self.state.get("phase") == "work")
        self.distraction_mgr.set_focus_active(is_focus)

        self.save_state()
        self.render_all(skip_tasks=True)
        status = "Started" if new_running else "Paused"
        self.show_toast(f"Timer {status}")

    def on_reset_clicked(self, btn):
        self.state["running"] = False
        self.distraction_mgr.set_focus_active(False)
        mode = self.state.get("mode", "pomo")
        if mode == "stop":
            self.state["elapsed"] = 0
        else:
            self.state["phase"] = "work"
            self.state["remaining"] = self.state.get("workSec", 1500)
        self.save_state()
        self.render_all(skip_tasks=True)
        self.show_toast("Timer Reset")

    def on_end_session_clicked(self, btn):
        mode = self.state.get("mode", "pomo")
        phase = self.state.get("phase", "work")

        if mode == "pomo":
            if phase == "work":
                tot = self.state.get("workSec", 1500)
                rem = self.state.get("remaining", tot)
                elapsed = max(0, tot - rem)
                if elapsed >= 30:
                    active_id = self.state.get("activeTaskId")
                    active_task = next((t for t in self.todos if t.get("id") == active_id), None)
                    task_name = active_task.get("text") if active_task else "General Focus"

                    self.state.setdefault("history", []).append({
                        "timestamp": int(time.time()),
                        "task": task_name,
                        "duration": elapsed,
                        "status": "ended_early",
                        "date": str(date.today())
                    })
            self.state["running"] = False
            self.state["phase"] = "work"
            self.state["remaining"] = self.state.get("workSec", 1500)
        else:
            self.state["running"] = False
            self.state["elapsed"] = 0

        self.distraction_mgr.set_focus_active(False)
        self.save_state()
        self.save_todos()
        self.render_all(skip_tasks=False)
        self.show_toast("Focus session ended • Distractions unmuted")

    def on_skip_clicked(self, btn):
        mode = self.state.get("mode", "pomo")
        if mode == "pomo":
            self.on_phase_finished()
            self.save_state()
            self.render_all(skip_tasks=False)

    def on_mode_toggled(self, btn, target_mode):
        if not btn.get_active():
            return
        if self.state.get("mode") == target_mode:
            return
        self.state["mode"] = target_mode
        self.state["running"] = False
        self.distraction_mgr.set_focus_active(False)
        self.save_state()
        self.render_all(skip_tasks=True)
        self.show_toast(f"Switched to {target_mode.capitalize()} mode")

    def on_set_work_min(self, btn, mins):
        self.state["workSec"] = mins * 60
        self.state["phase"] = "work"
        if not self.state.get("running", False):
            self.state["remaining"] = self.state["workSec"]
        self.save_state()
        self.render_all(skip_tasks=True)
        self.show_toast(f"Focus set to {mins} min")

    def on_set_break_min(self, btn, mins):
        self.state["breakSec"] = mins * 60
        self.state["phase"] = "short_break"
        if not self.state.get("running", False):
            self.state["remaining"] = self.state["breakSec"]
        self.distraction_mgr.set_focus_active(False)
        self.save_state()
        self.render_all(skip_tasks=True)
        self.show_toast(f"Short break set to {mins} min")

    def on_set_long_break_min(self, btn, mins):
        self.state["longBreakSec"] = mins * 60
        self.state["phase"] = "long_break"
        if not self.state.get("running", False):
            self.state["remaining"] = self.state["longBreakSec"]
        self.distraction_mgr.set_focus_active(False)
        self.save_state()
        self.render_all(skip_tasks=True)
        self.show_toast(f"Long break set to {mins} min")

    def on_add_task_entered(self, widget):
        txt = self.task_entry.get_text().strip()
        if not txt:
            return
        new_task = {
            "id": int(time.time() * 1000),
            "text": txt,
            "done": False,
            "spent_seconds": 0,
            "today_seconds": 0,
            "last_date": str(date.today())
        }
        self.todos.append(new_task)
        self.save_todos()
        self.task_entry.set_text("")
        if self.state.get("activeTaskId") is None:
            self.state["activeTaskId"] = new_task["id"]
            self.save_state()
        self.render_all(skip_tasks=False)
        self.show_toast(f"Task added: {txt[:20]}")

    def on_task_check_toggled(self, check, idx):
        if 0 <= idx < len(self.todos):
            is_done = check.get_active()
            self.todos[idx]["done"] = is_done
            if is_done:
                self.todos[idx]["completed_at"] = datetime.now().strftime("%H:%M")
                self.todos[idx]["completed_date"] = str(date.today())
                if self.state.get("activeTaskId") == self.todos[idx].get("id"):
                    self.state["activeTaskId"] = None
                    self.save_state()
                play_sound("complete")
                self.show_toast("Task completed! 🎉")
            else:
                self.todos[idx].pop("completed_at", None)
                self.todos[idx].pop("completed_date", None)
            self.save_todos()
            self.render_all(skip_tasks=False)

    def on_task_focus_clicked(self, btn, task_id):
        if self.state.get("activeTaskId") == task_id:
            self.state["activeTaskId"] = None
            self.show_toast("Focus target cleared")
        else:
            self.state["activeTaskId"] = task_id
            active_task = next((t for t in self.todos if t.get("id") == task_id), None)
            if active_task:
                self.show_toast(f"Focus target: {active_task.get('text', '')[:20]}")
        self.save_state()
        self.render_all(skip_tasks=False)

    def on_task_delete_clicked(self, btn, idx):
        if 0 <= idx < len(self.todos):
            deleted = self.todos.pop(idx)
            if self.state.get("activeTaskId") == deleted.get("id"):
                self.state["activeTaskId"] = None
                self.save_state()
            self.save_todos()
            self.render_all(skip_tasks=False)
            self.show_toast("Task removed")


# ── Application Main Entrypoint ──────────────────────────────────────────────
class CarbonPomodoroApp(Adw.Application):
    def __init__(self):
        super().__init__(
            application_id="org.carbon.pomodoro",
            flags=Gio.ApplicationFlags.DEFAULT_FLAGS
        )
        self.win = None
        self.pip_win = None
        self._load_mtime = os.path.getmtime(os.path.abspath(__file__)) if os.path.exists(os.path.abspath(__file__)) else 0
        self.connect("startup", self.on_startup)
        self.connect("activate", self.on_activate)

    def on_startup(self, app):
        self.hold()

    def on_activate(self, app):
        # Auto-reload if the script file was updated on disk since process launch
        try:
            cur_mtime = os.path.getmtime(os.path.abspath(__file__))
            if cur_mtime > getattr(self, "_load_mtime", 0) + 0.1:
                distraction_mgr.set_focus_active(False)
                self.release()
                os.execv(sys.executable, [sys.executable, os.path.abspath(__file__)] + sys.argv[1:])
                return
        except Exception:
            pass

        if self.pip_win and self.pip_win.get_visible():
            self.pip_win.hide()

        if not self.win:
            self.win = PomodoroWindow(app)

        self.win.reload_state_from_disk()
        self.win.set_visible(True)
        self.win.present()
        self.win.render_all(skip_tasks=False)

        try:
            subprocess.Popen(
                ["hyprctl", "dispatch", "focuswindow", "class:org.carbon.pomodoro"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        except Exception:
            pass

    def show_pip_window(self):
        if self.win:
            self.win.set_visible(False)
        if not self.pip_win:
            self.pip_win = FloatingPipWindow(self)
        if self.win:
            self.pip_win.update_display(self.win.state, self.win.todos)
        self.pip_win.set_visible(True)
        self.pip_win.present()

    def restore_main_window(self):
        if self.pip_win:
            self.pip_win.hide()
        if not self.win:
            self.win = PomodoroWindow(self)
        self.win.set_visible(True)
        self.win.present()
        self.win.render_all(skip_tasks=False)
        try:
            subprocess.Popen(
                ["hyprctl", "dispatch", "focuswindow", "class:org.carbon.pomodoro"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        except Exception:
            pass


def main():
    app = CarbonPomodoroApp()
    return app.run([sys.argv[0]])


if __name__ == "__main__":
    sys.exit(main())
