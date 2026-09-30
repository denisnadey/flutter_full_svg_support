#!/usr/bin/env bash
# Verifies that a Mach-O binary exports the quickjs_engine FFI bridge, for
# every architecture it contains:
#
# - every DLLEXPORT function of native/cxx/libfastdev_quickjs_runtime.cpp, and
# - every symbol the Dart side looks up in lib/quickjs/ffi.dart.
#
# Dart looks the bridge up with DynamicLibrary.process() (dlsym), so a symbol
# that is missing from the export table fails at runtime even though the app
# builds fine. The second list catches Dart lookups that the native bridge
# never defined (jsSetMemoryLimit was missing until quickjs_engine 0.1.6).
#
# Usage: check_quickjs_bridge_exports.sh <mach-o binary>
set -euo pipefail

binary="$1"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
package_root="$repo_root/packages/quickjs_engine"
bridge_source="$package_root/native/cxx/libfastdev_quickjs_runtime.cpp"
ffi_source="$package_root/lib/quickjs/ffi.dart"

if [ ! -f "$binary" ]; then
  echo "::error::binary not found: $binary"
  exit 1
fi

# DLLEXPORT functions defined by the bridge.
bridge_names="$(grep -E '^[[:space:]]*DLLEXPORT ' "$bridge_source" \
  | sed -E 's/\(.*//' | awk '{print $NF}' | sed -E 's/^\*+//' | sort -u)"
bridge_count="$(printf '%s\n' "$bridge_names" | grep -c .)"
if [ "$bridge_count" -lt 50 ]; then
  echo "::error::parsed only $bridge_count DLLEXPORT functions from $bridge_source"
  exit 1
fi

# Symbols Dart looks up: `_qjsLib.lookup<NativeFunction<...>>('name')`.
dart_names="$(grep -oE ">>\('[A-Za-z_][A-Za-z0-9_]*'\)" "$ffi_source" \
  | sed -E "s/^>>\('//; s/'\)\$//" | sort -u)"
dart_count="$(printf '%s\n' "$dart_names" | grep -c .)"
lookup_count="$(grep -oE '\.lookup<' "$ffi_source" | grep -c .)"
if [ "$dart_count" -lt 50 ] || [ "$dart_count" -ne "$lookup_count" ]; then
  echo "::error::parsed $dart_count symbol names from $lookup_count lookups in $ffi_source"
  exit 1
fi

status=0
undefined="$(comm -13 <(printf '%s\n' "$bridge_names") <(printf '%s\n' "$dart_names") | tr '\n' ' ')"
if [ -n "${undefined// /}" ]; then
  echo "::error::lib/quickjs/ffi.dart looks up symbols that native/cxx/libfastdev_quickjs_runtime.cpp does not DLLEXPORT: $undefined"
  status=1
fi

names="$(printf '%s\n%s\n' "$bridge_names" "$dart_names" | sort -u)"
expected="$(printf '%s\n' "$names" | grep -c .)"
echo "checking $expected symbols: $bridge_count DLLEXPORT functions, $dart_count Dart lookups"

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
  echo "$(basename "$binary") [$arch]: $found/$expected bridge symbols exported"
  if [ -n "$missing" ]; then
    echo "::error::$(basename "$binary") [$arch] is missing:$missing"
    status=1
  fi
done
exit "$status"
