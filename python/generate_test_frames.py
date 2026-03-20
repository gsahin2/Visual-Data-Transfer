#!/usr/bin/env python3
"""
Generate deterministic PNG frames that visualize a payload as a symbol grid.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

from vdt_protocol_v1 import FRAME_DESCRIPTOR, FrameHeader, TransferDescriptorV1, build_frame, crc32_ieee


def message_to_two_bit_symbols(message: bytes, cells: int) -> list[int]:
    """V1 visual: 2 bits per cell, MSB-first within bytes."""
    out: list[int] = []
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


def render_grid(
    rows: int,
    cols: int,
    symbols: list[int],
    width: int,
    height: int,
    margin: int,
    gap: int,
) -> Image.Image:
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


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate VDT-style test frames as PNG images.")
    parser.add_argument("--message", default="VDT test", help="UTF-8 payload text")
    parser.add_argument("--session", type=int, default=1, help="Session id")
    parser.add_argument("--rows", type=int, default=12)
    parser.add_argument("--cols", type=int, default=20)
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--out-dir", type=Path, default=Path("../samples/generated"))
    args = parser.parse_args()

    message = args.message.encode("utf-8")
    cells = args.rows * args.cols
    symbols = message_to_two_bit_symbols(message, cells)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    grid_path = args.out_dir / "grid_preview.png"
    render_grid(args.rows, args.cols, symbols, args.width, args.height, margin=8, gap=2).save(grid_path)

    desc = TransferDescriptorV1(
        transfer_id=args.session & 0xFFFFFFFF,
        payload_byte_length=len(message),
        payload_crc32=crc32_ieee(message),
        data_frame_count=1,
        encoding_mode=1,
    )
    desc_bytes = desc.serialize()
    dheader = FrameHeader(
        version=1,
        frame_type=FRAME_DESCRIPTOR,
        flags=0,
        session_id=args.session & 0xFFFFFFFF,
        chunk_index=0,
        chunk_count=1,
        payload_length=len(desc_bytes),
    )
    desc_path = args.out_dir / "descriptor0.bin"
    desc_path.write_bytes(build_frame(dheader, desc_bytes))

    header = FrameHeader(
        version=1,
        frame_type=0,
        flags=0,
        session_id=args.session & 0xFFFFFFFF,
        chunk_index=0,
        chunk_count=1,
        payload_length=len(message),
    )
    wire = build_frame(header, message)
    raw_path = args.out_dir / "payload0.bin"
    raw_path.write_bytes(wire)

    print(f"Wrote {grid_path}")
    print(f"Wrote descriptor {desc_path}")
    print(f"Wrote payload wire frame {raw_path} ({len(wire)} bytes)")


if __name__ == "__main__":
    main()
