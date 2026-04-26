# W3C SVG 1.1 Test Suite in This Repository

## What Is This

`W3C_SVG_11_TestSuite` is the official SVG 1.1 (2nd Edition) test suite from the W3C.
It is designed to verify that a renderer conforms to the specification: geometry, gradients, filters, text, animations, masks, `use`, DOM/scripts, etc.

In this copy we have:

- `W3C_SVG_11_TestSuite/svg` — source SVG tests (525 files)
- `W3C_SVG_11_TestSuite/png` — reference PNGs (544 files)
- `W3C_SVG_11_TestSuite/harness/*` — HTML wrappers for running tests in a browser
- `W3C_SVG_11_TestSuite/resources/*` — fonts and auxiliary resources

From the `harness` you can see:

- All tests: 526 (`harness/htmlObject/index.html`)
- Approved subset: 433 (`harness/htmlObjectApproved/index.html`)
- The `harness/index.html` indicates the suite date: **15 Jul 2011**

## Why This Is Useful for Our Project

Your current scenario compares screenshots of the **Flutter SVG renderer** with the **browser renderer**.
This suite is a perfect large source of real spec-compliant cases for such a comparison.

What the suite provides:

- Wide coverage of edge cases not found in hand-made fixtures
- Consistent case names and categories (`coords`, `filters`, `masking`, `text`, `animate`, ...)
- Ready-made reference PNGs (can be used as an additional oracle)
- Metadata in each SVG: `testDescription`, `passCriteria`, `operatorScript`

## Important Constraints Before Integration

- The current `tool/golden_capture/capture.js` embeds SVG inline via `page.setContent(...)`.
- For W3C this is a risk: many tests use relative references (`../resources/...`, `../images/...`), and inline mode breaks the base path.
- Text tests will be unstable in the Flutter test environment due to the Ahem font (this is already reflected in the current golden tests).
- Tests with `script`/DOM-events/interaction are poorly suited for a stable headless baseline.
- For animations you need to fix the timestamp (e.g., `0ms` or a specific moment), otherwise the result is non-deterministic.

Additionally, regarding the local copy:

- `W3C_SVG_11_TestSuite/status` is absent
- `W3C_SVG_11_TestSuite/archives` is absent
- `harness/*` references `../resources/testharnessreport.js`, but `harness/resources` is not present in the copy

This does not prevent using `svg` and `png` for our purposes, but is important when trying to run the original harness as-is.

## How to Use in Our Screenshot Testing

Recommended approach:

1. Take cases from `harness/htmlObjectApproved/index.html` as the starting set.
2. Render them in Chrome/Puppeteer via a local HTTP server (not inline), so that relative resources work.
3. Store browser baselines in a separate namespace, e.g. `test/goldens/w3c/browser/`.
4. Render the same SVGs via Flutter (`AnimatedSvgPicture.string`) into `test/goldens/w3c/flutter/`.
5. Compare using the existing `tool/golden_capture/image_compare.dart` and write diffs to `test/goldens/w3c/diff/`.
6. Maintain an explicit case manifest (threshold, skip reason, category, CI tier).

## Quick Manual Browse of the Suite

```bash
cd /Users/denisnadey/apps/flutter_full_svg_support
python3 -m http.server 8000
```

Open in a browser:

- `http://localhost:8000/W3C_SVG_11_TestSuite/harness/index.html`
- or a specific test, e.g. `.../harness/htmlObjectApproved/coords-trans-01-b.html`

## What to Read Next

The detailed step-by-step integration plan is saved in:

- `W3C_SVG_11_TestSuite_PLAN_README.md`

The current working tooling implementation is in:

- `tool/w3c_goldens/README.md`
