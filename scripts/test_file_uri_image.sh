#!/usr/bin/env bash
# Verifies that <image href="file://..."> in SVG loads and renders correctly.
#
# Steps:
#   1. Creates a solid-red 20x20 PNG in a temp dir
#   2. Runs readFileBytes unit tests (verifies dart:io reads the file)
#   3. Runs pixel render test (verifies the image actually appears in the SVG)
#
# Usage: bash scripts/test_file_uri_image.sh

set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER="$HOME/fvm/versions/3.38.1/bin/flutter"

# Allow override: FLUTTER_BIN=... bash scripts/test_file_uri_image.sh
FLUTTER="${FLUTTER_BIN:-$FLUTTER}"

if [[ ! -x "$FLUTTER" ]]; then
  echo "Flutter not found at $FLUTTER"
  echo "Set FLUTTER_BIN=/path/to/flutter and retry."
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   file:// image loading — end-to-end test suite ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── 1. Create a solid-red PNG ────────────────────────────────────────────────
TEMP_DIR=$(mktemp -d)
PNG_PATH="$TEMP_DIR/red_square.png"
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "→ Creating solid-red 20×20 PNG at $PNG_PATH"
python3 - "$PNG_PATH" <<'PYEOF'
import struct, zlib, sys

def make_png(r, g, b, w=20, h=20):
    def chunk(t, d):
        c = t + d
        return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    raw = b''.join(b'\x00' + bytes([r, g, b] * w) for _ in range(h))
    return (
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(raw))
        + chunk(b'IEND', b'')
    )

with open(sys.argv[1], 'wb') as f:
    f.write(make_png(255, 0, 0))
print(f'  Written {sys.argv[1]}')
PYEOF

FILE_URI="file://$PNG_PATH"
echo "  URI: $FILE_URI"
echo ""

# ── 2. readFileBytes unit tests ──────────────────────────────────────────────
echo "→ Step 1/2: readFileBytes unit tests"
cd "$PROJECT"
"$FLUTTER" test test/animation/image_file_uri_test.dart \
  --name "readFileBytes" \
  --reporter expanded
echo ""

# ── 3. Pixel render test ─────────────────────────────────────────────────────
echo "→ Step 2/2: pixel render test (SVG renders the image at file://)"
PNG_PATH="$PNG_PATH" FILE_URI="$FILE_URI" \
  "$FLUTTER" test test/animation/file_uri_pixel_test.dart \
  --reporter expanded
echo ""

echo "✓ All checks passed — file:// images load and render correctly."
echo ""
