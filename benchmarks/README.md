# full_svg_flutter Benchmarks

Reproducible benchmark suite for [`full_svg_flutter`](https://pub.dev/packages/full_svg_flutter) — measuring performance, frame stability, memory behaviour, and SVG feature compatibility against `flutter_svg` and `vector_graphics`.

- Reproducible benchmarks
- Raw JSON results included
- Tested on real devices
- Compared against flutter_svg and vector_graphics modes
- Cold load / warm cache / animation frame stability measured

---

## What is measured

### 5 categories

| Category | Description |
|----------|-------------|
| **Static rendering** | Parse + first paint time for static SVG assets of varying complexity |
| **Animated SVG** | Per-frame build and raster times for SMIL, CSS keyframe, and path-morph animations |
| **Stress tests** | Grid layouts with 50+ simultaneous SVGs; large-path rendering; filter stacks |
| **Compatibility** | Feature support matrix — which SVG features render correctly vs fallback/blank |
| **Developer experience** | Parse error handling, hot reload stability (not a performance metric) |

### Metrics collected per scenario

| Metric | Unit | Description |
|--------|------|-------------|
| `first_paint_ms` | ms | Wall-clock time from widget insertion to first rasterised frame |
| `avg_build_ms` | ms | Mean UI-thread build duration across the measurement window |
| `p90_build_ms` | ms | 90th percentile build duration — typical slow frame |
| `p99_build_ms` | ms | 99th percentile build duration — worst-case jank indicator |
| `avg_raster_ms` | ms | Mean GPU/raster-thread duration |
| `jank_frame_count` | count | Frames exceeding 16.67ms build budget (60Hz) |
| `memory_delta_mb` | MB | Dart heap delta from before first load to steady state |
| `sample_count` | count | Number of frames measured |

---

## Why these metrics matter

### UI thread vs raster thread

Flutter separates work into two threads. `build_ms` measures the **UI thread** — time spent in Dart constructing the widget tree and computing layout. `raster_ms` measures the **raster thread** — time the GPU driver spends drawing commands on screen.

An SVG rendered as a `Picture` (vector commands replayed each frame) is cheap in memory but can have high `raster_ms` for complex paths. An SVG pre-rasterised to a `Bitmap` pays a one-time cost at load (high `first_paint_ms` and high `memory_delta_mb`) but then has near-zero `raster_ms` each frame. This tradeoff is the core reason `full_svg_flutter` exposes both rendering strategies.

### Why p99 matters more than average FPS

The human eye detects dropped frames, not average frame rate. A benchmark that reports "60 FPS average" can hide the fact that every 5 seconds a single 100ms frame occurs — which users experience as a visible stutter. p99 build time captures this: if p99 > 16.67ms, roughly 1% of frames are jank at 60Hz. At 120Hz, the budget halves to 8.33ms.

### Why debug mode is excluded

Flutter's debug build runs with the JIT compiler, enabling hot reload and assert-level checks. Both impose 3–10x overhead on typical widget code. Benchmarks in debug mode measure the Flutter framework itself, not your rendering code. This suite requires **profile** or **release** builds only. Profile mode is preferred because it retains the timeline profiler without assert overhead.

---

## How to reproduce locally

### Prerequisites

- Flutter >=3.32.0 (`flutter --version`)
- A physical Android device, a physical iOS device, or a macOS desktop
- Profile or release build mode (debug mode excluded — see [methodology.md](methodology.md))
- Dart SDK in PATH (bundled with Flutter)

### Quick start

```bash
git clone <this-repo-url>
cd full_svg_flutter_benchmarks

# Android
./scripts/run_android.sh

# iOS (real device only — see note in script)
./scripts/run_ios.sh

# macOS desktop
./scripts/run_macos.sh

# Pure Dart parser microbenchmarks (no device needed)
./scripts/run_parser_benchmarks.sh

# Regenerate reports from existing JSON results
dart run scripts/generate_report.dart
```

### Running on Android

```bash
./scripts/run_android.sh [device_id]
```

- Connects to a physical Android device via ADB
- Runs `flutter test integration_test/benchmark_test.dart --profile`
- Copies results to `results/android/<timestamp>/`
- Regenerates `reports/report.md`, `reports/index.html`, `reports/summary.csv`

To find your device ID: `adb devices`

### Running on iOS

```bash
./scripts/run_ios.sh [device_id]
```

> iOS Simulator gives inaccurate GPU results — the script warns and recommends a real device. Metal GPU scheduling and Impeller behaviour differ substantially between Simulator and device hardware.

To find your device ID: `flutter devices`

### Running on macOS

```bash
./scripts/run_macos.sh
```

Requires macOS desktop support to be enabled:

```bash
flutter config --enable-macos-desktop
```

Note: macOS results (Metal, x86_64 or Apple Silicon) are not representative of iOS or Android due to different GPU architectures, driver behaviour, and the absence of mobile thermal constraints.

### Running parser microbenchmarks

```bash
./scripts/run_parser_benchmarks.sh
```

Runs pure Dart microbenchmarks in `benchmark_runner/` using `benchmark_harness`. No Flutter or device needed. Measures SVG parse time, DOM construction, CSS tokenization, and path data throughput per package. See [methodology.md](methodology.md) for details.

### Generating the report

```bash
dart run scripts/generate_report.dart [results_dir]
```

Reads all `*.json` files from `results/` (skipping `results/example/`), computes per-scenario statistics, and writes:

- `reports/report.md` — Markdown with summary table and per-category breakdown
- `reports/index.html` — Standalone dark-theme HTML with Chart.js bar charts
- `reports/summary.csv` — CSV with all raw metrics for import into spreadsheets

---

## Interpreting results

### Build time = UI thread work

`avg_build_ms` and the percentiles measure how long Flutter's UI thread was blocked constructing and laying out the SVG widget. High build times cause dropped frames regardless of GPU speed. Animated SVGs that rebuild every frame are especially sensitive to this.

### Raster time = GPU work

`avg_raster_ms` measures GPU driver time. Complex SVG filters (`feGaussianBlur`, `feColorMatrix`), large path counts, and opacity-composited layers all increase raster time. The picture rendering mode replays vector commands every frame; the raster mode uploads a pre-baked bitmap.

### Frame budget

| Refresh rate | Budget per frame |
|-------------|-----------------|
| 60 Hz | 16.67 ms |
| 90 Hz | 11.11 ms |
| 120 Hz | 8.33 ms |

A frame exceeds budget if `build_ms + raster_ms > budget`. Flutter counts these as "janky frames" in the timeline. This benchmark counts frames where `build_ms > budget` separately from `raster_ms > budget` to isolate the bottleneck.

### Cold vs warm cache

| State | Description |
|-------|-------------|
| `cold` | SVG string not yet parsed; `svg.cache.clear()` called before measurement |
| `warm` | SVG already parsed and in memory cache; measures steady-state rendering cost |

Cold load is what users experience on first navigation. Warm cache is what matters for repeated render / list scroll scenarios.

### Picture vs raster rendering strategy

`full_svg_flutter` supports two rendering strategies:

- **Picture**: SVG is compiled to a `Picture` (Flutter vector drawing commands) and replayed each frame. Fast first paint, low memory, higher raster cost at frame time for complex SVGs.
- **Raster**: SVG is pre-rendered to a `ui.Image` (bitmap) at parse time. Slow first paint, high memory, near-zero raster cost per frame. Best for complex static SVGs used in lists.

---

## Benchmark scenarios

| # | Scenario | Category | Asset | Cache |
|---|----------|----------|-------|-------|
| 1 | `static_simple_icon` | static | `assets/simple/simple_icon.svg` | cold |
| 2 | `static_simple_shapes` | static | `assets/simple/simple_shapes.svg` | cold |
| 3 | `static_gradients_warm` | static | `assets/complex/gradients.svg` | warm |
| 4 | `static_gradients_cold` | static | `assets/complex/gradients.svg` | cold |
| 5 | `static_masks_clips` | static | `assets/complex/masks_clips.svg` | cold |
| 6 | `static_path_1k` | static | `assets/complex/complex_path_1k.svg` | cold |
| 7 | `static_real_world` | real_world | `assets/real_world/real_world_illustration.svg` | cold |
| 8 | `static_real_world_warm` | real_world | `assets/real_world/real_world_illustration.svg` | warm |
| 9 | `animated_smil_spinner` | animated | `assets/animated/smil_spinner.svg` | warm |
| 10 | `animated_dash_heartbeat` | animated | `assets/animated/dash_heartbeat.svg` | warm |
| 11 | `animated_path_morph` | animated | `assets/animated/path_morph.svg` | warm |
| 12 | `animated_transform` | animated | `assets/animated/animate_transform.svg` | warm |
| 13 | `animated_motion` | animated | `assets/animated/animate_motion.svg` | warm |
| 14 | `animated_css_keyframes` | animated | `assets/animated/css_keyframes.svg` | warm |
| 15 | `filter_stack_cold` | filters | `assets/filters/filter_stack.svg` | cold |
| 16 | `filter_drop_shadow` | filters | `assets/filters/drop_shadow.svg` | warm |
| 17 | `text_path` | text | `assets/text/text_path.svg` | cold |
| 18 | `text_complex` | text | `assets/text/complex_text.svg` | cold |
| 19 | `compat_smil_complex` | unsupported | `assets/unsupported_by_flutter_svg/smil_complex.svg` | warm |
| 20 | `compat_css_keyframes` | unsupported | `assets/unsupported_by_flutter_svg/css_keyframes_anim.svg` | warm |
| 21 | `compat_path_morphing` | unsupported | `assets/unsupported_by_flutter_svg/path_morphing.svg` | warm |
| 22 | `stress_grid_50` | stress | _(50x simple_icon in a GridView)_ | warm |
| 23 | `stress_grid_animated` | stress | _(20x smil_spinner in a ListView)_ | warm |
| 24 | `stress_filter_stack` | stress | _(10x filter_stack in a Column)_ | warm |
| 25 | `mega_stress_galactic_storm` | mega_stress | `assets/stress/galactic_storm.svg` | warm |

---

## Galactic Storm — the mega stress test

A single SVG asset designed to exercise **every** advanced feature
`full_svg_flutter` supports, simultaneously. **Everything moves** — there
isn't a single static element. All long animations use cubic-bezier
`calcMode="spline"` easing for buttery-smooth motion. Generated by
[`tool/generate_galactic_storm.dart`](tool/generate_galactic_storm.dart) and
saved to [`assets/stress/galactic_storm.svg`](assets/stress/galactic_storm.svg)
(~317 KB, deterministic seed=42).

**What's inside one file:**

| Layer | Count | Motion | Other features |
|-------|------:|--------|----------------|
| Distant stars | 500 | drift translate (unique vectors per star) + opacity twinkle | spline easing, staggered `begin` |
| Bright stars | 100 | orbital `animateMotion` + cross-rays rotation + pulse | radial gradients, glow filter |
| Floating particles | 50 | long-range `animateMotion` along curves + opacity keyTimes | glow filter |
| Nebula clouds | 30 | animated `rx`/`ry` + slow rotation | `feGaussianBlur` (big) |
| Morphing crystals | 10 | drift translate + path `d`-morph + rotation | spline easing, opacity cycle |
| Streaking comets | 10 | `animateMotion` + animated radius | glow filter |
| Galactic core | 1 | rotating rings + accretion disk morph | animated `stop-color` + `stop-offset`, drop-shadow filter |
| Arc text | 1 | skewY twist + letter-spacing pulse + `fill` cycle | `<textPath>`, glow |
| Flying twisting text | 1 | skewX twist + scrolling `startOffset` + font-size pulse + colour cycle | `<textPath>` on a **morphing** curve |
| CSS-animated shapes | 5 | `@keyframes` (pulse / spin / drift) | `transform-box: fill-box` |
| Cosmic background | 1 | animated `stop-color` on both gradient stops | `<linearGradient>` |

**Total**: ~3,070 elements · **854 `<animate>`** · **653 `<animateTransform>`** · **160 `<animateMotion>`** = **1,667 concurrent animations** on a single render tree.

```bash
# Regenerate the SVG (deterministic, seeded):
./.fvm/flutter_sdk/bin/dart run benchmarks/tool/generate_galactic_storm.dart

# View it interactively:
cd benchmarks/benchmark_app && flutter run --profile
# → tap "Galactic Storm — Mega Stress"

# Benchmark it (30s warmup + 30s measurement window):
./benchmarks/scripts/run_macos.sh
# scenario: mega_stress_galactic_storm
```

**Why 30 seconds?** Animation periods range from 1.5 s (star pulses) to 22 s
(core ring rotation). A 30 s sample captures at least one full cycle of
every animation, which surfaces real GC pauses and worst-case raster spikes
that shorter windows would miss.

**flutter_svg comparison.** `flutter_svg` cannot animate this asset —
it has no SMIL, CSS `@keyframes`, path morphing, `animateMotion`, or
animated gradient stops. The `mega_stress_galactic_storm — flutter_svg`
result captures parse cost + a single static frame for honesty's sake;
the visual side-by-side in the **Galactic Storm — Mega Stress** screen
shows the difference at a glance.

---

## Compatibility matrix

| SVG Feature | Chrome | flutter_svg | full_svg_flutter |
|-------------|--------|-------------|------------------|
| Basic shapes (rect, circle, ellipse, line, polygon) | Yes | Yes | Yes |
| `<path>` with cubic/quadratic bezier | Yes | Yes | Yes |
| `<linearGradient>` / `<radialGradient>` | Yes | Yes | Yes |
| `<clipPath>` | Yes | Yes | Yes |
| `<mask>` | Yes | Partial | Yes |
| `feGaussianBlur` | Yes | Partial | Yes |
| `feColorMatrix` | Yes | No | Yes |
| `feComposite` | Yes | No | Yes |
| `feDropShadow` | Yes | Partial | Yes |
| `<textPath>` | Yes | Partial | Yes |
| `<tspan>` | Yes | Partial | Yes |
| SMIL `<animate>` | Yes | No | Yes |
| SMIL `<animateTransform>` | Yes | No | Yes |
| SMIL `<animateMotion>` + `<mpath>` | Yes | No | Yes |
| SMIL `<set>` | Yes | No | Yes |
| CSS `@keyframes` + `animation:` | Yes | No | Yes |
| CSS `transform-origin` | Yes | No | Yes |
| `<animate attributeName="d">` (path morphing) | Yes | No | Yes |
| `stroke-dashoffset` animation | Yes | No | Yes |
| `writing-mode: tb` | Yes | No | Partial |

---

## Limitations

- **Simulator / emulator results are not representative** of real-device GPU performance. iOS Simulator uses CPU-based rendering; Android emulator GPU behaviour differs from Mali/Adreno hardware. Always use physical devices for meaningful results.
- **macOS results differ from iOS/Android** due to Metal GPU architecture differences, the absence of mobile Impeller on macOS, and the absence of thermal throttling on desktop hardware.
- **Thermal throttling** on mobile devices can reduce GPU clock speeds mid-benchmark. The scripts recommend running after 5 minutes of idle and warn about Low Power Mode. See [methodology.md](methodology.md).
- **This suite does not cover every real-world SVG.** Results are specific to the included assets. SVGs with unusual path topologies, very large element counts, or non-standard attribute combinations may behave differently.
- **Memory measurements are Dart heap only.** Native-side allocations (Skia/Impeller GPU resources, decoded bitmap memory in the raster thread) are not captured by `Service.getVM()`. The `memory_delta_mb` metric is a lower bound.
- **Parser benchmarks use JIT Dart.** The microbenchmarks in `benchmark_runner/` run under JIT, not AOT. Parse time in a shipped Flutter app (AOT) may differ. This is a known limitation; the benchmarks serve as relative comparisons between packages, not absolute production measurements.

---

## Contributing

### Adding new SVG assets

1. Place the file in the appropriate `assets/<category>/` subdirectory.
2. Include the header comment: `<!-- Source: <attribution or "generated for full_svg_flutter benchmarks"> -->`
3. Verify the SVG renders correctly in a browser before adding.
4. Add a corresponding scenario entry to `benchmark_app/integration_test/benchmark_test.dart`.
5. Update the scenario table in this README.

### Adding new benchmark scenarios

1. Add the scenario in `benchmark_app/integration_test/benchmark_test.dart` following the existing pattern.
2. The scenario name must be lowercase with underscores and match what is written to the result JSON.
3. Document the scenario in the table above.

### Submitting device results

1. Run the appropriate script on a physical device in profile mode.
2. Verify the output JSON in `results/<platform>/<timestamp>/` looks correct.
3. Open a PR with the JSON file added and a brief description of the device (model, OS version, Flutter version, renderer mode).
4. Do not modify raw JSON values — see the raw data policy in [methodology.md](methodology.md).

---

## License

MIT — see [LICENSE](LICENSE) for details.
