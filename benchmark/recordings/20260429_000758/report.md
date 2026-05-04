# Galactic Storm — Side-by-Side Recording

Recorded **60s** · 2026-04-29T00:09:42

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
| Avg FPS               |             36.3 |       29.9 | +6.4                |
| Frame count           |             2177 |       1792 | +385                  |
| p50 frame ms          |            33.29 |       33.4 | -0.11                 |
| p90 frame ms          |            36.06 |       41.8 | -5.74                 |
| p99 frame ms          |            38.15 |       50.1 | -11.95                 |
| Max frame ms          |           108.31 |      117.6 | -9.29                 |
| Jank frames (>16.67ms)|             2176 |       1780 | +396                  |
| Jank frames (>8.33ms) |             2177 |       1791 | +386                  |

### Build vs raster split (full_svg_flutter only)

| Phase     | avg | p50 | p90 | p99 | max |
|---        | ---:| ---:| ---:| ---:| ---:|
| build_ms  | 27.97 | 28.1 | 29.17 | 30.53 | 81.1 |
| raster_ms | 5.44 | 6.05 | 7.58 | 8.55 | 40.67 |

---

Raw data: `flutter_metrics.jsonl`, `chrome_metrics.jsonl`, `summary.json`.

**Note on FPS parity.** Chrome on macOS often clamps `requestAnimationFrame`
to 60 Hz on external displays, even on ProMotion laptops. The Flutter side
runs at native refresh. Compare **p99 frame time** and **jank counts** for
an apples-to-apples view of stability rather than raw FPS.
