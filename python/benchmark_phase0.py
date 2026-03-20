#!/usr/bin/env python3
"""
Emit repeatable **synthetic** timings for Phase 0 / CI (not a substitute for hardware throughput).

Run: ``python3 benchmark_phase0.py`` from ``python/`` (or repo root with ``python/benchmark_phase0.py``).
"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

# Allow running as ``python3 benchmark_phase0.py`` from repo root
_ROOT = Path(__file__).resolve().parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from benchmark_symbols import expand_to_two_bit_cells  # noqa: E402
from grid_codec import decode_grid_sampled  # noqa: E402
from optical_wire import bytes_to_grid_symbols, render_symbols_grid_rgb  # noqa: E402


def main() -> None:
    rows, cols = 12, 20
    cells = rows * cols
    payload = bytes((i & 0xFF) for i in range(20480))
    iters = 200

    t0 = time.perf_counter()
    for _ in range(iters):
        expand_to_two_bit_cells(payload, cells)
    t_sym = time.perf_counter() - t0

    wire = b"\x56\x54" + bytes(40)  # fake wire prefix + padding to stay <= 60 B
    symbols = bytes_to_grid_symbols(wire, cells)
    w, h, m, g = 640, 480, 8, 2
    img = render_symbols_grid_rgb(symbols, rows, cols, w, h, m, g)
    iw, ih = img.size

    def sample(cx: int, cy: int) -> float:
        r, g0, b = img.getpixel((cx, cy))
        return 0.299 * r + 0.587 * g0 + 0.114 * b

    t1 = time.perf_counter()
    for _ in range(iters):
        decode_grid_sampled(iw, ih, rows, cols, m, g, len(wire), sample, False)
    t_dec = time.perf_counter() - t1

    out = {
        "tool": "benchmark_phase0.py",
        "symbol_expand_iters": iters,
        "symbol_expand_total_s": round(t_sym, 6),
        "symbol_expand_per_iter_us": round(t_sym / iters * 1e6, 2),
        "grid_decode_png_iters": iters,
        "grid_decode_total_s": round(t_dec, 6),
        "grid_decode_per_iter_us": round(t_dec / iters * 1e6, 2),
        "note": "Synthetic CPU timings on developer machine; re-run for your hardware.",
    }
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
