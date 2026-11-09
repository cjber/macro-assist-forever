#!/usr/bin/env python3
"""Draw media/squiggle.tga, the wavy underline under a diagnostic.

The client has no squiggle atlas, so the editor draws its own: a white tile with alpha on the wave, tinted
red for an error and yellow for a warning. It is 16 by 4 pixels, repeated horizontally at its native height.

    python3 tools/make_squiggle.py
"""

import math
import struct
from pathlib import Path

WIDTH = 16
HEIGHT = 4
OUT = Path(__file__).resolve().parent.parent / "media" / "squiggle.tga"


def wave_y(x: int) -> int:
    """One sine period over 8 px, held inside the tile."""
    return round(1.5 + 1.4 * math.sin(2 * math.pi * x / 8))


def main() -> None:
    pixels = bytearray()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            # BGRA, top-left origin. AUTH: white where the wave is, transparent elsewhere.
            alpha = 255 if y == wave_y(x) else 0
            pixels += bytes((255, 255, 255, alpha))
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0,  # ID length
        0,  # no colour map
        2,  # uncompressed truecolour
        0,
        0,
        0,
        0,
        0,
        WIDTH,
        HEIGHT,
        32,  # bits per pixel
        0x28,  # 8 alpha bits, top-left origin
    )
    OUT.write_bytes(header + pixels)
    print(f"{OUT}: {WIDTH}x{HEIGHT}")


if __name__ == "__main__":
    main()
