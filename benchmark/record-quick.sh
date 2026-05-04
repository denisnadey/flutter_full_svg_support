#!/usr/bin/env bash
# Direct-shell variant of `make record-quick` — see record.sh for rationale.
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec python3 "${SCRIPT_DIR}/comparison/record_session.py" \
    --duration 60 --gif-clip 12 --gif-start 8 --gif-fps 12 --gif-width 540 "$@"
