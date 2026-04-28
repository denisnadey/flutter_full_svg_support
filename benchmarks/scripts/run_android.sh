#!/bin/bash
# Runs the full_svg_flutter benchmark suite on a connected Android device in profile mode.
#
# Usage:
#   ./scripts/run_android.sh [device_id]
#
# Prerequisites:
#   - A physical Android device connected via USB with USB debugging enabled
#   - adb in PATH (part of Android SDK platform-tools)
#   - Flutter SDK in PATH (flutter --version should work)
#   - Profile or release build only — debug mode is excluded (see methodology.md)
#
# Output:
#   results/android/<timestamp>/benchmark_results.json
#   reports/report.md  (regenerated after run)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RESULTS_DIR="$PROJECT_ROOT/results/android/$TIMESTAMP"
DEVICE_ID="${1:-}"

# ── Step 1: Verify Flutter is available ──────────────────────────────────────
echo "==> Checking Flutter installation..."
if ! command -v flutter &>/dev/null; then
  echo "ERROR: 'flutter' not found in PATH. Install Flutter SDK and add it to PATH."
  exit 1
fi
flutter --version

# ── Step 2: Verify adb is available and a device is connected ────────────────
echo ""
echo "==> Checking ADB and connected devices..."
if ! command -v adb &>/dev/null; then
  echo "ERROR: 'adb' not found in PATH. Install Android SDK platform-tools."
  exit 1
fi

if [ -z "$DEVICE_ID" ]; then
  DEVICE_COUNT=$(adb devices | tail -n +2 | grep -c "device$" || true)
  if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "ERROR: No Android devices detected. Connect a device and enable USB debugging."
    adb devices
    exit 1
  elif [ "$DEVICE_COUNT" -gt 1 ]; then
    echo "WARNING: Multiple devices detected. Pass a device ID as the first argument."
    echo "  Usage: ./scripts/run_android.sh <device_id>"
    echo ""
    adb devices
    echo ""
    echo "Proceeding with default device selection (adb will choose)..."
  fi
  DEVICE_FLAG=""
else
  DEVICE_FLAG="--device-id $DEVICE_ID"
  echo "Using device: $DEVICE_ID"
fi

# ── Step 3: Enter the benchmark app directory and get dependencies ────────────
BENCHMARK_APP_DIR="$PROJECT_ROOT/benchmark_app"
if [ ! -d "$BENCHMARK_APP_DIR" ]; then
  echo "ERROR: benchmark_app/ directory not found at $BENCHMARK_APP_DIR"
  echo "  Create the Flutter app first: flutter create --template=app benchmark_app"
  exit 1
fi

echo ""
echo "==> Running flutter pub get in benchmark_app/..."
cd "$BENCHMARK_APP_DIR"
flutter pub get

# ── Step 4: Run integration tests in profile mode ────────────────────────────
INTEGRATION_TEST="integration_test/benchmark_test.dart"
if [ ! -f "$INTEGRATION_TEST" ]; then
  echo "ERROR: Integration test not found at $INTEGRATION_TEST"
  echo "  Create it per the benchmark suite documentation."
  exit 1
fi

echo ""
echo "==> Running benchmarks on Android (profile mode)..."
echo "    This may take several minutes — each scenario runs for 5+ seconds."
echo ""

flutter test "$INTEGRATION_TEST" \
  --profile \
  ${DEVICE_FLAG} \
  --dart-define=BENCHMARK_MODE=true \
  --dart-define=TARGET_PLATFORM=android \
  --reporter=expanded \
  2>&1 | tee /tmp/flutter_benchmark_output.txt

# ── Step 5: Copy results to timestamped directory ────────────────────────────
echo ""
echo "==> Collecting results..."
mkdir -p "$RESULTS_DIR"

# The benchmark test should write results to a known location on device;
# pull them via adb if written to external storage, or read from stdout capture.
RESULT_FILE_ON_DEVICE="/sdcard/Download/benchmark_results.json"
if adb ${DEVICE_ID:+-s "$DEVICE_ID"} shell "[ -f $RESULT_FILE_ON_DEVICE ]" 2>/dev/null; then
  echo "    Pulling results from device..."
  adb ${DEVICE_ID:+-s "$DEVICE_ID"} pull "$RESULT_FILE_ON_DEVICE" \
    "$RESULTS_DIR/benchmark_results.json"
  echo "    Results saved to: $RESULTS_DIR/benchmark_results.json"
else
  echo "    NOTE: Result file not found on device at $RESULT_FILE_ON_DEVICE"
  echo "    If your benchmark test writes results elsewhere, adjust this script."
  echo "    Flutter test stdout captured at: /tmp/flutter_benchmark_output.txt"
  cp /tmp/flutter_benchmark_output.txt "$RESULTS_DIR/stdout.txt"
fi

# Copy device metadata
echo "==> Capturing device info..."
{
  echo "timestamp: $TIMESTAMP"
  echo "device_id: ${DEVICE_ID:-auto}"
  adb ${DEVICE_ID:+-s "$DEVICE_ID"} shell getprop ro.product.model 2>/dev/null \
    | xargs echo "model:" || true
  adb ${DEVICE_ID:+-s "$DEVICE_ID"} shell getprop ro.build.version.release 2>/dev/null \
    | xargs echo "android_version:" || true
  flutter --version 2>/dev/null | head -3 || true
} > "$RESULTS_DIR/device_info.txt"

echo "    Device info saved to: $RESULTS_DIR/device_info.txt"

# ── Step 6: Regenerate the report ────────────────────────────────────────────
echo ""
echo "==> Generating report..."
cd "$PROJECT_ROOT"
if command -v dart &>/dev/null; then
  dart run scripts/generate_report.dart results/
  echo "    Report generated: reports/report.md"
  echo "    HTML report:      reports/index.html"
  echo "    CSV summary:      reports/summary.csv"
else
  echo "    WARNING: 'dart' not in PATH — skipping report generation."
  echo "    Run manually: dart run scripts/generate_report.dart results/"
fi

echo ""
echo "==> Done. Results in: $RESULTS_DIR"
