#!/usr/bin/env bash
# Direct shell wrapper for the recording session.
#
# Why this exists instead of just `make record`:
#   On systems where `make` is shimmed via Xcode CLI tools, the binary lives at
#     /Applications/Xcode.app/Contents/Developer/usr/bin/make
#   macOS attributes Screen Recording permission to the first .app bundle in
#   the process tree — that's Xcode. iTerm/Terminal/etc. that the user actually
#   has permission for never get consulted. Result: ffmpeg writes black frames.
#
# This wrapper calls Python directly so the chain becomes
#   iTerm → zsh → record.sh → python3 → ffmpeg
# with no /Applications/Xcode.app/ to confuse TCC.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec python3 "${SCRIPT_DIR}/comparison/record_session.py" "$@"
