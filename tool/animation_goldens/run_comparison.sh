#!/bin/bash
#
# Animation Parity Regression Suite — Orchestrator
#
# Runs the full pipeline:
#   Phase 1: Capture browser frames (Puppeteer/Chrome)
#   Phase 2: Capture Flutter frames (Flutter test)
#   Phase 3: Compare frames and generate reports
#
# Usage:
#   ./tool/animation_goldens/run_comparison.sh
#   ./tool/animation_goldens/run_comparison.sh --frames 10 --duration 10
#
# Options:
#   --duration <n>   Animation duration in seconds (default: 15)
#   --frames <n>     Number of frames to capture (default: 15)
#   --skip-browser   Skip browser capture (reuse existing frames)
#   --skip-flutter   Skip Flutter capture (reuse existing frames)
#   --skip-compare   Skip comparison (only capture)
#

set -e

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
_find_flutter() {
  local dir="$1"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.fvm/flutter_sdk/bin/flutter" ]; then
      echo "$dir/.fvm/flutter_sdk/bin/flutter"
      return
    fi
    dir="$(dirname "$dir")"
  done
  command -v flutter 2>/dev/null || echo "flutter"
}
FLUTTER="$(_find_flutter "$PROJECT_ROOT")"

DURATION=15
FRAMES=15
SKIP_BROWSER=false
SKIP_FLUTTER=false
SKIP_COMPARE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --duration) DURATION="$2"; shift 2 ;;
    --frames) FRAMES="$2"; shift 2 ;;
    --skip-browser) SKIP_BROWSER=true; shift ;;
    --skip-flutter) SKIP_FLUTTER=true; shift ;;
    --skip-compare) SKIP_COMPARE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

SVG_FIXTURES="$PROJECT_ROOT/test/animation_goldens/svg_fixtures"

echo "============================================================"
echo "  Animation Parity Regression Suite"
echo "============================================================"
echo "  Project  : $PROJECT_ROOT"
echo "  Duration : ${DURATION}s"
echo "  Frames   : $FRAMES"
echo "  Fixtures : $SVG_FIXTURES"
echo "============================================================"
echo ""

# ---------------------------------------------------------------------------
# Phase 1: Browser capture
# ---------------------------------------------------------------------------

if [ "$SKIP_BROWSER" = false ]; then
  echo "Phase 1: Capturing browser frames..."
  echo "------------------------------------------------------------"

  # Install npm dependencies if needed
  if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
    echo "  Installing Puppeteer..."
    cd "$SCRIPT_DIR" && npm install --silent && cd "$PROJECT_ROOT"
  fi

  # Run capture
  node "$SCRIPT_DIR/capture_browser.js" \
    --duration "$DURATION" \
    --frames "$FRAMES" \
    --output "test/animation_goldens/browser/" \
    "$SVG_FIXTURES"/*.svg

  echo ""
else
  echo "Phase 1: SKIPPED (--skip-browser)"
  echo ""
fi

# ---------------------------------------------------------------------------
# Phase 2: Flutter capture
# ---------------------------------------------------------------------------

if [ "$SKIP_FLUTTER" = false ]; then
  echo "Phase 2: Capturing Flutter frames..."
  echo "------------------------------------------------------------"

  ANIM_DURATION=$DURATION ANIM_FRAMES=$FRAMES \
    $FLUTTER test \
    "$SCRIPT_DIR/capture_flutter_test.dart" \
    --tags animation_golden \
    --reporter expanded

  echo ""
else
  echo "Phase 2: SKIPPED (--skip-flutter)"
  echo ""
fi

# ---------------------------------------------------------------------------
# Phase 3: Compare and report
# ---------------------------------------------------------------------------

if [ "$SKIP_COMPARE" = false ]; then
  echo "Phase 3: Comparing frames and generating reports..."
  echo "------------------------------------------------------------"

  ANIM_DURATION=$DURATION ANIM_FRAMES=$FRAMES \
    $FLUTTER test \
    "$SCRIPT_DIR/compare_frames.dart" \
    --tags animation_compare \
    --reporter expanded

  echo ""
else
  echo "Phase 3: SKIPPED (--skip-compare)"
  echo ""
fi

echo "============================================================"
echo "  Pipeline complete!"
echo ""
echo "  Browser frames: test/animation_goldens/browser/"
echo "  Flutter frames: test/animation_goldens/flutter/"
echo "  Diff images:    test/animation_goldens/diff/"
echo "  Reports:        test/animation_goldens/reports/"
echo "============================================================"
