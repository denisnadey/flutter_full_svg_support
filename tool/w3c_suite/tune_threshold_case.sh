#!/usr/bin/env bash

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${REPO_ROOT}/test/w3c/w3c_render_utils.dart"
TEST_FILE="test/w3c/w3c_static_golden_test.dart"

usage() {
  cat <<'EOF'
Usage:
  tool/w3c_suite/tune_threshold_case.sh <case-name> <min-threshold> [step] [repeats]

Examples:
  tool/w3c_suite/tune_threshold_case.sh filters-light-02-f 0.10
  tool/w3c_suite/tune_threshold_case.sh filters-turb-02-f 0.20 0.01 2

Behavior:
  - Reads current per-case threshold from test/w3c/w3c_render_utils.dart
  - Decreases threshold in steps (default 0.01)
  - Runs single-case W3C golden test for each candidate
  - Stops on first failing candidate
  - Leaves file set to the last passing threshold
EOF
}

if [[ $# -lt 2 || $# -gt 4 ]]; then
  usage
  exit 2
fi

CASE_NAME="$1"
MIN_THRESHOLD="$2"
STEP="${3:-0.01}"
REPEATS="${4:-1}"

if ! [[ "$STEP" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Invalid step: ${STEP}" >&2
  exit 2
fi
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

CURRENT_THRESHOLD="$(extract_current_threshold)"
if [[ -z "${CURRENT_THRESHOLD}" ]]; then
  echo "Case not found in threshold map: ${CASE_NAME}" >&2
  exit 1
fi

CURRENT_I="$(to_hundredths_int "${CURRENT_THRESHOLD}")"
MIN_I="$(to_hundredths_int "${MIN_THRESHOLD}")"
STEP_I="$(to_hundredths_int "${STEP}")"

if [[ "${MIN_I}" -gt "${CURRENT_I}" ]]; then
  echo "Min threshold (${MIN_THRESHOLD}) is above current (${CURRENT_THRESHOLD}). Nothing to do."
  exit 0
fi
if [[ "${STEP_I}" -le 0 ]]; then
  echo "Step must be > 0." >&2
  exit 2
fi

echo "Case: ${CASE_NAME}"
echo "Current threshold: ${CURRENT_THRESHOLD}"
echo "Search min: ${MIN_THRESHOLD}"
echo "Step: ${STEP}"
echo "Repeats per candidate: ${REPEATS}"
echo "Flutter: ${FLUTTER_BIN}"
echo

last_pass_i="${CURRENT_I}"
ts="$(date +%Y%m%d%H%M%S)"
slug="$(echo "${CASE_NAME}" | tr -c 'a-zA-Z0-9' '_')"

for ((candidate_i = CURRENT_I - STEP_I; candidate_i >= MIN_I; candidate_i -= STEP_I)); do
  candidate="$(to_threshold_string "${candidate_i}")"
  set_threshold "${candidate}"
  echo "Trying ${CASE_NAME} -> ${candidate}"

  candidate_ok=1
  for ((attempt = 1; attempt <= REPEATS; attempt++)); do
    run_id="thr_auto_${slug}_${candidate//./}_${ts}_a${attempt}"
    summary_path="${REPO_ROOT}/test/w3c/artifacts/trace/${run_id}/${CASE_NAME}/summary.json"
    log_path="${REPO_ROOT}/test/w3c/artifacts/trace/${run_id}.log"
    mkdir -p "$(dirname "${log_path}")"

    (
      cd "${REPO_ROOT}"
      RUN_W3C_STATIC=1 \
      W3C_LIMIT=1 \
      W3C_NAME_FILTER="${CASE_NAME}" \
      W3C_TRACE=1 \
      W3C_TRACE_PROFILE=basic \
      W3C_TRACE_FAIL_ONLY=0 \
      W3C_TRACE_RUN_ID="${run_id}" \
      "${FLUTTER_BIN}" test "${TEST_FILE}" >"${log_path}" 2>&1
    )
    exit_code=$?

    if [[ ! -f "${summary_path}" ]]; then
      echo "  attempt ${attempt}/${REPEATS}: no summary (exit=${exit_code}), see ${log_path}"
      candidate_ok=0
      break
    fi

    passed="$(jq -r '.passed' "${summary_path}")"
    similarity="$(jq -r '.similarity' "${summary_path}")"
    echo "  attempt ${attempt}/${REPEATS}: passed=${passed} similarity=${similarity} (runId=${run_id})"

    if [[ "${passed}" != "true" ]]; then
      candidate_ok=0
      break
    fi
  done

  if [[ "${candidate_ok}" -eq 1 ]]; then
    last_pass_i="${candidate_i}"
    echo "  => PASS, keep lowering"
  else
    echo "  => FAIL, stop at previous passing threshold"
    break
  fi
done

final_threshold="$(to_threshold_string "${last_pass_i}")"
set_threshold "${final_threshold}"
echo
echo "Final threshold for ${CASE_NAME}: ${final_threshold}"
