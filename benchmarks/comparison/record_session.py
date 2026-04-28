#!/usr/bin/env python3
"""
3-minute side-by-side recording session for the Galactic Storm mega stress
test. Produces ready-to-share GIFs, full-length MP4s, raw JSONL telemetry,
an aggregated summary.json and a markdown report.

╔════════════════════════════════════════════════════════════════════════╗
║  IMPORTANT — RUN THIS IN TERMINAL.APP, NOT INSIDE AN IDE.              ║
║                                                                        ║
║  macOS gates AVFoundation screen capture on the *parent* process's     ║
║  Screen Recording permission. IDE-embedded terminals (Claude Code,     ║
║  VS Code, etc.) usually do NOT have that permission, so ffmpeg will    ║
║  silently produce a black frame stream.                                ║
║                                                                        ║
║  Open the system Terminal.app and run:                                 ║
║                                                                        ║
║    cd /path/to/flutter_full_svg_support                                ║
║    make -C benchmarks record                                           ║
║                                                                        ║
║  First run will prompt for Screen Recording permission — grant it to   ║
║  Terminal.app in System Settings → Privacy & Security → Screen         ║
║  Recording, then re-run.                                               ║
╚════════════════════════════════════════════════════════════════════════╝

Architecture:
  1. Custom HTTP server: serves benchmarks/* AND accepts POST /metrics/*
  2. Flutter is rebuilt with `--dart-define=BENCHMARK_TELEMETRY=...` and
     `--dart-define=BENCHMARK_AUTOROUTE=/mega_stress` so it lands directly
     on the Galactic Storm screen and POSTs frame timings every 5 s.
  3. Chrome is launched in --app mode at comparison.html?telemetry=...
     so its rAF tick deltas are POSTed via fetch on the same cadence.
  4. ffmpeg avfoundation captures the entire screen for the duration.
  5. Both apps are killed; ffmpeg finishes; we post-process:
        - split video into flutter.mp4 / chrome.mp4 (left / right halves)
        - generate highlight GIFs (configurable clip / fps / width)
        - aggregate the JSONL telemetry into summary.json
        - write report.md with a side-by-side metrics table

Output:
  benchmarks/recordings/<timestamp>/
    flutter.mp4              - full duration capture, left half
    chrome.mp4               - full duration capture, right half
    flutter_<N>s.gif         - highlight GIF for README
    chrome_<N>s.gif          - highlight GIF for README
    flutter_metrics.jsonl    - one POST batch per line
    chrome_metrics.jsonl     - one POST batch per line
    summary.json             - aggregated stats (avg/p50/p90/p99/max + jank)
    report.md                - markdown report with embedded GIF refs

Usage:
  python3 record_session.py                        # 180s, 30s GIFs at 15fps
  python3 record_session.py --duration 60          # 60s session
  python3 record_session.py --gif-clip 20          # 20s highlight GIFs
  python3 record_session.py --no-build             # reuse existing build
  python3 record_session.py --skip-permission-check
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import hashlib
import json
import os
import re
import shutil
import signal
import socket
import statistics
import subprocess
import sys
import threading
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, quote

# Reuse helpers from launcher.py that live in the same directory.
sys.path.insert(0, str(Path(__file__).parent))
from launcher import (  # noqa: E402
    REPO_ROOT,
    BENCHMARKS,
    BENCHMARK_APP,
    COMPARISON,
    FVM_FLUTTER,
    _info,
    _die,
    _osascript,
    get_screen_size,
    position_window_by_process,
    ensure_macos_platform,
    find_built_app,
    find_chromium,
)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

RECORDINGS = BENCHMARKS / "recordings"
TELEMETRY_PORT = 18765  # Fixed so the dart-defined URL matches the live server.
SCREENCAPTURE = Path("/usr/sbin/screencapture")


# ---------------------------------------------------------------------------
# TCC-disclaiming spawn (macOS only)
# ---------------------------------------------------------------------------
#
# When we launch the Swift recorder as a normal child of Python, macOS TCC
# walks up the process chain to find the "responsible process" — which lands
# on /opt/homebrew/.../python3.14, often without Screen Recording permission.
# `CGRequestScreenCaptureAccess()` returns True because TCC checks the
# binary's own grants, but AVCaptureSession does an additional check that
# resolves to the responsible process and fails ("Cannot Record", 0-byte file).
#
# Apple's libSystem exposes `responsibility_spawnattrs_setdisclaim()` (used
# internally by /usr/bin/open and Spotlight) which tells the kernel that the
# spawned child should be its own responsible process — TCC then evaluates
# permissions strictly against the child's binary identity, ignoring the
# parent. This matches what the user experiences when running the binary
# from a fresh terminal directly.

_LIBSYSTEM: ctypes.CDLL | None = None


def _libsystem() -> ctypes.CDLL:
    global _LIBSYSTEM
    if _LIBSYSTEM is not None:
        return _LIBSYSTEM
    path = ctypes.util.find_library("System") or "libSystem.dylib"
    lib = ctypes.CDLL(path, use_errno=True)

    lib.posix_spawn.argtypes = [
        ctypes.POINTER(ctypes.c_int),     # pid_t *
        ctypes.c_char_p,                   # path
        ctypes.c_void_p,                   # file_actions_t *  (NULL = inherit)
        ctypes.POINTER(ctypes.c_void_p),   # spawnattr_t *
        ctypes.POINTER(ctypes.c_char_p),   # argv
        ctypes.POINTER(ctypes.c_char_p),   # envp
    ]
    lib.posix_spawn.restype = ctypes.c_int

    lib.posix_spawnattr_init.argtypes = [ctypes.POINTER(ctypes.c_void_p)]
    lib.posix_spawnattr_init.restype = ctypes.c_int
    lib.posix_spawnattr_destroy.argtypes = [ctypes.POINTER(ctypes.c_void_p)]
    lib.posix_spawnattr_destroy.restype = ctypes.c_int

    # Private SPI — present on every macOS since at least 10.14.
    lib.responsibility_spawnattrs_setdisclaim.argtypes = [
        ctypes.POINTER(ctypes.c_void_p),
        ctypes.c_int,
    ]
    lib.responsibility_spawnattrs_setdisclaim.restype = ctypes.c_int

    _LIBSYSTEM = lib
    return lib


def spawn_disclaimed(executable: str, args: list[str]) -> int:
    """posix_spawn the executable with `responsibility_spawnattrs_setdisclaim(1)`.

    The child inherits stdin/stdout/stderr from the parent (NULL file_actions),
    so its messages stream directly to our terminal. Returns the child PID;
    caller is responsible for `os.waitpid()`.
    """
    lib = _libsystem()
    attrs = ctypes.c_void_p(0)

    rc = lib.posix_spawnattr_init(ctypes.byref(attrs))
    if rc != 0:
        raise OSError(rc, f"posix_spawnattr_init failed: {os.strerror(rc)}")
    try:
        rc = lib.responsibility_spawnattrs_setdisclaim(ctypes.byref(attrs), 1)
        if rc != 0:
            raise OSError(rc,
                f"responsibility_spawnattrs_setdisclaim failed: {os.strerror(rc)}")

        full_argv = [executable] + args
        argv = (ctypes.c_char_p * (len(full_argv) + 1))()
        for i, a in enumerate(full_argv):
            argv[i] = a.encode("utf-8")
        argv[len(full_argv)] = None

        env_items = list(os.environ.items())
        envp = (ctypes.c_char_p * (len(env_items) + 1))()
        for i, (k, v) in enumerate(env_items):
            envp[i] = f"{k}={v}".encode("utf-8")
        envp[len(env_items)] = None

        pid = ctypes.c_int(0)
        rc = lib.posix_spawn(
            ctypes.byref(pid),
            executable.encode("utf-8"),
            None,                       # NULL → child inherits stdio
            ctypes.byref(attrs),
            argv,
            envp,
        )
        if rc != 0:
            raise OSError(rc, f"posix_spawn failed: {os.strerror(rc)}")
        return pid.value
    finally:
        lib.posix_spawnattr_destroy(ctypes.byref(attrs))


def waitpid_full(pid: int, timeout: float | None = None) -> int:
    """Wait for child PID, return exit code (or -1 if killed/timeout)."""
    if timeout is None:
        _, status = os.waitpid(pid, 0)
    else:
        deadline = time.time() + timeout
        while True:
            res = os.waitpid(pid, os.WNOHANG)
            if res != (0, 0):
                _, status = res
                break
            if time.time() > deadline:
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                return -1
            time.sleep(0.05)
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    return -1

# Swift recorder cache. We package the compiled binary into a .app bundle with:
#   • a stable CFBundleIdentifier (com.benchmarks.svg.recorder)
#   • a designated requirement pinned to the identifier, not the CDHash
#   • content-hash-based change detection (not mtime — git pull changes mtime)
# Together these ensure TCC tracks the grant by Bundle ID across rebuilds and
# does NOT create a new entry (which forces the user to remove the old one).
SWIFT_RECORDER_SRC = COMPARISON / "recorder.swift"
RECORDER_APP_DIR = COMPARISON / ".bin" / "recorder.app"
RECORDER_APP_BIN = RECORDER_APP_DIR / "Contents" / "MacOS" / "recorder"
RECORDER_APP_PLIST = RECORDER_APP_DIR / "Contents" / "Info.plist"
# Stores the SHA-256 of recorder.swift at the time the binary was last compiled.
# We compare content hash (not mtime) so that `git pull` — which updates mtime
# without changing content — does NOT trigger a spurious recompile and a new
# TCC code identity.
RECORDER_HASH_FILE = RECORDER_APP_DIR / "Contents" / "MacOS" / ".swift_src_hash"
RECORDER_BUNDLE_ID = "com.benchmarks.svg.recorder"

# Legacy bare-binary path — still used as fallback to find leftover recorder
# from earlier versions of this script and warn the user it is stale.
SWIFT_RECORDER_BIN = RECORDER_APP_BIN  # back-compat alias used by error messages

INFO_PLIST_TEMPLATE = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>recorder</string>
    <key>CFBundleIdentifier</key>
    <string>{bundle_id}</string>
    <key>CFBundleName</key>
    <string>recorder</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Records the screen for the SVG benchmark comparison harness.</string>
</dict>
</plist>
"""

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Screen Recording permission helpers (macOS)
# ---------------------------------------------------------------------------

# Map of substrings → friendly name. Order matters: most specific first.
_TERMINAL_HINTS = [
    ("/Terminal.app/",        "Terminal"),
    ("/iTerm.app/",           "iTerm"),
    ("/iTerm2.app/",          "iTerm"),
    ("/Warp.app/",            "Warp"),
    ("/WarpPreview.app/",     "Warp Preview"),
    ("/Ghostty.app/",         "Ghostty"),
    ("/Alacritty.app/",       "Alacritty"),
    ("/kitty.app/",           "kitty"),
    ("/WezTerm.app/",         "WezTerm"),
    ("/Hyper.app/",           "Hyper"),
    ("/Tabby.app/",           "Tabby"),
    # IDE-embedded terminals — these usually do NOT have Screen Recording perm.
    ("/Visual Studio Code.app/", "Visual Studio Code"),
    ("/Code.app/",            "Visual Studio Code"),
    ("/Cursor.app/",          "Cursor"),
    ("/Claude.app/",          "Claude"),
    ("/Windsurf.app/",        "Windsurf"),
    ("/Zed.app/",             "Zed"),
    ("/JetBrains Toolbox.app/", "JetBrains Toolbox"),
    ("/Xcode.app/",           "Xcode"),
]

_IDE_TERMINALS = {
    "Visual Studio Code", "Cursor", "Claude", "Windsurf", "Zed",
    "JetBrains Toolbox", "Xcode",
}


def get_process_chain() -> list[tuple[int, str]]:
    """Walk up the process tree from os.getppid(), return [(pid, comm), ...]."""
    chain: list[tuple[int, str]] = []
    pid = os.getppid()
    for _ in range(20):
        if pid <= 1:
            break
        try:
            r = subprocess.run(
                ["ps", "-o", "ppid=,comm=", "-p", str(pid)],
                capture_output=True, text=True, check=False,
            )
            parts = r.stdout.strip().split(None, 1)
            if len(parts) < 2:
                break
            ppid_s, comm = parts[0], parts[1]
            chain.append((pid, comm))
            pid = int(ppid_s)
        except Exception:
            break
    return chain


def identify_owning_app(chain: list[tuple[int, str]]) -> tuple[str, bool]:
    """Return (friendly_name, is_ide_terminal).

    Walks the whole chain and *prefers* a real terminal app match over an
    IDE/Xcode match — otherwise we'd return "Xcode" for users on systems
    where `make` was shimmed through Xcode CLI tools, even though they're
    actually running inside iTerm/Terminal/Warp/etc.
    """
    terminal_match: str | None = None
    ide_match: str | None = None
    for _pid, comm in chain:
        for hint, name in _TERMINAL_HINTS:
            if hint in comm:
                if name in _IDE_TERMINALS:
                    if ide_match is None:
                        ide_match = name
                else:
                    if terminal_match is None:
                        terminal_match = name
                break  # one match per chain entry is enough
    if terminal_match is not None:
        return terminal_match, False
    if ide_match is not None:
        return ide_match, True
    # Fallback — first entry that isn't a shell/launcher.
    for _pid, comm in chain:
        if not any(s in comm for s in ("zsh", "bash", "fish", "make", "python", "login", "sh")):
            short = comm.rsplit("/", 1)[-1] if "/" in comm else comm
            return short, False
    return "your terminal app", False


def detect_xcode_make_in_chain(chain: list[tuple[int, str]]) -> bool:
    """True if any chain entry is a binary inside the Xcode.app bundle.

    Specifically catches /Applications/Xcode.app/Contents/Developer/usr/bin/make
    which is what Xcode CLI tools shims `make` to. macOS TCC binds the
    "responsible process" to the first .app bundle in the chain — Xcode in
    that case — even when the user is actually running inside iTerm/Terminal.
    """
    return any("/Xcode.app/" in comm for _pid, comm in chain)


def macos_check_screen_capture() -> bool | None:
    """`CGPreflightScreenCaptureAccess()` — check status without prompting.

    Returns True/False on success, None if the symbol is unavailable.
    """
    try:
        path = ctypes.util.find_library("CoreGraphics")
        if not path:
            return None
        cg = ctypes.CDLL(path)
        fn = cg.CGPreflightScreenCaptureAccess
        fn.restype = ctypes.c_bool
        fn.argtypes = []
        return bool(fn())
    except Exception:
        return None


def macos_request_screen_capture() -> bool | None:
    """`CGRequestScreenCaptureAccess()` — ask macOS to show the system dialog.

    Returns True if permission is granted, False if explicitly denied
    (no dialog will appear — user must enable manually via System Settings),
    None if the symbol is unavailable on this macOS version.
    """
    try:
        path = ctypes.util.find_library("CoreGraphics")
        if not path:
            return None
        cg = ctypes.CDLL(path)
        fn = cg.CGRequestScreenCaptureAccess
        fn.restype = ctypes.c_bool
        fn.argtypes = []
        return bool(fn())
    except Exception:
        return None


def open_screen_recording_settings() -> None:
    """Open System Settings → Privacy & Security → Screen Recording."""
    subprocess.Popen(
        [
            "open",
            "x-apple.systempreferences:com.apple.preference.security"
            "?Privacy_ScreenCapture",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def ensure_screen_recording_permission() -> None:
    """End-to-end pre-flight: detect, request, instruct.

    Exits the script with code 2 if permission cannot be obtained.
    """
    chain = get_process_chain()
    owner, is_ide = identify_owning_app(chain)
    xcode_in_chain = detect_xcode_make_in_chain(chain)

    print()
    print("=" * 72)
    print(f"  Parent process tree (top→down):")
    for pid, comm in chain[:8]:
        short = comm.rsplit("/", 1)[-1] if "/" in comm else comm
        marker = "  ⚠  /Applications/Xcode.app/" if "/Xcode.app/" in comm else ""
        print(f"    pid {pid:>5}  {short}{marker}")
    print()
    print(f"  Detected terminal: {owner}")
    print("=" * 72)
    print()

    # ---------------------------------------------------------------- Xcode trap
    if xcode_in_chain:
        script_dir = COMPARISON.parent  # benchmarks/
        sh_quick = script_dir / "record-quick.sh"
        sh_full  = script_dir / "record.sh"
        print("⚠  Xcode-bundled binary detected in process chain.")
        print()
        print(f"   Your `make` is shimmed via Xcode CLI tools at:")
        for _pid, comm in chain:
            if "/Xcode.app/" in comm:
                print(f"     {comm}")
                break
        print()
        print(f"   macOS TCC walks the process chain and binds Screen Recording")
        print(f"   permission to the first `.app` bundle it finds — that's Xcode.")
        print(f"   Your real terminal ({owner}) is never consulted, so even if")
        print(f"   {owner} has Screen Recording perm, ffmpeg will write black frames.")
        print()
        print(f"   ✅  Workaround: bypass `make` and call the script directly.")
        print(f"        cd {script_dir.parent}")
        print(f"        ./benchmarks/record-quick.sh        # 60-second smoke")
        print(f"        ./benchmarks/record.sh              # full 3-minute run")
        print()
        print(f"   The .sh wrappers spawn Python directly, leaving Xcode out of")
        print(f"   the chain — TCC then attributes capture to {owner}, where you")
        print(f"   have permission.")
        print()
        sys.exit(2)

    # ---------------------------------------------------------------- normal path
    status = macos_check_screen_capture()
    if status is True:
        _info(f"Screen Recording permission ✓ already granted to {owner}.")
        return

    if is_ide:
        print(f"⚠  You are running inside {owner}, an IDE.")
        print("⚠  IDEs almost never have Screen Recording permission.")
        print("⚠  Quit this and run from the real Terminal.app (or iTerm / Warp / Ghostty).")
        print()
        print(f"    1.  Quit current session  (Ctrl+C)")
        print(f"    2.  Open Terminal.app  (Cmd+Space, type 'Terminal')")
        print(f"    3.  cd {REPO_ROOT}")
        print(f"    4.  make -C benchmarks record-quick")
        print()
        sys.exit(2)

    _info(f"Triggering macOS permission prompt for {owner}…")
    granted = macos_request_screen_capture()
    if granted is True:
        _info("Permission granted via system dialog ✓")
        return

    # Either denied or status unavailable — open Settings and instruct.
    print()
    print(f"⚠  Screen Recording permission is NOT granted to {owner}.")
    print()
    print("  Opening System Settings → Privacy & Security → Screen Recording…")
    open_screen_recording_settings()
    time.sleep(0.4)
    print()
    print(f"   1.  In the panel that just opened, find  '{owner}'  in the list")
    print(f"        (if it isn't there, click the '+' button and add it from /Applications)")
    print(f"   2.  Toggle the switch ON ✅")
    print(f"   3.  COMPLETELY QUIT {owner} — Cmd+Q, not just close window")
    print(f"   4.  Re-open {owner}, cd {REPO_ROOT}, and re-run this command")
    print()
    print("  Then re-run:  make -C benchmarks record-quick")
    print()
    sys.exit(2)


def find_ffmpeg() -> Path:
    p = shutil.which("ffmpeg")
    if not p:
        _die("ffmpeg not found. Install with `brew install ffmpeg`.")
    return Path(p)


def detect_screen_index(ffmpeg_bin: Path) -> int:
    """Run ffmpeg's device list and pick `[N] Capture screen 0`."""
    r = subprocess.run(
        [str(ffmpeg_bin), "-hide_banner", "-f", "avfoundation",
         "-list_devices", "true", "-i", ""],
        capture_output=True, text=True
    )
    # ffmpeg writes the list to stderr.
    text = r.stderr
    # Match lines like "[AVFoundation indev @ 0x...] [1] Capture screen 0"
    in_video = False
    for line in text.splitlines():
        if "AVFoundation video devices" in line:
            in_video = True
            continue
        if "AVFoundation audio devices" in line:
            in_video = False
            continue
        if in_video and "Capture screen" in line:
            m = re.search(r"\[(\d+)\]\s+Capture screen", line)
            if m:
                return int(m.group(1))
    _info("Could not parse screen index — defaulting to 1.")
    return 1


def macos_major_version() -> int:
    try:
        r = subprocess.run(["sw_vers", "-productVersion"],
                           capture_output=True, text=True, check=False)
        return int(r.stdout.strip().split(".")[0])
    except Exception:
        return 0


def screencapture_video_supported() -> bool:
    """`screencapture -V <duration>` was added in macOS 14 (Sonoma)."""
    return SCREENCAPTURE.exists() and macos_major_version() >= 14


def measure_luminance(ffmpeg_bin: Path, video: Path) -> float:
    """Extract first-frame YAVG from a video. 0 ≈ black, 235 ≈ white."""
    r = subprocess.run(
        [str(ffmpeg_bin), "-hide_banner", "-loglevel", "info",
         "-i", str(video),
         "-vframes", "1", "-vf", "signalstats",
         "-f", "null", "-"],
        capture_output=True, text=True, check=False,
    )
    m = re.search(r"YAVG:([0-9.]+)", r.stderr)
    return float(m.group(1)) if m else 0.0


def _swift_src_hash() -> str:
    """SHA-256 of recorder.swift content, truncated to 16 hex chars."""
    return hashlib.sha256(SWIFT_RECORDER_SRC.read_bytes()).hexdigest()[:16]


def ensure_swift_recorder() -> Path | None:
    """Compile recorder.swift on first use; package as a .app bundle.

    The binary is placed inside `recorder.app/Contents/MacOS/` with a stable
    `CFBundleIdentifier`. macOS TCC tracks Screen Recording grants by bundle
    identifier when one is available.

    Change detection uses a SHA-256 content hash stored in `.swift_src_hash`,
    NOT mtime. `git pull` updates mtime without changing content, which with
    mtime-based detection would cause a spurious recompile, change the binary's
    CDHash, and force TCC re-authorisation every time. Hash-based detection
    rebuilds only when recorder.swift content actually changes.

    The codesign designated requirement is pinned to the bundle identifier
    (`identifier "com.benchmarks.svg.recorder"`) rather than the default CDHash
    — so TCC recognises the same app across rebuilds and does not create a new
    permissions entry.

    Returns the executable path, or None if swiftc is unavailable.
    """
    swiftc = shutil.which("swiftc")
    if not swiftc:
        return None

    # Ensure .app bundle structure exists.
    RECORDER_APP_BIN.parent.mkdir(parents=True, exist_ok=True)

    current_hash = _swift_src_hash()
    stored_hash = RECORDER_HASH_FILE.read_text().strip() if RECORDER_HASH_FILE.exists() else ""

    if (
        RECORDER_APP_BIN.exists()
        and RECORDER_APP_PLIST.exists()
        and current_hash == stored_hash
    ):
        return RECORDER_APP_BIN

    # Always write Info.plist (idempotent). Stable Bundle ID is what makes
    # TCC permissions persist across rebuilds.
    RECORDER_APP_PLIST.write_text(
        INFO_PLIST_TEMPLATE.format(bundle_id=RECORDER_BUNDLE_ID)
    )

    _info("Compiling Swift recorder app bundle (~3 s)...")
    r = subprocess.run(
        [
            swiftc, "-O",
            "-parse-as-library",
            "-framework", "AVFoundation",
            "-framework", "ScreenCaptureKit",
            "-framework", "CoreGraphics",
            "-framework", "CoreMedia",
            str(SWIFT_RECORDER_SRC),
            "-o", str(RECORDER_APP_BIN),
        ],
        capture_output=True, text=True, check=False,
    )
    if r.returncode != 0:
        _info(f"  swiftc failed: {r.stderr.strip()[:400]}")
        return None

    # Sign the bundle with a stable designated requirement pinned to the
    # bundle identifier. Without --requirements, ad-hoc signing uses the
    # CDHash as the DR — so every rebuild produces a new DR, TCC creates a
    # NEW entry and the old grant is orphaned (the user sees "remove old app,
    # add new one" on every recompile). With the explicit DR, TCC matches any
    # binary that carries the identifier, regardless of CDHash.
    dr = f'identifier "{RECORDER_BUNDLE_ID}"'
    cs = subprocess.run(
        [
            "codesign", "--force", "--sign", "-",
            "--identifier", RECORDER_BUNDLE_ID,
            "--requirements", f"=designated => {dr}",
            "--timestamp=none",
            str(RECORDER_APP_DIR),
        ],
        capture_output=True, text=True, check=False,
    )
    if cs.returncode != 0:
        _info(f"  codesign failed: {cs.stderr.strip()[:300]}")
        # Continue anyway — default ad-hoc signing may still work.
    else:
        _info(f"  codesigned: identifier={RECORDER_BUNDLE_ID}  DR={dr}")

    # Persist hash AFTER successful compile + sign so we only skip the build
    # when both steps succeeded.
    RECORDER_HASH_FILE.write_text(current_hash)

    _info(f"  built: {RECORDER_APP_DIR}")
    return RECORDER_APP_BIN


def probe_with_swift_recorder(ffmpeg_bin: Path, recorder_bin: Path) -> bool:
    """1 s capture via the Swift recorder. Validates by exit code + file size.

    Uses posix_spawn with `responsibility_spawnattrs_setdisclaim(1)` so the
    child is its OWN TCC responsible process. Without disclaim, AVCapture
    walks up the chain to /opt/homebrew/.../python3.14 and refuses with
    "Cannot Record" — even though CGRequestScreenCaptureAccess in-binary
    returns true, AVCapture does its own responsibility-aware check.

    Validation strategy:
      - Swift binary exits with code 0 (writer.status = .completed)
      - Output file > 200 KB (1 s @ 60 fps h264 BGRA → ~1–3 MB normally)
      - Luminance check runs as INFO only — ffmpeg sometimes can't decode
        the first frame of an SCK-h264 .mp4 on macOS 26, but the file is
        still valid (QuickTime plays it correctly).
    """
    probe_dir = Path("/tmp/svg-bench-probe-swift")
    probe_dir.mkdir(exist_ok=True)
    probe_mp4 = probe_dir / "probe.mp4"
    if probe_mp4.exists():
        probe_mp4.unlink()

    print()
    print("─" * 64)
    print("  Probing Swift recorder via TCC-disclaim spawn (≤ 90 s)...")
    print("  ⚠  If a 'recorder would like to record this computer's screen'")
    print("     dialog appears, click ALLOW.")
    print("─" * 64)
    print()
    try:
        pid = spawn_disclaimed(str(recorder_bin), ["1", str(probe_mp4)])
    except OSError as e:
        _info(f"  spawn_disclaimed failed: {e}")
        return False

    rc = waitpid_full(pid, timeout=90)
    print()
    if rc != 0:
        _info(f"  swift probe exited with rc={rc}")
        return False

    size = probe_mp4.stat().st_size if probe_mp4.exists() else 0
    if size < 200 * 1024:
        _info(f"  swift probe produced too-small output ({size} bytes < 200 KB)")
        _info(f"  inspect manually:  open {probe_mp4}")
        return False

    # Luminance is informational — ffmpeg's signalstats sometimes returns 0
    # for SCK-encoded h264 .mp4 files on macOS 26 (codec metadata quirk),
    # even though QuickTime plays the file correctly. We log it but don't
    # gate on it.
    yavg = measure_luminance(ffmpeg_bin, probe_mp4)
    _info(f"  swift recorder ✓ size={size // 1024} KB, ffmpeg luminance={yavg:.1f}")
    if yavg < 1.0:
        _info(f"  (luminance=0 from ffmpeg is OK for SCK-h264 — file is valid)")
        _info(f"  to verify visually: open {probe_mp4}")
    return True


def probe_with_screencapture(ffmpeg_bin: Path) -> bool:
    """Try the Apple-signed system recorder. Often works when ffmpeg can't,
    because TCC walks the responsibility chain back to the terminal cleanly
    for system binaries instead of binding to /opt/homebrew/bin/ffmpeg."""
    if not screencapture_video_supported():
        return False

    probe_dir = Path("/tmp/svg-bench-probe-sc")
    probe_dir.mkdir(exist_ok=True)
    probe_mov = probe_dir / "probe.mov"
    if probe_mov.exists():
        probe_mov.unlink()

    _info("Probing /usr/sbin/screencapture -V (1 s)...")
    r = subprocess.run(
        [str(SCREENCAPTURE), "-V", "1", "-x", str(probe_mov)],
        capture_output=True, text=True, timeout=10, check=False,
    )
    if r.returncode != 0 or not probe_mov.exists() or probe_mov.stat().st_size < 4096:
        _info(f"  screencapture probe failed: rc={r.returncode}  size={probe_mov.stat().st_size if probe_mov.exists() else 0}")
        if r.stderr.strip():
            _info(f"  stderr: {r.stderr.strip()[:200]}")
        return False

    yavg = measure_luminance(ffmpeg_bin, probe_mov)
    _info(f"  screencapture avg luminance: {yavg:.1f} (0=black, 235=white)")
    return yavg > 8.0


def _print_probe_failure_help(server) -> None:
    """All capture methods failed — print actionable diagnostics and exit."""
    real_python = os.path.realpath(sys.executable)
    print()
    print("⚠  All capture methods (Swift / ffmpeg / screencapture) returned black frames.")
    print()
    print("  This is a stuck TCC state — try the following IN ORDER:")
    print()
    print("  1) Quit iTerm completely (Cmd+Q, NOT just close the window).")
    print("     Verify in Activity Monitor that no iTerm/iTermServer processes remain.")
    print("     Reopen iTerm, cd back here, re-run.")
    print()
    print("     Permission caches are read at process start. A running iTerm")
    print("     session won't see new permissions until it's restarted.")
    print()
    print("  2) The Swift recorder bypasses Python entirely. If it failed too,")
    print(f"     macOS may not have prompted yet. Run it once manually:")
    print()
    print(f"        {SWIFT_RECORDER_BIN} 2 /tmp/probe.mp4 && open /tmp/probe.mp4")
    print()
    print("     The first run shows a permission dialog — accept it. After that,")
    print(f"     re-run ./record-quick.sh from this terminal.")
    print()
    print("  3) Add the brew Python's REAL path to Screen Recording.")
    print(f"     System Settings won't accept symlinks. Use realpath:")
    print()
    print(f"        sys.executable = {sys.executable}")
    print(f"        realpath       = {real_python}")
    print()
    print(f"     In Finder press Cmd+Shift+G, paste the realpath, drag the file")
    print(f"     into System Settings → Privacy & Security → Screen Recording.")
    print()
    print(f"  Diagnostics: macOS major={macos_major_version()} · "
          f"screencapture -V supported={screencapture_video_supported()}")
    print()
    server.shutdown()
    sys.exit(2)


def quick_permission_probe(ffmpeg_bin: Path, screen_idx: int) -> bool:
    """Capture 1s with ffmpeg-avfoundation and verify it isn't all black."""
    probe_dir = Path("/tmp/svg-bench-probe")
    probe_dir.mkdir(exist_ok=True)
    probe_mp4 = probe_dir / "probe.mp4"
    if probe_mp4.exists():
        probe_mp4.unlink()

    _info("Probing ffmpeg avfoundation (1 s)...")
    r = subprocess.run(
        [
            str(ffmpeg_bin), "-hide_banner", "-loglevel", "error",
            "-f", "avfoundation", "-framerate", "30", "-capture_cursor", "0",
            "-i", f"{screen_idx}:none",
            "-t", "1", "-y", str(probe_mp4),
        ],
        capture_output=True, text=True, check=False,
    )
    if r.returncode != 0 or not probe_mp4.exists() or probe_mp4.stat().st_size < 1024:
        _info(f"  ffmpeg probe failed: {r.stderr.strip()[:200]}")
        return False

    yavg = measure_luminance(ffmpeg_bin, probe_mp4)
    _info(f"  ffmpeg avg luminance: {yavg:.1f} (0=black, 235=white)")
    return yavg > 8.0


# ---------------------------------------------------------------------------
# HTTP server: static files + telemetry POST sink
# ---------------------------------------------------------------------------

class _Handler(BaseHTTPRequestHandler):
    serve_dir: Path | None = None
    flutter_path: Path | None = None
    chrome_path: Path | None = None
    flutter_lock = threading.Lock()
    chrome_lock = threading.Lock()

    # silence default access-log spam
    def log_message(self, fmt, *args):  # noqa: A002
        return

    def do_OPTIONS(self):  # CORS preflight from Chrome
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        # Dart's HttpClient (HTTP/1.1) sends chunked transfer encoding instead
        # of Content-Length. We must decode it properly; plain rfile.read(n)
        # with n=0 produces an empty body and a JSON-parse 400.
        te = self.headers.get("Transfer-Encoding", "").lower()
        cl = self.headers.get("Content-Length")
        if "chunked" in te:
            chunks: list[bytes] = []
            while True:
                size_line = self.rfile.readline().strip()
                if not size_line:
                    break
                chunk_size = int(size_line, 16)
                if chunk_size == 0:
                    break
                chunks.append(self.rfile.read(chunk_size))
                self.rfile.read(2)  # consume trailing \r\n after chunk data
            body = b"".join(chunks)
        elif cl is not None:
            body = self.rfile.read(int(cl))
        else:
            body = b""
        try:
            payload = json.loads(body)
        except Exception:
            self.send_response(400); self.end_headers(); return

        payload["_received_ms"] = int(time.time() * 1000)
        line = json.dumps(payload, separators=(",", ":")) + "\n"

        if self.path.endswith("/flutter") and _Handler.flutter_path:
            with _Handler.flutter_lock, open(_Handler.flutter_path, "a") as f:
                f.write(line)
        elif self.path.endswith("/chrome") and _Handler.chrome_path:
            with _Handler.chrome_lock, open(_Handler.chrome_path, "a") as f:
                f.write(line)
        elif self.path.endswith("/ping"):
            # Diagnostic ping from the Flutter side at app startup. Just
            # log to stderr so the operator sees the app reached us BEFORE
            # the first 5-second telemetry batch arrives.
            who = payload.get("label", "?")
            kind = payload.get("kind", "?")
            print(f"[telemetry-server] {kind} from {who} · pid={payload.get('pid', '?')}",
                  flush=True)
        else:
            self.send_response(404); self.end_headers(); return

        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

    def do_GET(self):
        # Serve static files from serve_dir.
        path = urlparse(self.path).path.lstrip("/")
        full = (_Handler.serve_dir / path).resolve()
        # path-traversal guard
        try:
            full.relative_to(_Handler.serve_dir)
        except ValueError:
            self.send_response(403); self.end_headers(); return
        if full.is_dir():
            full = full / "index.html"
        if not full.exists() or not full.is_file():
            self.send_response(404); self.end_headers(); return
        ext = full.suffix.lower()
        ct = {
            ".html": "text/html; charset=utf-8",
            ".css":  "text/css; charset=utf-8",
            ".js":   "application/javascript; charset=utf-8",
            ".svg":  "image/svg+xml; charset=utf-8",
            ".json": "application/json; charset=utf-8",
            ".mp4":  "video/mp4",
            ".gif":  "image/gif",
            ".png":  "image/png",
        }.get(ext, "application/octet-stream")
        data = full.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", ct)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-cache, no-store")
        self.end_headers()
        self.wfile.write(data)


def start_server(port: int) -> ThreadingHTTPServer:
    _Handler.serve_dir = BENCHMARKS
    try:
        server = ThreadingHTTPServer(("127.0.0.1", port), _Handler)
    except OSError as e:
        _die(f"Could not bind 127.0.0.1:{port} ({e}). Another session running?")
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


# ---------------------------------------------------------------------------
# Build / launch helpers
# ---------------------------------------------------------------------------

def build_flutter_with_telemetry(flutter_bin: Path, telemetry_url: str) -> None:
    ensure_macos_platform(flutter_bin)
    _info("flutter pub get...")
    subprocess.run([str(flutter_bin), "pub", "get"], cwd=BENCHMARK_APP, check=True)
    _info(f"flutter build macos --release  (telemetry → {telemetry_url})")
    subprocess.run(
        [
            str(flutter_bin), "build", "macos", "--release",
            f"--dart-define=BENCHMARK_TELEMETRY={telemetry_url}",
            "--dart-define=BENCHMARK_AUTOROUTE=/mega_stress",
        ],
        cwd=BENCHMARK_APP, check=True,
    )


def kill_app_by_name(process_name: str) -> None:
    subprocess.run(
        ["osascript", "-e", f'tell application "{process_name}" to quit'],
        check=False, capture_output=True,
    )
    time.sleep(0.5)
    subprocess.run(["pkill", "-f", process_name], check=False, capture_output=True)


# ---------------------------------------------------------------------------
# Post-processing
# ---------------------------------------------------------------------------

def split_recording(ffmpeg: Path, src: Path, left: Path, right: Path) -> None:
    _info("Splitting recording into left / right halves...")
    cmd = [
        str(ffmpeg), "-hide_banner", "-loglevel", "error",
        "-i", str(src),
        "-filter_complex",
        "[0:v]split=2[a][b];"
        "[a]crop=iw/2:ih:0:0[L];"
        "[b]crop=iw/2:ih:iw/2:0[R]",
        "-map", "[L]", "-c:v", "libx264", "-preset", "fast",
            "-crf", "20", "-pix_fmt", "yuv420p", "-y", str(left),
        "-map", "[R]", "-c:v", "libx264", "-preset", "fast",
            "-crf", "20", "-pix_fmt", "yuv420p", "-y", str(right),
    ]
    subprocess.run(cmd, check=True)


def make_gif(ffmpeg: Path, src: Path, dst: Path,
             start: int, length: int, fps: int, width: int) -> None:
    palette = dst.with_suffix(".palette.png")
    _info(f"  → {dst.name}  (start={start}s len={length}s fps={fps} w={width})")
    subprocess.run(
        [
            str(ffmpeg), "-hide_banner", "-loglevel", "error",
            "-ss", str(start), "-t", str(length), "-i", str(src),
            "-vf", f"fps={fps},scale={width}:-1:flags=lanczos,palettegen",
            "-y", str(palette),
        ],
        check=True,
    )
    subprocess.run(
        [
            str(ffmpeg), "-hide_banner", "-loglevel", "error",
            "-ss", str(start), "-t", str(length), "-i", str(src), "-i", str(palette),
            "-lavfi",
            f"fps={fps},scale={width}:-1:flags=lanczos[x];[x][1:v]paletteuse",
            "-y", str(dst),
        ],
        check=True,
    )
    palette.unlink(missing_ok=True)


def stats(values: list[float]) -> dict:
    if not values:
        return {"count": 0, "avg_ms": 0.0, "p50_ms": 0.0, "p90_ms": 0.0,
                "p99_ms": 0.0, "max_ms": 0.0}
    s = sorted(values)
    n = len(s)
    return {
        "count":  n,
        "avg_ms": round(sum(s) / n, 2),
        "p50_ms": round(s[n // 2], 2),
        "p90_ms": round(s[min(n - 1, int(n * 0.90))], 2),
        "p99_ms": round(s[min(n - 1, int(n * 0.99))], 2),
        "max_ms": round(max(s), 2),
    }


def aggregate(flutter_jsonl: Path, chrome_jsonl: Path,
              duration_s: int) -> dict:
    flutter_builds, flutter_rasters = [], []
    for line in flutter_jsonl.read_text().splitlines():
        if not line.strip(): continue
        try:
            d = json.loads(line)
            flutter_builds.extend(d.get("builds_ms", []))
            flutter_rasters.extend(d.get("rasters_ms", []))
        except Exception:
            continue

    flutter_total = [b + r for b, r in zip(flutter_builds, flutter_rasters)]

    chrome_deltas: list[float] = []
    for line in chrome_jsonl.read_text().splitlines():
        if not line.strip(): continue
        try:
            d = json.loads(line)
            chrome_deltas.extend(d.get("deltas_ms", []))
        except Exception:
            continue

    return {
        "duration_s": duration_s,
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "flutter": {
            "frame_count": len(flutter_builds),
            "fps_avg":     round(len(flutter_total) / duration_s, 1) if flutter_total else 0,
            "build_ms":    stats(flutter_builds),
            "raster_ms":   stats(flutter_rasters),
            "total_ms":    stats(flutter_total),
            "jank_60hz":   sum(1 for v in flutter_total if v > 16.67),
            "jank_120hz":  sum(1 for v in flutter_total if v > 8.33),
        },
        "chrome": {
            "frame_count": len(chrome_deltas),
            "fps_avg":     round(len(chrome_deltas) / duration_s, 1) if chrome_deltas else 0,
            "delta_ms":    stats(chrome_deltas),
            "jank_60hz":   sum(1 for v in chrome_deltas if v > 16.67),
            "jank_120hz":  sum(1 for v in chrome_deltas if v > 8.33),
        },
    }


def write_report(path: Path, summary: dict, gif_clip: int, gif_fps: int,
                 gif_start: int, flutter_gif: Path, chrome_gif: Path) -> None:
    f = summary["flutter"]
    c = summary["chrome"]
    fps_diff = f["fps_avg"] - c["fps_avg"]
    p99_diff = f["total_ms"]["p99_ms"] - c["delta_ms"]["p99_ms"]
    jank60_diff = f["jank_60hz"] - c["jank_60hz"]

    lines = [
        "# Galactic Storm — Side-by-Side Recording",
        "",
        f"Recorded **{summary['duration_s']}s** · {summary['generated_at']}",
        "",
        "Asset under test: [`assets/stress/galactic_storm.svg`]"
        "(../../assets/stress/galactic_storm.svg) — **3,074 elements**, "
        "**1,667 concurrent animations**.",
        "",
        "## Highlight clips",
        "",
        f"_{gif_clip}s @ {gif_fps}fps starting at {gif_start}s into the recording._",
        "",
        "| full_svg_flutter (release, native macOS) | Chrome (native Blink) |",
        "|---|---|",
        f"| ![flutter]({flutter_gif.name}) | ![chrome]({chrome_gif.name}) |",
        "",
        f"Full-length captures: [`flutter.mp4`](flutter.mp4) · [`chrome.mp4`](chrome.mp4)",
        "",
        "## Metrics over the full window",
        "",
        "| Metric                | full_svg_flutter | Chrome     | Δ (flutter − chrome) |",
        "|---                    |              ---:|        ---:|                  ---:|",
        f"| Avg FPS               | {f['fps_avg']:>16} | {c['fps_avg']:>10} | {fps_diff:+.1f}                |",
        f"| Frame count           | {f['frame_count']:>16} | {c['frame_count']:>10} | {f['frame_count'] - c['frame_count']:+d}                  |",
        f"| p50 frame ms          | {f['total_ms']['p50_ms']:>16} | {c['delta_ms']['p50_ms']:>10} | {f['total_ms']['p50_ms'] - c['delta_ms']['p50_ms']:+.2f}                 |",
        f"| p90 frame ms          | {f['total_ms']['p90_ms']:>16} | {c['delta_ms']['p90_ms']:>10} | {f['total_ms']['p90_ms'] - c['delta_ms']['p90_ms']:+.2f}                 |",
        f"| p99 frame ms          | {f['total_ms']['p99_ms']:>16} | {c['delta_ms']['p99_ms']:>10} | {p99_diff:+.2f}                 |",
        f"| Max frame ms          | {f['total_ms']['max_ms']:>16} | {c['delta_ms']['max_ms']:>10} | {f['total_ms']['max_ms'] - c['delta_ms']['max_ms']:+.2f}                 |",
        f"| Jank frames (>16.67ms)| {f['jank_60hz']:>16} | {c['jank_60hz']:>10} | {jank60_diff:+d}                  |",
        f"| Jank frames (>8.33ms) | {f['jank_120hz']:>16} | {c['jank_120hz']:>10} | {f['jank_120hz'] - c['jank_120hz']:+d}                  |",
        "",
        "### Build vs raster split (full_svg_flutter only)",
        "",
        "| Phase     | avg | p50 | p90 | p99 | max |",
        "|---        | ---:| ---:| ---:| ---:| ---:|",
        f"| build_ms  | {f['build_ms']['avg_ms']} | {f['build_ms']['p50_ms']} | {f['build_ms']['p90_ms']} | {f['build_ms']['p99_ms']} | {f['build_ms']['max_ms']} |",
        f"| raster_ms | {f['raster_ms']['avg_ms']} | {f['raster_ms']['p50_ms']} | {f['raster_ms']['p90_ms']} | {f['raster_ms']['p99_ms']} | {f['raster_ms']['max_ms']} |",
        "",
        "---",
        "",
        "Raw data: `flutter_metrics.jsonl`, `chrome_metrics.jsonl`, `summary.json`.",
        "",
        "**Note on FPS parity.** Chrome on macOS often clamps `requestAnimationFrame`",
        "to 60 Hz on external displays, even on ProMotion laptops. The Flutter side",
        "runs at native refresh. Compare **p99 frame time** and **jank counts** for",
        "an apples-to-apples view of stability rather than raw FPS.",
        "",
    ]
    path.write_text("\n".join(lines))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    if sys.platform != "darwin":
        _die("macOS-only.")

    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--duration",       type=int, default=180, help="Recording length in seconds (default 180)")
    ap.add_argument("--gif-clip",       type=int, default=30,  help="Highlight GIF length in seconds (default 30)")
    ap.add_argument("--gif-start",      type=int, default=10,  help="GIF start offset (default 10s — skip warmup)")
    ap.add_argument("--gif-fps",        type=int, default=15,  help="GIF frame rate (default 15)")
    ap.add_argument("--gif-width",      type=int, default=720, help="GIF width in px (height auto)")
    ap.add_argument("--video-fps",      type=int, default=60,  help="Screen capture frame rate (default 60)")
    ap.add_argument("--video-device",   type=int, default=None,help="Override AVFoundation screen index")
    ap.add_argument("--no-build",       action="store_true",   help="Skip Flutter rebuild (binary must already have telemetry baked in)")
    ap.add_argument("--menubar-offset", type=int, default=28,  help="Pixels reserved for menu bar")
    ap.add_argument("--skip-permission-check", action="store_true",
                    help="Skip the 1s probe that detects missing Screen Recording perm")
    ap.add_argument("--keep-raw",       action="store_true",   help="Keep the raw full-screen MP4 (default deletes after split)")
    args = ap.parse_args()

    if not args.skip_permission_check:
        ensure_screen_recording_permission()

    ffmpeg  = find_ffmpeg()
    chrome  = find_chromium()
    flutter = FVM_FLUTTER if FVM_FLUTTER.exists() else Path(shutil.which("flutter") or "")
    if not chrome:
        _die("No Chromium-family browser found.")
    if not flutter or not flutter.exists():
        _die("Flutter SDK not found.")

    # ------------------------------------------------------------- output dir
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = RECORDINGS / timestamp
    out_dir.mkdir(parents=True, exist_ok=True)
    _info(f"Output directory: {out_dir}")

    flutter_jsonl = out_dir / "flutter_metrics.jsonl"
    chrome_jsonl  = out_dir / "chrome_metrics.jsonl"
    flutter_jsonl.touch()
    chrome_jsonl.touch()
    _Handler.flutter_path = flutter_jsonl
    _Handler.chrome_path  = chrome_jsonl

    # --------------------------------------------------------------- server
    server = start_server(TELEMETRY_PORT)
    base = f"http://127.0.0.1:{TELEMETRY_PORT}"
    flutter_telemetry = f"{base}/metrics/flutter"
    chrome_telemetry  = f"{base}/metrics/chrome"
    chrome_url = (
        f"{base}/comparison/comparison.html"
        f"?telemetry={quote(chrome_telemetry, safe='')}"
    )
    _info(f"HTTP server: {base}")

    # --------------------------------------------------- screen / capture probe
    screen_idx = args.video_device if args.video_device is not None else detect_screen_index(ffmpeg)
    recording_method = "ffmpeg"
    swift_bin: Path | None = None

    if not args.skip_permission_check:
        # Method 1 — Swift AVFoundation recorder. Most reliable: TCC binds
        # the permission to *our* binary identity, no Python/brew indirection.
        swift_bin = ensure_swift_recorder()
        swift_ok = False
        if swift_bin is not None:
            swift_ok = probe_with_swift_recorder(ffmpeg, swift_bin)
        if swift_ok:
            recording_method = "swift"
            _info("✓ Swift recorder works — using it for the recording.")
        else:
            if swift_bin is None:
                _info("swiftc not available — skipping Swift recorder.")
            else:
                _info("Swift recorder probe failed.")

            # Method 2 — ffmpeg avfoundation
            ffmpeg_ok = quick_permission_probe(ffmpeg, screen_idx)
            if ffmpeg_ok:
                recording_method = "ffmpeg"
                _info("✓ ffmpeg works — using it for the recording.")
            else:
                _info("ffmpeg probe returned a black frame.")
                _info("Trying macOS-native /usr/sbin/screencapture as last resort...")
                sc_ok = probe_with_screencapture(ffmpeg)
                if sc_ok:
                    recording_method = "screencapture"
                    _info("✓ screencapture works — using it for the recording.")
                else:
                    _print_probe_failure_help(server)
    _info(f"Recording method: {recording_method}")

    # ------------------------------------------------------------------ build
    if not args.no_build:
        build_flutter_with_telemetry(flutter, flutter_telemetry)

    app_path = find_built_app()
    if not app_path:
        _die("No built .app found. Run without --no-build.")

    # ------------------------------------------------------------- positioning
    sw, sh = get_screen_size()
    half = sw // 2
    top = args.menubar_offset
    height = sh - top
    _info(f"Screen: {sw}x{sh} (each window {half}x{height})")

    # ----------------------------------------------------------- launch apps
    # Launch Flutter via the bundled executable directly (NOT `open -na`) so
    # we capture its stderr — the Flutter MetricsReporter prints diagnostic
    # lines that help when debugging telemetry. We also write that stderr
    # tee'd to a file in the output dir for forensics.
    flutter_exe = app_path / "Contents" / "MacOS" / app_path.stem
    _info(f"Launching Flutter app via executable: {flutter_exe}")
    flutter_log = out_dir / "flutter_app.log"
    flutter_proc = subprocess.Popen(
        [str(flutter_exe)],
        stdout=open(flutter_log, "wb"),
        stderr=subprocess.STDOUT,
    )
    time.sleep(2.5)
    if flutter_proc.poll() is not None:
        _info(f"⚠  Flutter app exited immediately (rc={flutter_proc.returncode})")
        _info(f"   See {flutter_log}")
    position_window_by_process(app_path.stem, 0, top, half, height)
    # Bring to the front so it's actually rendering (occluded windows may
    # be throttled by the macOS compositor and skip frame timings).
    _osascript(
        f'tell application "System Events" to tell process "{app_path.stem}" '
        f'to set frontmost to true'
    )

    _info("Launching Chrome (--app mode)...")
    profile = "/tmp/full-svg-flutter-record-profile"
    Path(profile).mkdir(exist_ok=True)
    chrome_proc = subprocess.Popen(
        [
            str(chrome),
            f"--app={chrome_url}",
            f"--window-position={half},{top}",
            f"--window-size={half},{height}",
            f"--user-data-dir={profile}",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-features=Translate,InterestFeed",
            "--disable-extensions",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    # ------------------------------------------------------------- warmup
    settle = 5
    _info(f"Settling {settle}s before capture (warmup)...")
    time.sleep(settle)

    # ----------------------------------------------------------- recording
    if recording_method == "swift":
        assert swift_bin is not None
        flutter_video = out_dir / "flutter.mp4"
        chrome_video  = out_dir / "chrome.mp4"
        # Pass exact window regions (logical points) so each recorder uses a
        # plain display filter + sourceRect — avoids CGS init issues that
        # SCContentFilter(desktopIndependentWindow:) triggers in parallel spawns.
        flutter_rect = ["0",    str(top), str(half), str(height)]
        chrome_rect  = [str(half), str(top), str(half), str(height)]
        _info(f"Recording {args.duration}s: Flutter → flutter.mp4 "
              f"| Chrome → chrome.mp4  [parallel region capture]")
        try:
            pid_f = spawn_disclaimed(str(swift_bin),
                                     [str(args.duration), str(flutter_video),
                                      "--rect", *flutter_rect])
            pid_c = spawn_disclaimed(str(swift_bin),
                                     [str(args.duration), str(chrome_video),
                                      "--rect", *chrome_rect])
        except OSError as e:
            _die(f"spawn_disclaimed failed: {e}")
            raise SystemExit  # for type checker
        rc_f = waitpid_full(pid_f, timeout=args.duration + 60)
        rc_c = waitpid_full(pid_c, timeout=args.duration + 60)
        if rc_f != 0:
            _die(f"Flutter Swift recorder exited with rc={rc_f}")
        if rc_c != 0:
            _die(f"Chrome Swift recorder exited with rc={rc_c}")
        raw_video = None  # per-window capture — no full-screen file to split
    else:
        if recording_method == "screencapture":
            raw_video = out_dir / "raw.mov"
            _info(f"Recording {args.duration}s with screencapture -V → {raw_video}")
            rec_cmd = [
                str(SCREENCAPTURE),
                "-V", str(args.duration),
                "-x",                  # no sound effect
                str(raw_video),
            ]
        else:
            raw_video = out_dir / "raw.mp4"
            _info(f"Recording {args.duration}s with ffmpeg → {raw_video}")
            rec_cmd = [
                str(ffmpeg), "-hide_banner", "-loglevel", "error",
                "-f", "avfoundation",
                "-framerate", str(args.video_fps),
                "-capture_cursor", "0",
                "-i", f"{screen_idx}:none",
                "-t", str(args.duration),
                "-c:v", "libx264", "-preset", "fast", "-crf", "20",
                "-pix_fmt", "yuv420p",
                "-y", str(raw_video),
            ]
        rec_proc = subprocess.Popen(rec_cmd)
        try:
            rec_proc.wait(timeout=args.duration + 60)
        except subprocess.TimeoutExpired:
            _info(f"{recording_method} timed out — terminating.")
            rec_proc.send_signal(signal.SIGINT)
            try:
                rec_proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                rec_proc.kill()

    _info("Recording complete. Stopping apps...")
    chrome_proc.terminate()
    try:
        chrome_proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        chrome_proc.kill()
    # Stop our directly-launched Flutter app.
    if flutter_proc.poll() is None:
        flutter_proc.terminate()
        try:
            flutter_proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            flutter_proc.kill()
    # Belt-and-suspenders kill in case AppKit spawned a helper.
    kill_app_by_name(app_path.stem)

    # Let any in-flight telemetry land.
    time.sleep(2)
    server.shutdown()
    server.server_close()

    # ----------------------------------------------------------- post-process
    flutter_video = out_dir / "flutter.mp4"
    chrome_video  = out_dir / "chrome.mp4"

    if raw_video is not None:
        # Full-screen recording (ffmpeg / screencapture) — crop into two halves.
        if not raw_video.exists() or raw_video.stat().st_size < 1024:
            _die(f"Raw recording is missing/empty ({raw_video}). Likely a permission issue.")
        split_recording(ffmpeg, raw_video, flutter_video, chrome_video)
        if not args.keep_raw:
            raw_video.unlink(missing_ok=True)
    else:
        # Per-window capture (swift) — files are already written directly.
        for vid, name in [(flutter_video, "flutter.mp4"), (chrome_video, "chrome.mp4")]:
            if not vid.exists() or vid.stat().st_size < 1024:
                _die(f"{name} is missing/empty. Check swift recorder output above.")

    flutter_gif = out_dir / f"flutter_{args.gif_clip}s.gif"
    chrome_gif  = out_dir / f"chrome_{args.gif_clip}s.gif"
    _info("Generating highlight GIFs...")
    make_gif(ffmpeg, flutter_video, flutter_gif,
             args.gif_start, args.gif_clip, args.gif_fps, args.gif_width)
    make_gif(ffmpeg, chrome_video, chrome_gif,
             args.gif_start, args.gif_clip, args.gif_fps, args.gif_width)

    # ----------------------------------------------------------- aggregate
    _info("Aggregating telemetry...")
    summary = aggregate(flutter_jsonl, chrome_jsonl, args.duration)
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2))

    write_report(
        out_dir / "report.md", summary,
        args.gif_clip, args.gif_fps, args.gif_start,
        flutter_gif, chrome_gif,
    )

    # ----------------------------------------------------------- banner
    print()
    print("=" * 72)
    print(f"  Done. Artifacts in: {out_dir}")
    print()
    print(f"    flutter.mp4  / chrome.mp4    full {args.duration}s captures")
    print(f"    flutter_{args.gif_clip}s.gif / chrome_{args.gif_clip}s.gif    highlight GIFs")
    print( "    flutter_metrics.jsonl / chrome_metrics.jsonl    raw telemetry")
    print( "    summary.json                aggregated stats")
    print( "    report.md                   side-by-side markdown report")
    print()
    f = summary["flutter"]; c = summary["chrome"]
    print(f"  Flutter  avg FPS {f['fps_avg']:>5} · p99 {f['total_ms']['p99_ms']:>5} ms · jank60 {f['jank_60hz']}")
    print(f"  Chrome   avg FPS {c['fps_avg']:>5} · p99 {c['delta_ms']['p99_ms']:>5} ms · jank60 {c['jank_60hz']}")
    print("=" * 72)


if __name__ == "__main__":
    main()
