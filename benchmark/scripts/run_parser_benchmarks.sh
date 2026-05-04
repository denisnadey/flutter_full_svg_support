#!/bin/bash
# Runs pure Dart parser microbenchmarks — no Flutter or device needed.
#
# Usage:
#   ./scripts/run_parser_benchmarks.sh
#
# Prerequisites:
#   - Dart SDK in PATH (comes with Flutter; or install standalone Dart SDK)
#   - benchmark_runner/ directory with a Dart package using benchmark_harness
#
# What this measures:
#   - SVG parse time per asset (microseconds per iteration, 10-run median)
#   - DOM tree construction time
#   - CSS parsing time (for SVG with embedded <style> blocks)
#   - Path data tokenization throughput
#   - Comparison: full_svg_flutter parser vs flutter_svg parser
#
# See methodology.md: 'Parser microbenchmark methodology' section.
#
# Output:
#   results/parser/benchmark_results.txt
#   results/parser/benchmark_results.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
PARSER_RESULTS_DIR="$PROJECT_ROOT/results/parser/$TIMESTAMP"

# ── Step 1: Verify Dart is available ─────────────────────────────────────────
echo "==> Checking Dart installation..."
if ! command -v dart &>/dev/null; then
  echo "ERROR: 'dart' not found in PATH."
  echo "  Dart comes bundled with Flutter SDK (add <flutter>/bin to PATH),"
  echo "  or install the standalone Dart SDK from https://dart.dev/get-dart"
  exit 1
fi
dart --version

# ── Step 2: Check benchmark_runner package exists ────────────────────────────
RUNNER_DIR="$PROJECT_ROOT/benchmark_runner"
if [ ! -d "$RUNNER_DIR" ]; then
  echo "ERROR: benchmark_runner/ directory not found at $RUNNER_DIR"
  echo "  Create it with:"
  echo "    mkdir benchmark_runner && cd benchmark_runner"
  echo "    dart create --template=package-simple ."
  echo "  Then add benchmark_harness to pubspec.yaml and write bin/run_benchmarks.dart"
  exit 1
fi

if [ ! -f "$RUNNER_DIR/pubspec.yaml" ]; then
  echo "ERROR: No pubspec.yaml in benchmark_runner/"
  exit 1
fi

BENCHMARK_ENTRY="$RUNNER_DIR/bin/run_benchmarks.dart"
if [ ! -f "$BENCHMARK_ENTRY" ]; then
  echo "ERROR: Benchmark entry point not found: $BENCHMARK_ENTRY"
  exit 1
fi

# ── Step 3: Get dependencies ──────────────────────────────────────────────────
echo ""
echo "==> Running dart pub get in benchmark_runner/..."
cd "$RUNNER_DIR"
dart pub get

# ── Step 4: Run the microbenchmarks ──────────────────────────────────────────
echo ""
echo "==> Running parser microbenchmarks..."
echo "    Each benchmark runs for ~10 iterations; results in microseconds/iteration."
echo "    Warmup: 2 seconds JIT warmup before measurement window."
echo ""

mkdir -p "$PARSER_RESULTS_DIR"

dart run bin/run_benchmarks.dart \
  --assets-dir "$PROJECT_ROOT/assets" \
  --output-json "$PARSER_RESULTS_DIR/benchmark_results.json" \
  2>&1 | tee "$PARSER_RESULTS_DIR/stdout.txt"

echo ""
echo "==> Parser benchmark results:"
echo "    JSON:   $PARSER_RESULTS_DIR/benchmark_results.json"
echo "    stdout: $PARSER_RESULTS_DIR/stdout.txt"

# ── Step 5: Quick summary ─────────────────────────────────────────────────────
if [ -f "$PARSER_RESULTS_DIR/benchmark_results.json" ]; then
  echo ""
  echo "==> Top results (median µs/iter):"
  if command -v python3 &>/dev/null; then
    python3 - "$PARSER_RESULTS_DIR/benchmark_results.json" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
results = data.get("results", [])
results.sort(key=lambda r: r.get("median_us", 0))
for r in results[:10]:
    print(f"  {r.get('name','?'):50s}  {r.get('median_us', '?'):>8} µs/iter")
PYEOF
  fi
fi

echo ""
echo "==> Done."
