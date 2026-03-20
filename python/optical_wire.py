"""
Optical grid carrying raw **VT wire bytes** (2 bits/cell), for synthetic E2E tests and small-frame video.

Layout matches ``generate_test_frames`` / Swift margin+gap. Max wire length per frame:
``(rows * cols * 2) // 8`` bytes (e.g. 60 for 12×20).
"""

from __future__ import annotations

from typing import List

from PIL import Image, ImageDraw

from vdt_protocol_v1 import HEADER_BYTES, MAX_PAYLOAD_PER_FRAME


def max_wire_bytes_for_grid(rows: int, cols: int) -> int:
    """Octets that fit in ``rows×cols`` two-bit cells."""
    return (rows * cols * 2) // 8


def max_optical_payload_bytes(rows: int, cols: int) -> int:
    """Largest payload per **payload** wire frame that still fits in the grid (header + CRC included)."""
    wb = max_wire_bytes_for_grid(rows, cols)
    return max(1, min(MAX_PAYLOAD_PER_FRAME, wb - HEADER_BYTES - 2))


def bytes_to_grid_symbols(data: bytes, cells: int) -> List[int]:
    """Pack octets into ``cells`` two-bit symbols (MSB-first stream; same packing as ``generate_test_frames``)."""
    out: List[int] = []
    bit_buf = 0
    bit_count = 0
    idx = 0
    while len(out) < cells:
        while bit_count < 2:
            if idx < len(data):
                bit_buf = (bit_buf << 8) | data[idx]
                idx += 1
                bit_count += 8
            else:
                bit_buf <<= 2
                bit_count += 2
        shift = bit_count - 2
        out.append((bit_buf >> shift) & 0x03)
        bit_count -= 2
    return out


def render_symbols_grid_rgb(
    symbols: List[int],
    rows: int,
    cols: int,
    width: int,
    height: int,
    margin: int,
    gap: int,
) -> Image.Image:
    if len(symbols) < rows * cols:
        raise ValueError("not enough symbols")
    img = Image.new("RGB", (width, height), (0, 0, 0))
    draw = ImageDraw.Draw(img)
    inner_w = width - 2 * margin
    inner_h = height - 2 * margin
    cell_w = (inner_w - gap * (cols - 1)) / cols
    cell_h = (inner_h - gap * (rows - 1)) / rows
    for r in range(rows):
        for c in range(cols):
            i = r * cols + c
            v = symbols[i] if i < len(symbols) else 0
            gray = int(round(v / 3.0 * 255))
            x0 = margin + c * (cell_w + gap)
            y0 = margin + r * (cell_h + gap)
            x1 = x0 + cell_w
            y1 = y0 + cell_h
            draw.rectangle([x0, y0, x1, y1], fill=(gray, gray, gray))
    return img


def render_wire_as_grid_png_rgb(
    wire: bytes,
    rows: int,
    cols: int,
    width: int,
    height: int,
    margin: int = 8,
    gap: int = 2,
) -> Image.Image:
    cells = rows * cols
    max_b = (cells * 2) // 8
    if len(wire) > max_b:
        raise ValueError(f"wire {len(wire)} B > grid capacity {max_b} B")
    symbols = bytes_to_grid_symbols(wire, cells)
    return render_symbols_grid_rgb(symbols, rows, cols, width, height, margin, gap)
