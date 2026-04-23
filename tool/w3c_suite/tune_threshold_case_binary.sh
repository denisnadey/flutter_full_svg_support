#!/usr/bin/env bash

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${REPO_ROOT}/test/w3c/w3c_render_utils.dart"
TEST_FILE="test/w3c/w3c_static_golden_test.dart"

usage() {
  cat <<'EOF'
Usage:
  tool/w3c_suite/tune_threshold_case_binary.sh <case-name> [min-threshold] [repeats]

Examples:
  tool/w3c_suite/tune_threshold_case_binary.sh text-align-01-b
  tool/w3c_suite/tune_threshold_case_binary.sh painting-fill-02-t 0.00 2

Behavior:
  - Reads current per-case threshold from test/w3c/w3c_render_utils.dart
  - Uses binary search between min-threshold and current value
  - Finds minimum passing threshold at 0.01 precision
  - Leaves the file at the best passing value
EOF
}

if [[ $# -lt 1 || $# -gt 3 ]]; then
  usage
  exit 2
fi

CASE_NAME="$1"
MIN_THRESHOLD="${2:-0.00}"
REPEATS="${3:-1}"

if ! [[ "$MIN_THRESHOLD" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Invalid min-threshold: ${MIN_THRESHOLD}" >&2
  exit 2
fi
if ! [[ "$REPEATS" =~ ^[0-9]+$ ]] || [[ "$REPEATS" -lt 1 ]]; then
  echo "Invalid repeats: ${REPEATS}" >&2
  exit 2
fi

if [[ -x "${REPO_ROOT}/.fvm/versions/3.38.1/bin/flutter" ]]; then
  FLUTTER_BIN="${REPO_ROOT}/.fvm/versions/3.38.1/bin/flutter"
elif [[ -x "${REPO_ROOT}/.fvm/flutter_sdk/bin/flutter" ]]; then
  FLUTTER_BIN="${REPO_ROOT}/.fvm/flutter_sdk/bin/flutter"
else
  FLUTTER_BIN="flutter"
fi

to_hundredths_int() {
  awk -v value="$1" 'BEGIN { printf("%d\n", int((value * 100) + 0.5)); }'
}

to_threshold_string() {
  awk -v value="$1" 'BEGIN { printf("%.2f\n", value / 100.0); }'
}

extract_current_threshold() {
  rg -N -m1 "'${CASE_NAME}':\\s*[0-9]+(\\.[0-9]+)?," "${CONFIG_FILE}" \
    | sed -E "s/.*'${CASE_NAME}':[[:space:]]*([0-9]+(\\.[0-9]+)?),.*/\\1/"
}

set_threshold() {
  local new_value="$1"
  perl -0777 -i -pe "s/'\\Q${CASE_NAME}\\E':\\s*[0-9]+(?:\\.[0-9]+)?,/'${CASE_NAME}': ${new_value},/g" "${CONFIG_FILE}"
}

run_case_once() {
  (
    cd "${REPO_ROOT}"
    RUN_W3C_STATIC=1 \
    W3C_LIMIT=1 \
    W3C_NAME_FILTER="${CASE_NAME}" \
    "${FLUTTER_BIN}" test "${TEST_FILE}" >/tmp/w3c_tune_binary_${CASE_NAME}.log 2>&1
  )
}

run_case_repeated() {
  local repeats="$1"
  local attempt=1
  while [[ "$attempt" -le "$repeats" ]]; do
    if ! run_case_once; then
      return 1
    fi
    attempt=$((attempt + 1))
  done
  return 0
}

CURRENT_THRESHOLD="$(extract_current_threshold)"
if [[ -z "${CURRENT_THRESHOLD}" ]]; then
  echo "Case not found in threshold map: ${CASE_NAME}" >&2
  exit 1
fi

HI="$(to_hundredths_int "${CURRENT_THRESHOLD}")"
LO="$(to_hundredths_int "${MIN_THRESHOLD}")"

if [[ "${LO}" -gt "${HI}" ]]; then
  echo "min-threshold (${MIN_THRESHOLD}) is above current (${CURRENT_THRESHOLD}); nothing to do"
  exit 0
fi

echo "Case: ${CASE_NAME}"
echo "Current threshold: ${CURRENT_THRESHOLD}"
echo "Search min: ${MIN_THRESHOLD}"
echo "Repeats per check: ${REPEATS}"
echo "Flutter: ${FLUTTER_BIN}"

# Verify current threshold is actually passing.
set_threshold "$(to_threshold_string "${HI}")"
if ! run_case_repeated "${REPEATS}"; then
  echo "Current threshold does not pass for ${CASE_NAME}; aborting" >&2
  exit 1
fi

# If minimum already passes, keep it.
set_threshold "$(to_threshold_string "${LO}")"
if run_case_repeated "${REPEATS}"; then
  final="$(to_threshold_string "${LO}")"
  set_threshold "${final}"
  echo "Final threshold for ${CASE_NAME}: ${final}"
  exit 0
fi

# Binary search for minimum passing threshold.
while [[ $((HI - LO)) -gt 1 ]]; do
  MID=$(((HI + LO) / 2))
  MID_STR="$(to_threshold_string "${MID}")"
  set_threshold "${MID_STR}"
  if run_case_repeated "${REPEATS}"; then
    HI="${MID}"
    echo "  pass @ ${MID_STR}"
  else
    LO="${MID}"
    echo "  fail @ ${MID_STR}"
  fi
done

FINAL="$(to_threshold_string "${HI}")"
set_threshold "${FINAL}"

echo "Final threshold for ${CASE_NAME}: ${FINAL}"
