# Side-by-side comparison harness · macOS

Compare the **release** Flutter build of the benchmark app against a real
**Chromium** rendering of the exact same SVG, side-by-side, with FPS and
frame-time HUDs on both sides.

## How it works (and why it's accurate)

```
┌──────────────────────────┐  ┌───────────────────────────┐
│   Flutter (release .app) │  │   Chrome (--app mode)     │
│   benchmark_app          │  │   comparison.html         │
│                          │  │     └─ <iframe src=*.svg> │
│   ┌──────────────────┐   │  │   ┌──────────────────┐    │
│   │   FPS HUD        │   │  │   │   FPS HUD        │    │
│   │   (RepaintBound.)│   │  │   │   (own GPU layer)│    │
│   └──────────────────┘   │  │   └──────────────────┘    │
│                          │  │                           │
│  composited by Skia      │  │  composited by Blink      │
└──────────────────────────┘  └───────────────────────────┘
            ▲                              ▲
            │ AppleScript window position  │ --window-position
            │                              │
            └──── Python launcher.py ──────┘
                  + tiny stdlib http.server
                    serving benchmarks/
```

Both apps are **native processes**. Each composites directly into its own
`CALayer`. The launcher only:

1. Builds the Flutter release binary if needed.
2. Starts a tiny `http.server` so Chrome can resolve `../assets/stress/*`.
3. Positions both windows side-by-side via AppleScript.

After that, neither process knows the other exists. There is **no**
proxying, no GPU read-back, no IPC, no compositor sharing. The harness
itself is invisible to the measurement — exactly the property you want
when measuring rendering performance.

### Why not a single composited window?

A "single window" solution (`CGDisplayStream` capture, or hosting both as
sub-`NSView`s composited by a parent) requires at least one extra GPU
read-back per frame. For an asset like Galactic Storm that read-back can
add 2–3 ms/frame on integrated GPUs and bias the measurement we are
trying to take. Two native windows side-by-side trade a tiny amount of
window-chrome real estate for **zero measurement bias**.

## Prerequisites

- macOS
- Flutter SDK (project's pinned `.fvm/flutter_sdk/` is auto-detected)
- Google Chrome, Chromium, Brave, or Edge — first one found wins
- Python 3.9+ (stdlib only — no pip install required)

## Quick start

```bash
# From repo root:
make -C benchmarks compare              # build + launch
make -C benchmarks compare-rebuild      # force fresh release build, then launch
make -C benchmarks compare-run          # launch (assumes already built)

# Or invoke the launcher directly:
python3 benchmarks/comparison/launcher.py
python3 benchmarks/comparison/launcher.py --rebuild
python3 benchmarks/comparison/launcher.py --flutter-only
python3 benchmarks/comparison/launcher.py --chrome-only
```

The first run spends ~30–90 s on `flutter build macos --release`.
Subsequent runs reuse the built binary — `make compare-run` is instant.

## HUD controls

Both sides respond to identical keyboard shortcuts (focus the window first):

| Key | Effect                              |
| --- | ----------------------------------- |
| `M` | Toggle FPS HUD visibility           |
| `V` | Toggle verbose metrics (p99 / jank) |
| `I` | (Flutter only) Toggle info card     |
| `R` | (Chrome only) Reload SVG iframe     |

### Metrics shown

| Metric          | Flutter source                       | Chrome source                          |
| --------------- | ------------------------------------ | -------------------------------------- |
| FPS             | `addTimingsCallback` rolling avg     | `requestAnimationFrame` delta avg      |
| avg frame ms    | `(buildDuration + rasterDuration)/n` | mean of rAF deltas                     |
| p99 frame ms    | sorted percentile over 120-frame win | sorted percentile over 240-frame win   |
| jank/60Hz       | frames where buildDuration > 16.67ms | rAF deltas > 16.67ms                   |
| jank/120Hz      | frames where buildDuration > 8.33ms  | rAF deltas > 8.33ms                    |

Both HUDs refresh their *display* every 500 ms — the underlying samples
are collected on every frame, but the DOM/widget update cadence is
deliberately throttled so the HUD itself is not a measurable load.

## What the launcher actually does

```python
# 1. Find Flutter SDK (FVM-pinned or PATH).
# 2. Add macOS platform if missing → flutter create --platforms=macos .
# 3. flutter pub get && flutter build macos --release      [if needed]
# 4. Start http.server on a random port, rooted at benchmarks/.
# 5. Read screen size via osascript Finder bounds.
# 6. open -na <BenchmarkApp>.app  →  AppleScript-position to left half.
# 7. Launch Chrome with:
#    --app=http://127.0.0.1:N/comparison/comparison.html
#    --window-position=W/2,top  --window-size=W/2,H
#    --user-data-dir=/tmp/full-svg-flutter-comparison-profile  (isolated)
# 8. Block on Ctrl+C; shut down http.server cleanly.
```

The Chrome profile is isolated to `/tmp/full-svg-flutter-comparison-profile`
so it can't pick up extensions or sync state from your main browser.
Run `make distclean` to remove it.

## Troubleshooting

**`No Chromium-family browser found`** — install Chrome, or symlink your
preferred browser into one of the paths listed in `CHROME_CANDIDATES`
inside `launcher.py`.

**Windows do not get positioned** — System Events needs Accessibility
permission. macOS will prompt the first time the launcher runs
AppleScript window positioning. Grant Terminal (or your IDE) accessibility
access in *System Settings → Privacy & Security → Accessibility*.

**Flutter app immediately quits** — try `make compare-rebuild`. Stale
build artifacts from a prior Flutter SDK can sometimes survive
`flutter clean`; `make distclean` removes the entire `macos/` platform
folder so it's regenerated from scratch.

**FPS lower in Chrome than expected** — Chrome on macOS clamps rAF to
60 Hz on most external displays even on 120 Hz laptops. The Flutter side
runs at the native ProMotion rate. This is a Chrome behavior, not a
benchmark bug. Compare p99 frame time and jank counts instead of raw
FPS for an apples-to-apples view of stability.
