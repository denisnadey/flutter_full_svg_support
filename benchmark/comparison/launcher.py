#!/usr/bin/env python3
"""
Side-by-side comparison launcher: Flutter macOS release vs Chrome native.

Architecture
------------
- Flutter app runs as its own native macOS process (left half of screen).
  Its CALayer is composited by the system the same way it would be in a
  shipped binary — no embedding, no proxying, no capture.
- Chrome runs as a separate native process in --app mode (right half).
  Its Blink renderer composites independently. The SVG is loaded inside
  an <iframe> so the document is treated as a real standalone SVG.
- A tiny stdlib http.server in this script serves the benchmarks/ dir so
  Chrome can fetch sibling files (e.g. ../assets/stress/...).
- AppleScript positions the Flutter window after launch.
- Window positioning happens once at startup. After that, neither process
  knows the other exists. There is no IPC, no compositor sharing, no
  GPU read-back — therefore the comparison harness adds zero overhead to
  the measurement.

Why two windows instead of one composited surface?
--------------------------------------------------
A "single-window" solution (Quartz Display Stream → composited NSView,
or a Metal layer per app) would force at least one extra GPU read-back
per frame. For the Galactic Storm asset that read-back alone could cost
2-3 ms/frame on integrated GPUs and bias the very measurement we are
trying to take. Two native windows eliminate this category of error
entirely. The only price is that both windows live in their own OS
window chrome — a fair trade for measurement integrity.

Usage
-----
    python3 launcher.py                  # build if missing, then launch both
    python3 launcher.py --rebuild        # force a fresh release build
    python3 launcher.py --no-build       # skip build entirely
    python3 launcher.py --flutter-only   # left side only
    python3 launcher.py --chrome-only    # right side only
"""

from __future__ import annotations

import argparse
import http.server
import os
import shutil
import socketserver
import subprocess
import sys
import threading
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[2]
BENCHMARKS = REPO_ROOT / "benchmarks"
BENCHMARK_APP = BENCHMARKS / "benchmark_app"
COMPARISON = BENCHMARKS / "comparison"
FVM_FLUTTER = REPO_ROOT / ".fvm" / "flutter_sdk" / "bin" / "flutter"

# ---------------------------------------------------------------------------
# Console helpers
# ---------------------------------------------------------------------------

def _info(msg: str) -> None:
    print(f"[launcher] {msg}", flush=True)


def _die(msg: str, code: int = 1) -> None:
    print(f"[launcher] ERROR: {msg}", file=sys.stderr, flush=True)
    sys.exit(code)


# ---------------------------------------------------------------------------
# macOS window helpers
# ---------------------------------------------------------------------------

def _osascript(script: str) -> str:
    """Run an AppleScript snippet, return stdout."""
    res = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
        check=False,
    )
    return res.stdout.strip()


def get_screen_size() -> tuple[int, int]:
    """Return (width, height) of the primary display in points."""
    out = _osascript(
        'tell application "Finder" to get bounds of window of desktop'
    )
    # Output: "0, 0, 1920, 1080"
    try:
        parts = [int(p.strip()) for p in out.split(",")]
        return parts[2], parts[3]
    except Exception:
        _info(f"could not parse screen bounds ({out!r}), defaulting to 1440x900")
        return 1440, 900


def position_window_by_process(process_name: str, x: int, y: int, w: int, h: int) -> None:
    """Move + resize the front window of `process_name` via System Events."""
    script = f'''
    tell application "System Events"
        try
            tell process "{process_name}"
                set frontmost to true
                if (count of windows) > 0 then
                    set position of window 1 to {{{x}, {y}}}
                    set size of window 1 to {{{w}, {h}}}
                end if
            end tell
        end try
    end tell
    '''
    _osascript(script)


# ---------------------------------------------------------------------------
# Flutter build / discovery
# ---------------------------------------------------------------------------

def _find_flutter() -> Path:
    if FVM_FLUTTER.exists():
        return FVM_FLUTTER
    sys_flutter = shutil.which("flutter")
    if sys_flutter:
        return Path(sys_flutter)
    _die("Flutter SDK not found. Expected .fvm/flutter_sdk or `flutter` on PATH.")
    raise SystemExit  # appease type checker


def ensure_macos_platform(flutter: Path) -> None:
    macos_dir = BENCHMARK_APP / "macos"
    if macos_dir.exists():
        return
    _info("Adding macOS platform to benchmark_app (one-time)...")
    subprocess.run(
        [str(flutter), "create", "--platforms=macos", "."],
        cwd=BENCHMARK_APP,
        check=True,
    )


def build_flutter_release(flutter: Path) -> None:
    _info("Running `flutter pub get`...")
    subprocess.run([str(flutter), "pub", "get"], cwd=BENCHMARK_APP, check=True)
    _info("Building Flutter macOS release (this may take a minute)...")
    subprocess.run(
        [str(flutter), "build", "macos", "--release"],
        cwd=BENCHMARK_APP,
        check=True,
    )


def find_built_app() -> Path | None:
    release_dir = BENCHMARK_APP / "build" / "macos" / "Build" / "Products" / "Release"
    if not release_dir.exists():
        return None
    apps = list(release_dir.glob("*.app"))
    return apps[0] if apps else None


# ---------------------------------------------------------------------------
# Local HTTP server (for Chrome-side static files)
# ---------------------------------------------------------------------------

class _SilentHandler(http.server.SimpleHTTPRequestHandler):
    """Quiet variant — request logs would otherwise spam the launcher console."""

    def log_message(self, format: str, *args) -> None:  # noqa: A002 (shadow ok)
        pass


def start_http_server(serve_dir: Path) -> tuple[str, socketserver.TCPServer]:
    """Start a daemonised SimpleHTTPServer on a free port, rooted at `serve_dir`."""

    class _Server(socketserver.ThreadingTCPServer):
        allow_reuse_address = True

    cwd_lock = threading.Lock()

    def factory(*args, **kwargs):
        # SimpleHTTPRequestHandler resolves paths relative to its own cwd
        # at request time. We bind it to `serve_dir` here.
        return _SilentHandler(*args, directory=str(serve_dir), **kwargs)

    server = _Server(("127.0.0.1", 0), factory)
    port = server.server_address[1]
    threading.Thread(target=server.serve_forever, daemon=True).start()
    del cwd_lock  # not used (handler takes `directory=`)
    return f"http://127.0.0.1:{port}", server


# ---------------------------------------------------------------------------
# Chrome launch
# ---------------------------------------------------------------------------

CHROME_CANDIDATES = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
]


def find_chromium() -> Path | None:
    for p in CHROME_CANDIDATES:
        if Path(p).exists():
            return Path(p)
    return None


def launch_chrome(chrome_bin: Path, url: str, x: int, y: int, w: int, h: int) -> subprocess.Popen:
    """Launch Chromium-family browser in --app mode at exact bounds."""
    profile_dir = Path("/tmp/full-svg-flutter-comparison-profile")
    profile_dir.mkdir(exist_ok=True)
    args = [
        str(chrome_bin),
        f"--app={url}",
        f"--window-position={x},{y}",
        f"--window-size={w},{h}",
        f"--user-data-dir={profile_dir}",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-features=Translate,InterestFeed",
        "--disable-extensions",
        "--disable-background-networking",
        # We want vsync-paced rAF; do NOT pass --disable-gpu-vsync.
    ]
    _info(f"Launching Chromium: {chrome_bin.name}")
    return subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# ---------------------------------------------------------------------------
# Flutter launch + position
# ---------------------------------------------------------------------------

def launch_flutter_app(app_path: Path, x: int, y: int, w: int, h: int) -> None:
    """Open the .app bundle and position its window via AppleScript."""
    _info(f"Launching {app_path.name}...")
    # `-n` forces a new instance even if it's already running.
    subprocess.run(["open", "-na", str(app_path)], check=True)

    # Wait for the window to appear before positioning. Poll up to 6 s.
    process_name = app_path.stem
    deadline = time.time() + 6
    while time.time() < deadline:
        n = _osascript(
            f'tell application "System Events" to tell process "{process_name}" '
            f'to count of windows'
        )
        if n.isdigit() and int(n) > 0:
            break
        time.sleep(0.2)

    position_window_by_process(process_name, x, y, w, h)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Side-by-side comparison launcher (Flutter macOS vs Chrome).",
    )
    parser.add_argument("--rebuild", action="store_true", help="Force fresh Flutter release build")
    parser.add_argument("--no-build", action="store_true", help="Skip build even if .app is missing")
    parser.add_argument("--flutter-only", action="store_true", help="Launch only the Flutter side")
    parser.add_argument("--chrome-only", action="store_true", help="Launch only the Chrome side")
    parser.add_argument("--menubar-offset", type=int, default=28, help="Pixels reserved for menu bar")
    args = parser.parse_args()

    if sys.platform != "darwin":
        _die("This launcher is macOS-only.")

    flutter = _find_flutter()

    # ------------------------------------------------------------------ build
    app_path: Path | None = None
    if not args.chrome_only:
        ensure_macos_platform(flutter)
        app_path = find_built_app()
        needs_build = args.rebuild or app_path is None
        if needs_build and args.no_build:
            _die("No built .app and --no-build was passed. Run without --no-build first.")
        if needs_build:
            build_flutter_release(flutter)
            app_path = find_built_app()
        if app_path is None:
            _die("Build appeared to succeed but no .app bundle was found.")

    # ----------------------------------------------------------------- server
    base_url, server = start_http_server(BENCHMARKS)
    comparison_url = f"{base_url}/comparison/comparison.html"
    _info(f"HTTP server: {base_url} (serving {BENCHMARKS})")

    # ------------------------------------------------------------- positioning
    sw, sh = get_screen_size()
    _info(f"Screen: {sw}x{sh}")
    half = sw // 2
    top = args.menubar_offset
    height = sh - top
    flutter_bounds = (0, top, half, height)
    chrome_bounds = (half, top, half, height)

    # --------------------------------------------------------------- launches
    if not args.chrome_only and app_path is not None:
        launch_flutter_app(app_path, *flutter_bounds)

    chrome_proc: subprocess.Popen | None = None
    if not args.flutter_only:
        chrome_bin = find_chromium()
        if chrome_bin is None:
            _die("No Chromium-family browser found. Install Google Chrome or Chromium.")
        assert chrome_bin is not None
        chrome_proc = launch_chrome(chrome_bin, comparison_url, *chrome_bounds)

    # ----------------------------------------------------------------- banner
    print()
    print("=" * 64)
    if not args.chrome_only:
        print(f"  Flutter (release):  left half   {flutter_bounds[2]}x{flutter_bounds[3]} @ {flutter_bounds[0]},{flutter_bounds[1]}")
    if not args.flutter_only:
        print(f"  Chrome  (--app   ):  right half  {chrome_bounds[2]}x{chrome_bounds[3]} @ {chrome_bounds[0]},{chrome_bounds[1]}")
        print(f"  URL:                {comparison_url}")
    print()
    print("  Both processes are native — no proxy, no cast, zero harness overhead.")
    print("  Press Ctrl+C in this terminal to stop the HTTP server.")
    print("=" * 64)
    print()

    # ----------------------------------------------------------------- wait
    try:
        while True:
            if chrome_proc is not None and chrome_proc.poll() is not None:
                _info("Chrome closed; shutting down server.")
                break
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        _info("Stopping HTTP server.")
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
