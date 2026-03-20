"""
Shared 2-bit grid layout + sampling (used by PNG and video decoders).

Layout matches `generate_test_frames.py` / Swift `VDTLayoutSpec` defaults.
"""

from __future__ import annotations

from typing import Callable, List, Optional


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


def luma_to_symbol(y: float) -> int:
    """Quantise luma to 0..3 (midpoints between encoder levels 0, 85, 170, 255)."""
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


def decode_grid_sampled(
    width: int,
    height: int,
    rows: int,
    cols: int,
    margin: int,
    gap: int,
    byte_length: Optional[int],
    sample_luma: Callable[[int, int], float],
) -> bytes:
    """Sample integer pixel centres inside each cell."""
    symbols: List[int] = []
    for r in range(rows):
        for c in range(cols):
            x0, y0, x1, y1 = layout_cell_rect(width, height, rows, cols, margin, gap, r, c)
            cx = int((x0 + x1) * 0.5)
            cy = int((y0 + y1) * 0.5)
            cx = max(0, min(width - 1, cx))
            cy = max(0, min(height - 1, cy))
            symbols.append(luma_to_symbol(sample_luma(cx, cy)))
    bits = symbols_to_bitstream(symbols)
    return bitstream_to_bytes(bits, max_bytes=byte_length)


def decode_grid_from_ndarray_bgr(
    image_bgr,
    rows: int,
    cols: int,
    margin: int,
    gap: int,
    byte_length: Optional[int],
):
    """OpenCV BGR or grayscale ``HxW`` / ``HxWxC`` array (requires numpy)."""
    import numpy as np

    arr = np.asarray(image_bgr)
    h, w = arr.shape[:2]

    def sample(cx: int, cy: int) -> float:
        if arr.ndim == 2:
            return float(arr[cy, cx])
        b, g, r = arr[cy, cx, 0], arr[cy, cx, 1], arr[cy, cx, 2]
        return 0.299 * r + 0.587 * g + 0.114 * b

    return decode_grid_sampled(w, h, rows, cols, margin, gap, byte_length, sample)
