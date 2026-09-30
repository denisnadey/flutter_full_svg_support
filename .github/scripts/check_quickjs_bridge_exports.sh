#!/usr/bin/env bash
# Verifies that a Mach-O binary exports every DLLEXPORT function of the
# quickjs_engine FFI bridge, for every architecture it contains.
#
# Dart looks the bridge up with DynamicLibrary.process() (dlsym), so a symbol
# that is missing from the export table fails at runtime even though the app
# builds fine.
#
# Usage: check_quickjs_bridge_exports.sh <mach-o binary>
set -euo pipefail

binary="$1"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
bridge_source="$repo_root/packages/quickjs_engine/native/cxx/libfastdev_quickjs_runtime.cpp"

if [ ! -f "$binary" ]; then
  echo "::error::binary not found: $binary"
  exit 1
fi

names="$(grep -E '^[[:space:]]*DLLEXPORT ' "$bridge_source" \
  | sed -E 's/\(.*//' | awk '{print $NF}' | sed -E 's/^\*+//' | sort -u)"
expected="$(printf '%s\n' "$names" | grep -c .)"
if [ "$expected" -lt 50 ]; then
  echo "::error::parsed only $expected DLLEXPORT functions from $bridge_source"
  exit 1
fi

status=0
for arch in $(lipo -archs "$binary"); do
  exports="$(nm -gU -arch "$arch" "$binary")"
  missing=""
  found=0
  for name in $names; do
    if grep -qE "[[:space:]]_${name}\$" <<<"$exports"; then
      found=$((found + 1))
    else
      missing="$missing $name"
    fi
  done
  echo "$(basename "$binary") [$arch]: $found/$expected bridge functions exported"
  if [ -n "$missing" ]; then
    echo "::error::$(basename "$binary") [$arch] is missing:$missing"
    status=1
  fi
done
exit "$status"
