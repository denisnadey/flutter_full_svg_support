# Benchmark Methodology

This document describes exactly how measurements in this suite are collected, why specific choices were made, and how to interpret the numbers. Reading this before comparing results across devices or packages is strongly recommended.

---

## 1. Measurement approach

Benchmarks are implemented as Flutter integration tests using the `integration_test` package. The core measurement mechanism is `WidgetsBinding.instance.addTimingsCallback`, which receives a `List<FrameTiming>` after each batch of frames is rendered and composited.

```dart
WidgetsBinding.instance.addTimingsCallback((timings) {
  for (final t in timings) {
    _buildDurations.add(t.buildDuration.inMicroseconds / 1000.0);
    _rasterDurations.add(t.rasterDuration.inMicroseconds / 1000.0);
  }
});
```

`FrameTiming` is a first-party Flutter API that captures per-frame timestamps recorded by the engine at the boundaries of each pipeline stage. It is accurate to microsecond resolution and does not require a connected profiler.

For first-paint measurement, a `Stopwatch` is started immediately before the widget is added to the tree and stopped in the first `addTimingsCallback` callback that fires after the widget insertion.

---

## 2. Why profile/release mode only

Flutter has three build modes:

| Mode | Compiler | Asserts | Observatory | Overhead |
|------|----------|---------|-------------|----------|
| Debug | JIT | Enabled | Enabled | 3–10x typical |
| Profile | AOT | Disabled | Limited | ~production |
| Release | AOT | Disabled | Disabled | Production |

**Debug mode is excluded** from this suite for two reasons:

1. **JIT compilation cost.** The Dart JIT compiler compiles hot methods during execution. This introduces unpredictable latency spikes in the first several seconds of execution that are not representative of shipped app behaviour.
2. **Assert and debug-overlay overhead.** Flutter's debug mode runs paint bounds checks, semantic tree assertions, and the debug overlay repaint rainbow. All of these add rendering work that disappears in production.

Profile mode is the standard choice for Flutter performance work: it compiles AOT (same as release), disables asserts, but retains the Dart VM service (timeline, heap snapshots). This allows both accurate measurement and post-hoc profiling.

Release mode produces the fastest binary but loses observability. The difference between profile and release is typically under 5% for rendering-heavy code.

---

## 3. Warm-up rules

A 2-second warm-up period precedes every measurement window. During warm-up:

- The SVG is rendered (and discarded for cold-load tests, or kept for warm-cache tests)
- Flutter's widget caching and Skia/Impeller shader compilation are allowed to settle
- `FrameTiming` callbacks are registered but data is discarded

**Why warm-up matters:**

- **Shader compilation.** On the first render of a new visual element, Impeller/Skia may compile a new shader program. This shows up as a large spike in `raster_ms` on the first frame only. Without warm-up, this one-time cost would inflate the average.
- **Dart VM JIT (profile mode note).** Even in profile mode, the Dart VM's background compiler may still be active for a short period after launch. 2 seconds is sufficient for most SVG widget codepaths to stabilise.
- **Flutter widget caching.** Some internal Flutter caches (e.g. `ParagraphBuilder`, layout caches for text) are populated lazily. The warm-up ensures steady-state behaviour is measured.

For **cold-load scenarios**, the cache is cleared *after* warm-up, immediately before the measurement window begins. This means the warm-up itself is a warm-cache run, and only the final measurement reflects cold-load performance.

---

## 4. Number of iterations and measurement window

Each scenario runs for a **5-second measurement window** after the warm-up period. The minimum acceptable sample count is **60 frames** (approximately 1 second at 60 Hz). If fewer than 60 frames are collected, the result is flagged as low-confidence.

For animated scenarios (spinner, heartbeat, etc.), the animation loop runs continuously during the measurement window. For static scenarios, the widget is held on screen and the measurement captures steady-state repaint behaviour (which should be near-zero build time at rest).

The 5-second window is chosen to:
- Capture at least one full animation cycle for all included animations (longest cycle: 6s orbit — measured over partial cycle, still statistically valid at 60+ samples)
- Stay within practical test run time while collecting enough frames for p99 to be meaningful (p99 requires at least 100 samples to be non-trivially estimated; at 60 Hz × 5s = 300 frames, p99 is estimated over the top 3 frames)

---

## 5. Frame timing breakdown

`FrameTiming` exposes three durations per frame:

| Field | Description |
|-------|-------------|
| `buildDuration` | Time the UI thread spent building the widget tree and computing layout for this frame |
| `rasterDuration` | Time the raster thread spent issuing GPU draw calls for this frame |
| `totalSpan` | Wall-clock duration from vsync signal to frame composited on screen |

In this suite:

- `avg_build_ms` = mean of `buildDuration` in ms over the measurement window
- `avg_raster_ms` = mean of `rasterDuration` in ms
- `p90_build_ms` = 90th percentile of `buildDuration`
- `p99_build_ms` = 99th percentile of `buildDuration`
- `first_paint_ms` = `totalSpan` of the first frame after widget insertion

Note: `buildDuration + rasterDuration` is not equal to `totalSpan`. The two threads run in a pipeline; a frame can begin rasterising while the next frame is being built. `totalSpan` includes OS scheduling, GPU driver latency, and display scanout delay.

---

## 6. Jank definition

A frame is classified as **janky** when its `buildDuration` exceeds the display's frame budget:

- **60 Hz display**: budget = 16.67 ms → jank if `buildDuration > 16.67ms`
- **90 Hz display**: budget = 11.11 ms → jank if `buildDuration > 11.11ms`
- **120 Hz display**: budget = 8.33 ms → jank if `buildDuration > 8.33ms`

The `jank_frame_count` metric uses the 60 Hz threshold (16.67 ms) as the default baseline to allow cross-device comparison, even on 120 Hz devices. The raw frame timings are always stored so the threshold can be recomputed.

Note: a frame can miss the budget due to raster thread overrun even if `buildDuration` is within budget. This suite tracks `buildDuration`-based jank separately. Raster-thread jank can be inferred from cases where `avg_raster_ms` is consistently high.

---

## 7. Cache clearing strategy

Two cache states are measured:

**Cold load (`cache_state: "cold"`):**
```dart
svg.cache.clear();       // full_svg_flutter SVG parse cache
PaintingBinding.instance.imageCache.clear();  // Flutter image cache
```
These are called immediately before the measurement widget is inserted. This simulates first-time navigation to a screen containing the SVG.

**Warm cache (`cache_state: "warm"`):**
No cache clearing. The SVG has already been parsed in a prior warm-up render. This simulates returning to a screen, or an SVG in a recycling list that has been scrolled off and back on.

The cache state is always recorded in the result JSON. Do not compare cold-load results to warm-cache results across packages without accounting for this.

---

## 8. Device thermal throttling

Modern mobile SoCs reduce CPU and GPU clock speeds when the die temperature exceeds a threshold (typically 85°C). This can reduce rendering throughput by 20–50% compared to cool-device baseline, and the effect is non-linear and device-specific.

**Recommendations to minimise thermal bias:**

1. Allow the device to idle for at least **5 minutes** at room temperature before starting a benchmark run.
2. Disable **Low Power Mode** on iOS (reduces CPU/GPU clocks).
3. Avoid running benchmarks while the device is charging (chargers generate additional heat).
4. Do not run the full suite in a tight loop without breaks — allow 30 seconds of idle between categories.
5. Note the ambient temperature and whether the device felt warm to the touch. Include this in the result JSON's `device_info` field if abnormal.
6. On Android, you can check thermal headroom: `adb shell dumpsys thermalservice` (requires API 29+).

Benchmark order within each category is **randomised** (see section 9) to prevent scenarios that run later always experiencing more throttling than earlier ones.

---

## 9. Benchmark order

Within each category, scenario order is randomised using a deterministic seed derived from the current date:

```dart
final rng = Random(DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000);
scenarios.shuffle(rng);
```

Using the date as a seed means:
- All packages experience the same order within a single day's run (fair comparison)
- The order changes day-to-day, so systematic bias from a fixed order is detected across runs
- The seed is logged in the result JSON so the order can be reconstructed

Cross-category order is fixed: static → animated → filters → text → real_world → unsupported → stress. Categories are not randomised because they have significantly different thermal profiles (stress tests are the hottest), and randomising them would make inter-category comparison harder.

---

## 10. Parser microbenchmark methodology

The `benchmark_runner/` package uses [`benchmark_harness`](https://pub.dev/packages/benchmark_harness)'s `BenchmarkBase` class, which implements the standard Dart microbenchmark protocol:

1. **Warm-up**: `exercise()` is called for 2 seconds; timing is discarded.
2. **Measurement**: `exercise()` is called repeatedly until 2 seconds of measurement wall time has elapsed.
3. **Result**: `score` = total measurement time (µs) / number of `exercise()` calls = **microseconds per iteration**.

This suite runs each parser benchmark **10 times** and reports the **median** score. Taking 10 runs and using the median reduces the effect of GC pauses, background JIT activity, and OS scheduling noise.

**What is measured in each parser benchmark:**

| Benchmark | What `exercise()` does |
|-----------|------------------------|
| `parse_simple_icon` | Parse `simple_icon.svg` string → SVG element tree |
| `parse_complex_path_1k` | Parse `complex_path_1k.svg` → element tree |
| `parse_gradients` | Parse `gradients.svg` → element tree |
| `parse_real_world` | Parse `real_world_illustration.svg` → element tree |
| `parse_animated_smil` | Parse `smil_spinner.svg` → element tree |
| `parse_css_keyframes` | Parse `css_keyframes.svg` → element tree + CSS |

Each `exercise()` call parses from the raw UTF-8 string — no file I/O is included. The benchmark measures pure parser throughput. Asset strings are loaded once before warm-up and held in memory.

---

## 11. Memory measurement limitations

Memory is measured using the Dart VM service:

```dart
final vm = await Service.getVM();
final heapUsage = vm.isolates.first.pauseEvent?.heapUsage;
```

This returns the **Dart heap** (young + old generation) occupied by live objects at the time of the snapshot. It does not include:

- **Skia/Impeller GPU resources**: texture memory, compiled shaders, path cache
- **Decoded image memory**: bitmaps held by the Flutter image cache in the raster thread
- **Native SVG parser memory**: any native-side allocations by platform channels
- **Flutter framework internal caches**: `ParagraphBuilder` caches, layer tree, etc.

The `memory_delta_mb` metric therefore represents a **lower bound** on actual memory impact. For a more complete picture, use Android's `adb shell dumpsys meminfo`, Instruments on iOS, or Xcode's memory graph debugger.

Memory snapshots are taken:
- **Baseline**: immediately after `await tester.pumpAndSettle()` before the SVG widget is inserted
- **Peak**: after the 5-second measurement window, after calling `await tester.pumpAndSettle()`
- **Delta**: `peak - baseline`

---

## 12. Raw data policy

All raw JSON result files are committed to the repository unchanged. Post-processing is done only in `generate_report.dart` for display purposes. Specifically:

- **No rounding** of raw values in the JSON — values are stored at full double precision
- **No outlier removal** — all frames are included in statistics
- **No normalisation** — results from different devices are not adjusted to a common baseline
- **Source file path** is recorded in each result — results can always be traced back to a specific run
- **The `_note` field** in result files is informational only and does not affect statistics

If a measurement was taken under non-standard conditions (e.g. device was warm, Low Power Mode was on), add a `"conditions_note"` field to the result JSON rather than modifying the measured values.

---

## 13. How to add new assets

1. **Naming convention**: `<category>/<descriptive_slug>.svg` in lowercase with underscores. The slug should describe what SVG feature is being tested, not the visual appearance.

   ```
   assets/filters/gaussian_blur_only.svg     ✓
   assets/filters/blurry_circle.svg          ✗ (describes appearance, not feature)
   ```

2. **Required header comment**: every SVG file must begin with:
   ```xml
   <!-- Source: <attribution> -->
   <!-- Tests: <one sentence describing the SVG feature being exercised> -->
   ```

3. **Attribution**: if the SVG is derived from a third-party source, the `Source:` line must include the licence and URL. Public domain or CC0 assets are preferred for assets committed to this repository.

4. **Browser validation**: render the SVG in Chrome before adding. If Chrome renders it incorrectly, the SVG has a bug. Do not add SVGs that rely on browser-specific quirks.

5. **Size constraints**: assets should be under 50 KB uncompressed. Larger assets require justification and must be in the `stress/` category.

6. **Update the README**: add the new scenario to the scenario table in `README.md`.

---

## 14. Avoiding benchmark gaming

This suite is designed to measure real production behaviour, not optimised benchmark paths. The following rules are enforced:

1. **No benchmark detection.** Packages are not informed they are being benchmarked. The `BENCHMARK_MODE=true` dart-define is used only by the test harness to control timing — it does not reach the SVG package code.

2. **Same code paths as production.** The benchmark app uses `full_svg_flutter` and `flutter_svg` through their public APIs exactly as a production app would. No internal methods, no `@visibleForTesting` hooks.

3. **No pre-warming of package internals.** Packages are not given additional warm-up beyond what the standard 2-second warm-up provides.

4. **No cherry-picking assets.** All assets in `assets/` are benchmarked. Assets are not excluded from results because they make a particular package look bad. Unsupported features are recorded as `"unsupported": true` rather than excluded.

5. **Reproducibility first.** If a result cannot be reproduced on the same device model within ±15%, it should be re-run and the outlier discarded with a note. If results are consistently non-reproducible, this indicates a thermal or environmental issue — do not publish those results without noting the instability.
