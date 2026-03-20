#!/usr/bin/env python3
"""
Decode a synthetic grid PNG (same layout as `generate_test_frames.py`) back to bytes.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Optional

from PIL import Image

from grid_codec import decode_grid_sampled


def decode_grid_png(
    path: Path,
    rows: int,
    cols: int,
    margin: int,
    gap: int,
    byte_length: Optional[int],
) -> bytes:
    img = Image.open(path).convert("RGB")
    w, h = img.size

    def sample(cx: int, cy: int) -> float:
        r, g, b = img.getpixel((cx, cy))
        return 0.299 * r + 0.587 * g + 0.114 * b

    return decode_grid_sampled(w, h, rows, cols, margin, gap, byte_length, sample)


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode VDT-style grid PNG to bytes.")
    parser.add_argument("image", type=Path, help="PNG path")
    parser.add_argument("--rows", type=int, default=12)
    parser.add_argument("--cols", type=int, default=20)
    parser.add_argument("--margin", type=int, default=8)
    parser.add_argument("--gap", type=int, default=2)
    parser.add_argument("--byte-length", type=int, default=None, help="Trim output to this many bytes")
    parser.add_argument("--compare", type=str, default=None, help="Expected UTF-8 string for exit code")
    args = parser.parse_args()

    bl = args.byte_length
    if args.compare is not None and bl is None:
        bl = len(args.compare.encode("utf-8"))
    out = decode_grid_png(args.image, args.rows, args.cols, args.margin, args.gap, bl)
    print(f"Decoded {len(out)} bytes: {out!r}")
    if args.compare is not None:
        exp = args.compare.encode("utf-8")
        if bl is not None:
            exp = exp[:bl]
        if out != exp:
            raise SystemExit(f"Mismatch: expected {exp!r} got {out!r}")


if __name__ == "__main__":
    main()
