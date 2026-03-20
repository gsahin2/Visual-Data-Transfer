#!/usr/bin/env python3
"""
Decode a synthetic grid PNG (same layout as `generate_test_frames.py`) back to bytes.

Samples cell-centre luma, quantises to 4 levels (2 bits/cell), then unpacks MSB-first
to bytes. Use `--byte-length` when the encoded message is shorter than `cells*2` bits.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import List, Optional

from PIL import Image


def layout_cell_rect(
    width: int,
    height: int,
    rows: int,
    cols: int,
    margin: int,
    gap: int,
    row: int,
    col: int,
) -> tuple[float, float, float, float]:
    inner_w = width - 2 * margin
    inner_h = height - 2 * margin
    cell_w = (inner_w - gap * (cols - 1)) / cols
    cell_h = (inner_h - gap * (rows - 1)) / rows
    x0 = margin + col * (cell_w + gap)
    y0 = margin + row * (cell_h + gap)
    return x0, y0, x0 + cell_w, y0 + cell_h


def sample_cell_luma(img: Image.Image, x0: float, y0: float, x1: float, y1: float) -> float:
    px = img.convert("RGB")
    w, h = px.size
    cx = int((x0 + x1) * 0.5)
    cy = int((y0 + y1) * 0.5)
    cx = max(0, min(w - 1, cx))
    cy = max(0, min(h - 1, cy))
    r, g, b = px.getpixel((cx, cy))
    return 0.299 * r + 0.587 * g + 0.114 * b


def luma_to_symbol(y: float) -> int:
    """Map luma to 0..3 using midpoints between encoder levels 0, 85, 170, 255."""
    if y < 63.75:
        return 0
    if y < 148.75:
        return 1
    if y < 233.75:
        return 2
    return 3


def symbols_to_bitstream(symbols: List[int]) -> List[int]:
    bits: List[int] = []
    for s in symbols:
        s &= 3
        bits.append((s >> 1) & 1)
        bits.append(s & 1)
    return bits


def bitstream_to_bytes(bits: List[int], max_bytes: Optional[int] = None) -> bytes:
    out = bytearray()
    for i in range(0, len(bits), 8):
        if i + 8 > len(bits):
            break
        v = 0
        for j in range(8):
            v = (v << 1) | bits[i + j]
        out.append(v)
        if max_bytes is not None and len(out) >= max_bytes:
            break
    return bytes(out)


def decode_grid_png(
    path: Path,
    rows: int,
    cols: int,
    margin: int,
    gap: int,
    byte_length: Optional[int],
) -> bytes:
    img = Image.open(path)
    w, h = img.size
    symbols: List[int] = []
    for r in range(rows):
        for c in range(cols):
            x0, y0, x1, y1 = layout_cell_rect(w, h, rows, cols, margin, gap, r, c)
            y_l = sample_cell_luma(img, x0, y0, x1, y1)
            symbols.append(luma_to_symbol(y_l))
    bits = symbols_to_bitstream(symbols)
    return bitstream_to_bytes(bits, max_bytes=byte_length)


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
