#!/usr/bin/env python3
"""
Micro-benchmark for V1 symbol packing (2 bits per cell).
"""

from __future__ import annotations

import argparse
import time
from typing import List


def expand_to_two_bit_cells(message: bytes, cells: int) -> List[int]:
    out: List[int] = []
    bit_buf = 0
    bit_count = 0
    idx = 0
    for _ in range(cells):
        while bit_count < 2:
            if idx < len(message):
                bit_buf = (bit_buf << 8) | message[idx]
                idx += 1
                bit_count += 8
            else:
                bit_buf <<= 2
                bit_count += 2
        shift = bit_count - 2
        out.append((bit_buf >> shift) & 0x03)
        bit_count -= 2
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bytes", type=int, default=4096, help="Synthetic payload size")
    parser.add_argument("--cells", type=int, default=240, help="Grid cells (e.g. 12x20)")
    parser.add_argument("--iters", type=int, default=500)
    args = parser.parse_args()

    payload = bytes((i & 0xFF) for i in range(args.bytes))
    start = time.perf_counter()
    for _ in range(args.iters):
        expand_to_two_bit_cells(payload, args.cells)
    elapsed = time.perf_counter() - start
    print(f"{args.iters} iterations in {elapsed:.4f}s ({elapsed / args.iters * 1e6:.1f} µs/iter)")


if __name__ == "__main__":
    main()
