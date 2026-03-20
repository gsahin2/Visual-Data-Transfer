#!/usr/bin/env python3
"""
Scan a recorded video for V1 frames (CRC-valid) and dump payload sizes.

Full vision decoding belongs in the C++ core; this tool validates tooling and capture pipelines.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Optional

import numpy as np

try:
    import cv2
except ImportError as exc:  # pragma: no cover - optional dependency path
    cv2 = None
    _cv_import_error = exc
else:
    _cv_import_error = None

from vdt_protocol_v1 import HEADER_BYTES, parse_frame


def scan_frame_buffer(gray: np.ndarray) -> Optional[bytes]:
    """
    Placeholder hook: in a full pipeline, homography + grid sampling would recover bytes.
    Here we only demonstrate I/O around OpenCV frames.
    """
    _ = gray
    return None


def main() -> None:
    if cv2 is None:
        raise SystemExit(f"OpenCV is required: {_cv_import_error}")

    parser = argparse.ArgumentParser(description="Decode / inspect recorded VDT video (scaffold).")
    parser.add_argument("video", type=Path, help="Input video path")
    parser.add_argument("--max-frames", type=int, default=200, help="Frames to scan")
    args = parser.parse_args()

    cap = cv2.VideoCapture(str(args.video))
    if not cap.isOpened():
        raise SystemExit("Unable to open video")

    found = 0
    for i in range(args.max_frames):
        ok, frame = cap.read()
        if not ok:
            break
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        maybe = scan_frame_buffer(gray)
        if maybe:
            parsed = parse_frame(maybe)
            if parsed:
                found += 1
                print(f"frame {i}: payload {len(parsed[1])} bytes")

    cap.release()
    print(f"Scanned {args.max_frames} frames, structured hits: {found}")


if __name__ == "__main__":
    main()
