# Galactic Storm — Side-by-Side Recording

Recorded **60s** · 2026-04-29T17:43:46

Asset under test: [`assets/stress/galactic_storm.svg`](../../assets/stress/galactic_storm.svg) — **3,074 elements**, **1,667 concurrent animations**.

## Highlight clips

_12s @ 12fps starting at 8s into the recording._

| full_svg_flutter (release, native macOS) | Chrome (native Blink) |
|---|---|
| ![flutter](flutter_12s.gif) | ![chrome](chrome_12s.gif) |

Full-length captures: [`flutter.mp4`](flutter.mp4) · [`chrome.mp4`](chrome.mp4)

## Metrics over the full window

| Metric                | full_svg_flutter | Chrome     | Δ (flutter − chrome) |
|---                    |              ---:|        ---:|                  ---:|
| Avg FPS               |             36.2 |       30.1 | +6.1                |
| Frame count           |             2175 |       1809 | +366                  |
| p50 frame ms          |            33.13 |       33.4 | -0.27                 |
| p90 frame ms          |            36.21 |       41.8 | -5.59                 |
| p99 frame ms          |            38.48 |       50.1 | -11.62                 |
| Max frame ms          |           107.02 |       58.4 | +48.62                 |
| Jank frames (>16.67ms)|             2174 |       1791 | +383                  |
| Jank frames (>8.33ms) |             2175 |       1805 | +370                  |

### Build vs raster split (full_svg_flutter only)

| Phase     | avg | p50 | p90 | p99 | max |
|---        | ---:| ---:| ---:| ---:| ---:|
| build_ms  | 27.96 | 28.08 | 29.23 | 30.71 | 83.43 |
| raster_ms | 5.46 | 6.06 | 7.62 | 8.75 | 23.59 |

---

Raw data: `flutter_metrics.jsonl`, `chrome_metrics.jsonl`, `summary.json`.

**Note on FPS parity.** Chrome on macOS often clamps `requestAnimationFrame`
to 60 Hz on external displays, even on ProMotion laptops. The Flutter side
runs at native refresh. Compare **p99 frame time** and **jank counts** for
an apples-to-apples view of stability rather than raw FPS.
