#!/bin/sh
# Builds the quickjs_engine native bridge from source and stages the
# resulting shared library in the platform-specific output folder.
#
# Works on macOS and Linux. On Windows, use tool/build_native.ps1 instead.
#
# Required: cmake >= 3.10 and a C/C++17 compiler.
set -e

cd "$(dirname "$0")/.."
PKG_ROOT="$(pwd)"
BUILD_DIR="$PKG_ROOT/native/build"

echo "[quickjs_engine] Configuring (cmake -S native -B native/build)..."
cmake -S "$PKG_ROOT/native" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release

echo "[quickjs_engine] Building..."
JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
cmake --build "$BUILD_DIR" -j "$JOBS"

# Stage the output where the plugin/loader expects it.
case "$(uname -s)" in
  Darwin*)
    LIB="libquickjs_c_bridge_plugin.dylib"
    DEST="$PKG_ROOT/macos/Frameworks/$LIB"
    mkdir -p "$PKG_ROOT/macos/Frameworks"
    cp "$BUILD_DIR/$LIB" "$DEST"
    echo "[quickjs_engine] Staged: $DEST"
    ;;
  Linux*)
    echo "[quickjs_engine] Built: $BUILD_DIR/libquickjs_c_bridge_plugin.so"
    echo "[quickjs_engine] (Consumer apps rebuild this via the plugin's"
    echo "                  linux/CMakeLists.txt at 'flutter run' time.)"
    ;;
  *)
    echo "[quickjs_engine] Built under $BUILD_DIR — no platform-specific staging."
    ;;
esac
