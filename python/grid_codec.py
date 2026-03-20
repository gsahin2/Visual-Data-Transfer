"""
Shared 2-bit grid layout + sampling (used by PNG and video decoders).

Layout matches `generate_test_frames.py` / Swift `VDTLayoutSpec` defaults.
"""

from __future__ import annotations

from typing import Callable, List, Optional, Sequence, Tuple


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


def lumas_to_symbols(lumas: Sequence[float], adaptive: bool) -> List[int]:
    """Map per-cell luminance samples to 2-bit symbols (0..3). Adaptive uses min–max quartiles on this frame."""
    ys = [float(x) for x in lumas]
    if not adaptive:
        return [luma_to_symbol(y) for y in ys]
    lo = min(ys)
    hi = max(ys)
    span = hi - lo
    if span <= 4:
        return [luma_to_symbol(y) for y in ys]
    t1 = lo + span * 0.25
    t2 = lo + span * 0.50
    t3 = lo + span * 0.75
    out: List[int] = []
    for y in ys:
        if y < t1:
            out.append(0)
        elif y < t2:
            out.append(1)
        elif y < t3:
            out.append(2)
        else:
            out.append(3)
    return out


def majority_symbols(symbol_frames: Sequence[Sequence[int]]) -> List[int]:
    """Per-cell plurality over several symbol rows (each row length N, values 0..3)."""
    frames = [list(f) for f in symbol_frames]
    if not frames:
        return []
    n = len(frames[0])
    out: List[int] = []
    for i in range(n):
        counts = [0, 0, 0, 0]
        for f in frames:
            counts[f[i] & 3] += 1
        best = max(range(4), key=lambda k: counts[k])
        out.append(best)
    return out


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
    adaptive: bool = False,
) -> bytes:
    """Sample integer pixel centres inside each cell."""
    lumas: List[float] = []
    for r in range(rows):
        for c in range(cols):
            x0, y0, x1, y1 = layout_cell_rect(width, height, rows, cols, margin, gap, r, c)
            cx = int((x0 + x1) * 0.5)
            cy = int((y0 + y1) * 0.5)
            cx = max(0, min(width - 1, cx))
            cy = max(0, min(height - 1, cy))
            lumas.append(sample_luma(cx, cy))
    symbols = lumas_to_symbols(lumas, adaptive)
    bits = symbols_to_bitstream(symbols)
    return bitstream_to_bytes(bits, max_bytes=byte_length)


def grid_symbols_from_ndarray_bgr(
    image_bgr,
    rows: int,
    cols: int,
    margin: int,
    gap: int,
    adaptive: bool = False,
) -> List[int]:
    """Per-cell symbols (row-major) for temporal voting or custom packing."""
    import numpy as np

    arr = np.asarray(image_bgr)
    h, w = arr.shape[:2]

    def sample(cx: int, cy: int) -> float:
        if arr.ndim == 2:
            return float(arr[cy, cx])
        b, g, r = arr[cy, cx, 0], arr[cy, cx, 1], arr[cy, cx, 2]
        return 0.299 * r + 0.587 * g + 0.114 * b

    lumas: List[float] = []
    for r in range(rows):
        for c in range(cols):
            x0, y0, x1, y1 = layout_cell_rect(w, h, rows, cols, margin, gap, r, c)
            cx = int((x0 + x1) * 0.5)
            cy = int((y0 + y1) * 0.5)
            cx = max(0, min(w - 1, cx))
            cy = max(0, min(h - 1, cy))
            lumas.append(sample(cx, cy))
    return lumas_to_symbols(lumas, adaptive)


def decode_grid_from_ndarray_bgr(
    image_bgr,
    rows: int,
    cols: int,
    margin: int,
    gap: int,
    byte_length: Optional[int],
    adaptive: bool = False,
):
    """OpenCV BGR or grayscale ``HxW`` / ``HxWxC`` array (requires numpy)."""
    symbols = grid_symbols_from_ndarray_bgr(image_bgr, rows, cols, margin, gap, adaptive)
    bits = symbols_to_bitstream(symbols)
    return bitstream_to_bytes(bits, max_bytes=byte_length)


def _bilinear_luma(arr, sx: float, sy: float) -> float:
    import numpy as np

    a = np.asarray(arr)
    h, w = a.shape[:2]
    if w < 2 or h < 2:
        return 0.0
    sx = min(max(float(sx), 0.0), float(w - 1))
    sy = min(max(float(sy), 0.0), float(h - 1))
    x0 = int(np.floor(sx))
    y0 = int(np.floor(sy))
    x1 = min(x0 + 1, w - 1)
    y1 = min(y0 + 1, h - 1)
    tx = sx - x0
    ty = sy - y0

    def pix(ix: int, iy: int) -> float:
        if a.ndim == 2:
            return float(a[iy, ix])
        b, g, r = a[iy, ix, 0], a[iy, ix, 1], a[iy, ix, 2]
        return 0.299 * r + 0.587 * g + 0.114 * b

    p00, p10 = pix(x0, y0), pix(x1, y0)
    p01, p11 = pix(x0, y1), pix(x1, y1)
    v0 = p00 * (1.0 - tx) + p10 * tx
    v1 = p01 * (1.0 - tx) + p11 * tx
    return v0 * (1.0 - ty) + v1 * ty


def grid_symbols_full_bleed_from_ndarray_bgr(image_bgr, rows: int, cols: int, adaptive: bool = False) -> List[int]:
    """
    Uniform normalized grid → image pixels (matches C++ ``GridSampler`` with identity homography / full-bleed corners).
    """
    import numpy as np

    arr = np.asarray(image_bgr)
    h, w = arr.shape[:2]
    lumas: List[float] = []
    for r in range(rows):
        for c in range(cols):
            nx = (c + 0.5) / cols
            ny = (r + 0.5) / rows
            sx = nx * (w - 1)
            sy = ny * (h - 1)
            lumas.append(_bilinear_luma(arr, sx, sy))
    return lumas_to_symbols(lumas, adaptive)


def grid_symbols_quad_from_ndarray_bgr(
    image_bgr,
    rows: int,
    cols: int,
    quad_tl_tr_br_bl: Sequence[Tuple[float, float]],
    adaptive: bool = False,
) -> List[int]:
    """
    Map normalized unit-square cell centers through a homography to the image (TL, TR, BR, BL pixel corners).

    Requires OpenCV.
    """
    try:
        import cv2  # type: ignore
    except ImportError as exc:  # pragma: no cover
        raise ImportError("grid_symbols_quad_from_ndarray_bgr requires opencv-python") from exc

    import numpy as np

    arr = np.asarray(image_bgr)
    h, w = arr.shape[:2]
    if len(quad_tl_tr_br_bl) != 4:
        raise ValueError("quad must have 4 (x,y) points: TL, TR, BR, BL")
    inv_w = 1.0 / float(w - 1) if w > 1 else 0.0
    inv_h = 1.0 / float(h - 1) if h > 1 else 0.0
    src = np.array([[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]], dtype=np.float64)
    dst = np.array(
        [
            [quad_tl_tr_br_bl[0][0] * inv_w, quad_tl_tr_br_bl[0][1] * inv_h],
            [quad_tl_tr_br_bl[1][0] * inv_w, quad_tl_tr_br_bl[1][1] * inv_h],
            [quad_tl_tr_br_bl[2][0] * inv_w, quad_tl_tr_br_bl[2][1] * inv_h],
            [quad_tl_tr_br_bl[3][0] * inv_w, quad_tl_tr_br_bl[3][1] * inv_h],
        ],
        dtype=np.float64,
    )
    h_mat, _ = cv2.findHomography(src, dst, method=0)
    if h_mat is None:
        raise ValueError("homography solve failed")
    lumas: List[float] = []
    for r in range(rows):
        for c in range(cols):
            nx = (c + 0.5) / cols
            ny = (r + 0.5) / rows
            p = h_mat @ np.array([[nx], [ny], [1.0]], dtype=np.float64)
            pw = float(p[2, 0])
            if abs(pw) < 1e-8:
                px_n, py_n = nx, ny
            else:
                px_n = float(p[0, 0] / pw)
                py_n = float(p[1, 0] / pw)
            sx = px_n * (w - 1)
            sy = py_n * (h - 1)
            lumas.append(_bilinear_luma(arr, sx, sy))
    return lumas_to_symbols(lumas, adaptive)


def decode_grid_from_ndarray_bgr_mode(
    image_bgr,
    rows: int,
    cols: int,
    margin: int,
    gap: int,
    byte_length: Optional[int],
    adaptive: bool,
    sample_mode: str,
    quad_tl_tr_br_bl: Optional[Sequence[Tuple[float, float]]],
) -> bytes:
    mode = sample_mode.lower()
    if mode == "margin":
        syms = grid_symbols_from_ndarray_bgr(image_bgr, rows, cols, margin, gap, adaptive)
    elif mode == "fullbleed":
        syms = grid_symbols_full_bleed_from_ndarray_bgr(image_bgr, rows, cols, adaptive)
    elif mode == "quad":
        if quad_tl_tr_br_bl is None:
            raise ValueError("quad mode requires quad_tl_tr_br_bl")
        syms = grid_symbols_quad_from_ndarray_bgr(image_bgr, rows, cols, quad_tl_tr_br_bl, adaptive)
    else:
        raise ValueError(f"unknown sample_mode {sample_mode!r}")
    return bitstream_to_bytes(symbols_to_bitstream(syms), max_bytes=byte_length)
