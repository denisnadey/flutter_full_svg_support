#!/bin/bash
# Runs the full_svg_flutter benchmark suite on macOS desktop in profile mode.
#
# Usage:
#   ./scripts/run_macos.sh
#
# Prerequisites:
#   - macOS 12+ (Monterey or later recommended for Metal / Impeller)
#   - Flutter SDK in PATH with macOS desktop support enabled
#     (run: flutter config --enable-macos-desktop)
#   - Xcode installed
#
# Note: macOS Metal rendering differs from iOS Metal/Impeller and Android
# Impeller/Skia. macOS benchmark results are useful for macOS app performance
# but should not be used to extrapolate iOS or Android numbers.
# See methodology.md for details.
#
# Output:
#   results/macos/<timestamp>/benchmark_results.json
#   reports/report.md  (regenerated after run)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RESULTS_DIR="$PROJECT_ROOT/results/macos/$TIMESTAMP"

# ── Step 1: Verify Flutter + macOS desktop support ───────────────────────────
echo "==> Checking Flutter installation..."
if ! command -v flutter &>/dev/null; then
  echo "ERROR: 'flutter' not found in PATH."
  exit 1
fi
flutter --version

echo ""
echo "==> Verifying macOS desktop target is enabled..."
if ! flutter config 2>/dev/null | grep -q "enable-macos-desktop: true"; then
  echo "    macOS desktop not enabled. Enabling now..."
  flutter config --enable-macos-desktop
fi

# ── Step 2: Check macOS is available as a Flutter device ─────────────────────
echo ""
echo "==> Checking available devices..."
if ! flutter devices 2>/dev/null | grep -qi "macos"; then
  echo "ERROR: macOS device not found in flutter devices."
  echo "  Ensure macOS desktop support is enabled:"
  echo "    flutter config --enable-macos-desktop"
  flutter devices
  exit 1
fi

# ── Step 3: flutter pub get ───────────────────────────────────────────────────
BENCHMARK_APP_DIR="$PROJECT_ROOT/benchmark_app"
if [ ! -d "$BENCHMARK_APP_DIR" ]; then
  echo "ERROR: benchmark_app/ directory not found."
  exit 1
fi

echo ""
echo "==> Running flutter pub get..."
cd "$BENCHMARK_APP_DIR"
flutter pub get

# ── Step 4: Run integration tests against macOS target ───────────────────────
INTEGRATION_TEST="integration_test/benchmark_test.dart"
if [ ! -f "$INTEGRATION_TEST" ]; then
  echo "ERROR: Integration test not found: $INTEGRATION_TEST"
  exit 1
fi

echo ""
echo "==> Running benchmarks on macOS (profile mode)..."
echo "    Close other GPU-intensive applications before running."
echo ""

flutter test "$INTEGRATION_TEST" \
  --profile \
  -d macos \
  --dart-define=BENCHMARK_MODE=true \
  --dart-define=TARGET_PLATFORM=macos \
  --reporter=expanded \
  2>&1 | tee /tmp/flutter_benchmark_macos_output.txt

# ── Step 5: Collect results ───────────────────────────────────────────────────
echo ""
echo "==> Collecting results..."
mkdir -p "$RESULTS_DIR"

cp /tmp/flutter_benchmark_macos_output.txt "$RESULTS_DIR/stdout.txt"

echo "==> Capturing system info..."
{
  echo "timestamp: $TIMESTAMP"
  echo "platform: macos"
  sw_vers 2>/dev/null || true
  sysctl -n machdep.cpu.brand_string 2>/dev/null | xargs echo "cpu:" || true
  flutter --version 2>/dev/null | head -3 || true
} > "$RESULTS_DIR/device_info.txt"

echo "    Device info: $RESULTS_DIR/device_info.txt"
echo "    Stdout log:  $RESULTS_DIR/stdout.txt"

# ── Step 6: Regenerate the report ────────────────────────────────────────────
echo ""
echo "==> Generating report..."
cd "$PROJECT_ROOT"
if command -v dart &>/dev/null; then
  dart run scripts/generate_report.dart results/
  echo "    Report: reports/report.md  |  reports/index.html  |  reports/summary.csv"
else
  echo "    WARNING: 'dart' not in PATH. Run: dart run scripts/generate_report.dart results/"
fi

echo ""
echo "==> Done. Results in: $RESULTS_DIR"
