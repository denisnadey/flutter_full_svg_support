#!/bin/bash
# Runs the full_svg_flutter benchmark suite on a connected iOS device in profile mode.
#
# Usage:
#   ./scripts/run_ios.sh [device_id]
#
# Prerequisites:
#   - A physical iOS device connected via USB and trusted on this Mac
#   - Xcode and the iOS SDK installed (xcode-select --install)
#   - Flutter SDK in PATH
#   - Code signing configured in benchmark_app/ios/Runner.xcworkspace
#
# IMPORTANT: iOS Simulator results are NOT representative of real-device GPU
# performance. Metal GPU scheduling, Impeller behaviour, and memory pressure
# all differ significantly between Simulator and device. Always use a real
# device for iOS benchmarks. See methodology.md for details.
#
# Output:
#   results/ios/<timestamp>/benchmark_results.json
#   reports/report.md  (regenerated after run)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RESULTS_DIR="$PROJECT_ROOT/results/ios/$TIMESTAMP"
DEVICE_ID="${1:-}"

# ── Step 1: Verify Flutter is available ──────────────────────────────────────
echo "==> Checking Flutter installation..."
if ! command -v flutter &>/dev/null; then
  echo "ERROR: 'flutter' not found in PATH."
  exit 1
fi
flutter --version

# ── Step 2: Verify a real iOS device is connected (not simulator) ─────────────
echo ""
echo "==> Checking connected iOS devices..."
DEVICE_LIST=$(flutter devices 2>/dev/null | grep "ios" || true)
if [ -z "$DEVICE_LIST" ]; then
  echo "ERROR: No iOS devices detected."
  echo "  Connect a physical iPhone/iPad, trust this computer, and retry."
  echo ""
  flutter devices
  exit 1
fi

# Warn if only simulators are present
if echo "$DEVICE_LIST" | grep -qi "simulator"; then
  echo "WARNING: iOS Simulator detected. Simulator benchmarks are not representative"
  echo "         of real device GPU performance. Use a physical device."
  echo ""
fi

echo "$DEVICE_LIST"

if [ -z "$DEVICE_ID" ]; then
  DEVICE_FLAG=""
  echo "No device ID specified — Flutter will use the first available iOS device."
else
  DEVICE_FLAG="--device-id $DEVICE_ID"
  echo "Using device: $DEVICE_ID"
fi

# ── Step 3: Enter the benchmark app directory and get dependencies ────────────
BENCHMARK_APP_DIR="$PROJECT_ROOT/benchmark_app"
if [ ! -d "$BENCHMARK_APP_DIR" ]; then
  echo "ERROR: benchmark_app/ directory not found."
  exit 1
fi

echo ""
echo "==> Running flutter pub get..."
cd "$BENCHMARK_APP_DIR"
flutter pub get

# ── Step 4: Run integration tests in profile mode ────────────────────────────
INTEGRATION_TEST="integration_test/benchmark_test.dart"
if [ ! -f "$INTEGRATION_TEST" ]; then
  echo "ERROR: Integration test not found: $INTEGRATION_TEST"
  exit 1
fi

echo ""
echo "==> Running benchmarks on iOS (profile mode)..."
echo "    Tip: ensure the device is not in Low Power Mode and has cooled down"
echo "    before running — thermal throttling affects GPU performance."
echo "    See methodology.md: 'Device thermal throttling' section."
echo ""

flutter test "$INTEGRATION_TEST" \
  --profile \
  ${DEVICE_FLAG} \
  --dart-define=BENCHMARK_MODE=true \
  --dart-define=TARGET_PLATFORM=ios \
  --reporter=expanded \
  2>&1 | tee /tmp/flutter_benchmark_ios_output.txt

# ── Step 5: Collect results ───────────────────────────────────────────────────
echo ""
echo "==> Collecting results..."
mkdir -p "$RESULTS_DIR"

# iOS benchmark test should write results to the app's Documents directory;
# they can be retrieved via Instruments or the test framework stdout.
# If using flutter_test with file output, adjust the path below.
CAPTURED_OUTPUT="/tmp/flutter_benchmark_ios_output.txt"
cp "$CAPTURED_OUTPUT" "$RESULTS_DIR/stdout.txt"

# Device metadata via flutter
echo "==> Capturing device info..."
{
  echo "timestamp: $TIMESTAMP"
  echo "device_id: ${DEVICE_ID:-auto}"
  flutter devices 2>/dev/null | grep -i "ios" | head -5 || true
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
