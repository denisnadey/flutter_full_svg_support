#!/bin/sh
# Build the quickjs-ng bridge dylib for macOS and copy it into Frameworks/
# so the CocoaPods plugin can vendor it.
set -e
cd "$(dirname "$0")/.."
PKG_ROOT="$(pwd)"

cmake -S "$PKG_ROOT/native" -B "$PKG_ROOT/native/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$PKG_ROOT/native/build" -j 8

mkdir -p "$PKG_ROOT/macos/Frameworks"
cp "$PKG_ROOT/native/build/libquickjs_c_bridge_plugin.dylib" \
   "$PKG_ROOT/macos/Frameworks/libquickjs_c_bridge_plugin.dylib"

echo "built: $PKG_ROOT/macos/Frameworks/libquickjs_c_bridge_plugin.dylib"
