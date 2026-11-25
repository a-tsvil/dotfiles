#!/usr/bin/env python3
"""Render the bar's UI gradient with dithering before 8-bit quantization."""

from pathlib import Path
import random
import struct
import zlib


def chunk(kind, data):
    return (
        struct.pack('!I', len(data)) + kind + data
        + struct.pack('!I', zlib.crc32(kind + data) & 0xffffffff)
    )


def main():
    width, height = 3840, 96
    # A soft amber glow at the left fades through teal into the original dark end.
    stops = (
        (0.0, (48.5, 36.5, 24.5)),
        (0.25, (9.5, 42.6, 58.1)),
        (0.5, (15.3, 29.0, 30.7)),
        (1.0, (15.3, 16.3, 11.6)),
    )
    columns = []
    for x in range(width):
        position = x / (width - 1)
        segment = 0
        while segment < len(stops) - 2 and position > stops[segment + 1][0]:
            segment += 1
        start, start_color = stops[segment]
        end, end_color = stops[segment + 1]
        fraction = (position - start) / (end - start)
        columns.append(tuple(
            a + (b - a) * fraction
            for a, b in zip(start_color, end_color)
        ))

    rng = random.Random(17)
    pixels = bytearray()
    for _ in range(height):
        pixels.append(0)  # PNG scanline filter: none.
        for color in columns:
            # One shared threshold preserves neutral color relationships.
            threshold = rng.random()
            pixels.extend(int(channel + threshold) for channel in color)

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('!2I5B', width, height, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(pixels, 9))
    png += chunk(b'IEND', b'')
    output = Path(__file__).resolve().parents[1] / 'themes/bar-gradient.png'
    output.write_bytes(png)
    print(output)


if __name__ == '__main__':
    main()
