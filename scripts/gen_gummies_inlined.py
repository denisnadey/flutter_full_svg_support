#!/usr/bin/env python3
"""
Generate glowing_gummies_inlined.svg — the gummies animation SVG with the
SVGator player script embedded inline (no CDN fetch needed in tests).

Usage:
    python3 scripts/gen_gummies_inlined.py

Reads:
    test/golden_comparison/svg_fixtures/glowing_gummies.svg
    (downloads SVGator player script from CDN if not already in /tmp)

Writes:
    test/golden_comparison/svg_fixtures/glowing_gummies_inlined.svg
"""

import re
import sys
import os
import urllib.request

GUMMIES_URL = (
    "https://cdn.svgator.com/images/2024/10/"
    "glowing-gummies-graphic-art-animation.svg"
)
PLAYER_KEY     = "91c80d77"
PLAYER_VERSION = "2024-09-05"
PLAYER_URL     = f"https://cdn.svgator.com/ply/{PLAYER_KEY}.js?v={PLAYER_VERSION}"

FIXTURE_DIR = "test/golden_comparison/svg_fixtures"
GUMMIES_SVG = f"{FIXTURE_DIR}/glowing_gummies.svg"
OUT_SVG     = f"{FIXTURE_DIR}/glowing_gummies_inlined.svg"
PLAYER_CACHE = f"/tmp/svgator_player_{PLAYER_KEY}.js"


def download(url: str, dest: str) -> str:
    if os.path.exists(dest):
        print(f"  cached {dest}")
    else:
        print(f"  downloading {url}")
        urllib.request.urlretrieve(url, dest)
    return open(dest).read()


def main() -> None:
    os.chdir(os.path.join(os.path.dirname(__file__), ".."))

    # Ensure gummies SVG exists.
    if not os.path.exists(GUMMIES_SVG):
        os.makedirs(FIXTURE_DIR, exist_ok=True)
        download(GUMMIES_URL, GUMMIES_SVG)

    svg    = open(GUMMIES_SVG).read()
    player = download(PLAYER_URL, PLAYER_CACHE)

    # Find the original <script> block (the bootstrap).
    match = re.search(
        r"<script><!\[CDATA\[.*?\]\]></script>", svg, re.DOTALL
    )
    if not match:
        sys.exit("ERROR: could not find <script> block in gummies SVG")

    original_script = match.group(0)

    # Prepend the player script so __SVGATOR_PLAYER__ is defined before
    # the bootstrap tries to load it from CDN.
    player_block = f"<script><![CDATA[\n{player}\n]]></script>"
    new_svg = svg.replace(original_script, player_block + "\n" + original_script)

    open(OUT_SVG, "w").write(new_svg)
    print(f"Written: {OUT_SVG}  ({len(new_svg):,} bytes)")


if __name__ == "__main__":
    main()
