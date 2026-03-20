#!/usr/bin/env python3
"""
Build a short MP4 from synthetic **wire-in-grid** PNG frames (for ``decode_recorded_video --decode-grid --assemble-grid``).

Requires: opencv-python, Pillow.

Example::

  python3 build_synthetic_optical_video.py --message "optical video" --out /tmp/vdt_syn.mp4
  # If mp4v is unavailable, the script writes ``vdt_syn.avi`` (MJPG) next to the .mp4 path.
  python3 decode_recorded_video.py /tmp/vdt_syn.avi --decode-grid --assemble-grid --try-parse-wire --max-frames 500
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np

from optical_wire import max_optical_payload_bytes, render_wire_as_grid_png_rgb
from vdt_protocol_v1 import encode_session_wires


def main() -> None:
    parser = argparse.ArgumentParser(description="Synthetic optical video from VT wire grids.")
    parser.add_argument("--message", default="Hello from synthetic optical video", help="UTF-8 payload")
    parser.add_argument("--session", type=int, default=1)
    parser.add_argument("--rows", type=int, default=12)
    parser.add_argument("--cols", type=int, default=20)
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--fps", type=float, default=12.0)
    parser.add_argument("--out", type=Path, required=True, help="Output .mp4 path")
    args = parser.parse_args()

    msg = args.message.encode("utf-8")
    mx = max_optical_payload_bytes(args.rows, args.cols)
    wires = encode_session_wires(args.session & 0xFFFFFFFF, msg, max_payload_per_chunk=mx)

    size = (args.width, args.height)
    out_path = args.out
    candidates: list[tuple[str, str]] = [
        ("mp4v", str(out_path)),
    ]
    if out_path.suffix.lower() in {".mp4", ".m4v"}:
        alt = out_path.with_suffix(".avi")
        candidates.append(("MJPG", str(alt)))

    vw: cv2.VideoWriter | None = None
    used_path = out_path
    for fourcc_name, path_str in candidates:
        fourcc = cv2.VideoWriter_fourcc(*fourcc_name)
        w = cv2.VideoWriter(path_str, fourcc, args.fps, size)
        if w.isOpened():
            vw = w
            used_path = Path(path_str)
            if path_str != str(out_path):
                print(f"Note: mp4 writer unavailable; using {used_path.name} (MJPG) instead.")
            break
        w.release()
    if vw is None:
        raise SystemExit(
            "VideoWriter failed (codec/path?). Try --out path/to/out.avi or install a working ffmpeg/OpenCV video backend."
        )

    for wire in wires:
        pil = render_wire_as_grid_png_rgb(wire, args.rows, args.cols, args.width, args.height)
        rgb = np.array(pil)
        bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
        vw.write(bgr)
    vw.release()
    print(f"Wrote {len(wires)} frames → {used_path} ({args.fps} fps)")


if __name__ == "__main__":
    main()
