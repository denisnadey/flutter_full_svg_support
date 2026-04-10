#!/bin/bash
#
# W3C SVG Golden Pipeline Orchestrator
#
# Usage:
#   ./tool/w3c_goldens/run_w3c_comparison.sh
#   ./tool/w3c_goldens/run_w3c_comparison.sh --tier core
#   ./tool/w3c_goldens/run_w3c_comparison.sh --case coords-trans-01-b --update-baseline

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -n "${FLUTTER_BIN:-}" ]; then
  FLUTTER="$FLUTTER_BIN"
elif [ -x "$PROJECT_ROOT/.fvm/versions/3.38.1/bin/flutter" ]; then
  FLUTTER="$PROJECT_ROOT/.fvm/versions/3.38.1/bin/flutter"
elif [ -x "$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter" ]; then
  FLUTTER="$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter"
elif command -v flutter >/dev/null 2>&1; then
  FLUTTER="$(command -v flutter)"
else
  echo "Flutter binary not found."
  echo "Set FLUTTER_BIN=/absolute/path/to/flutter or install Flutter/FVM."
  exit 1
fi

TIER="smoke"
CASE_ID=""
LIMIT=""
SKIP_BROWSER=false
SKIP_FLUTTER=false
UPDATE_BASELINE=false
ENABLE_RENDER=false
ENFORCE_THRESHOLD=true
DEBUG_TRACE=false
USE_ANIMATED_RENDERER=false
FLUTTER_EXIT_CODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier)
      TIER="$2"
      shift 2
      ;;
    --case)
      CASE_ID="$2"
      shift 2
      ;;
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --skip-browser)
      SKIP_BROWSER=true
      shift
      ;;
    --skip-flutter)
      SKIP_FLUTTER=true
      shift
      ;;
    --update-baseline)
      UPDATE_BASELINE=true
      shift
      ;;
    --enable-render)
      ENABLE_RENDER=true
      shift
      ;;
    --no-enforce-threshold)
      ENFORCE_THRESHOLD=false
      shift
      ;;
    --debug-trace)
      DEBUG_TRACE=true
      shift
      ;;
    --use-animated-renderer)
      USE_ANIMATED_RENDERER=true
      shift
      ;;
    --use-static-renderer)
      USE_ANIMATED_RENDERER=false
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

REPORT_DIR="$PROJECT_ROOT/test/goldens/w3c/reports"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_SUFFIX="$TIER"
if [ -n "$CASE_ID" ]; then
  SAFE_CASE="$(echo "$CASE_ID" | tr '/: ' '___')"
  REPORT_SUFFIX="${REPORT_SUFFIX}_${SAFE_CASE}"
fi
REPORT_JSON="$REPORT_DIR/w3c_report_${REPORT_SUFFIX}_${TIMESTAMP}.json"
REPORT_MD="$REPORT_DIR/w3c_report_${REPORT_SUFFIX}_${TIMESTAMP}.md"

echo "============================================================"
echo "  W3C SVG Golden Pipeline"
echo "============================================================"
echo "  Tier   : $TIER"
echo "  Flutter: $FLUTTER"
if [ -n "$CASE_ID" ]; then
  echo "  Case   : $CASE_ID"
fi
if [ -n "$LIMIT" ]; then
  echo "  Limit  : $LIMIT"
fi
echo "  Report : $REPORT_JSON"
echo "============================================================"

if [ "$SKIP_BROWSER" = false ]; then
  echo ""
  echo "Phase 1: Browser capture"
  CMD=(node "$SCRIPT_DIR/capture_browser_w3c.js" --tier "$TIER")

  if [ -n "$CASE_ID" ]; then
    CMD+=(--case "$CASE_ID")
  fi

  if [ -n "$LIMIT" ]; then
    CMD+=(--limit "$LIMIT")
  fi

  if [ "$UPDATE_BASELINE" = true ]; then
    CMD+=(--update-baseline)
  fi

  "${CMD[@]}"
else
  echo ""
  echo "Phase 1: Browser capture skipped (--skip-browser)"
fi

if [ "$SKIP_FLUTTER" = false ]; then
  echo ""
  echo "Phase 2: Flutter comparison test"
  export W3C_TIER="$TIER"

  if [ -n "$CASE_ID" ]; then
    export W3C_CASE="$CASE_ID"
  else
    unset W3C_CASE
  fi

  if [ -n "$LIMIT" ]; then
    export W3C_LIMIT="$LIMIT"
  else
    unset W3C_LIMIT
  fi

  if [ "$ENABLE_RENDER" = true ]; then
    export W3C_ENABLE_RENDER=true
  else
    unset W3C_ENABLE_RENDER
    echo "  Note: Flutter render is disabled by default (set --enable-render to compare pixels)."
  fi

  if [ "$ENFORCE_THRESHOLD" = false ]; then
    export W3C_ENFORCE_THRESHOLD=false
    echo "  Note: Threshold assertions are disabled (--no-enforce-threshold)."
  else
    unset W3C_ENFORCE_THRESHOLD
  fi

  if [ "$DEBUG_TRACE" = true ]; then
    export W3C_DEBUG_TRACE=true
    echo "  Note: Debug trace is enabled (--debug-trace)."
  else
    unset W3C_DEBUG_TRACE
  fi

  if [ "$USE_ANIMATED_RENDERER" = true ]; then
    export W3C_USE_ANIMATED_RENDERER=true
    echo "  Renderer: AnimatedSvgPicture (--use-animated-renderer)"
  else
    export W3C_USE_ANIMATED_RENDERER=false
    echo "  Renderer: SvgPicture static (default)"
  fi

  mkdir -p "$REPORT_DIR"
  export W3C_REPORT_JSON="$REPORT_JSON"
  echo "  Report JSON path: $W3C_REPORT_JSON"

  set +e
  "$FLUTTER" test \
    "$PROJECT_ROOT/test/golden_comparison/w3c_golden_comparison_test.dart" \
    --tags w3c_golden \
    --reporter expanded
  FLUTTER_EXIT_CODE=$?
  set -e

  if [ -f "$REPORT_JSON" ]; then
    node "$SCRIPT_DIR/analyze_report.js" \
      --input "$REPORT_JSON" \
      --output "$REPORT_MD"
  else
    echo "  Warning: diagnostic report file not found at $REPORT_JSON"
  fi
else
  echo ""
  echo "Phase 2: Flutter test skipped (--skip-flutter)"
fi

echo ""
echo "============================================================"
echo "Done"
echo "Browser goldens : test/goldens/w3c/browser/"
echo "Flutter renders : test/goldens/w3c/flutter/"
echo "Diff images     : test/goldens/w3c/diff/"
echo "Reports         : test/goldens/w3c/reports/"
echo "============================================================"

if [ "$FLUTTER_EXIT_CODE" -ne 0 ]; then
  exit "$FLUTTER_EXIT_CODE"
fi
