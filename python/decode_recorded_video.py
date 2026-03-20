#!/usr/bin/env python3
"""
Recorded video scaffold OR offline reassembly from raw wire `.bin` files.

Vision decoding from pixels is Phase 3; `--wire-dir` exercises the session assembler today.
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

from vdt_protocol_v1 import SessionAssembler, parse_frame


def scan_frame_buffer(gray: np.ndarray) -> Optional[bytes]:
    """Placeholder: homography + grid sampling would produce wire bytes here."""
    _ = gray
    return None


def reassemble_wire_directory(directory: Path) -> None:
    asm = SessionAssembler()
    files = sorted(directory.glob("*.bin"))
    if not files:
        raise SystemExit(f"No .bin files in {directory}")
    for path in files:
        wire = path.read_bytes()
        ok = asm.push_wire(wire)
        print(f"{path.name}: push {'ok' if ok else 'FAIL'}")
    if asm.is_complete():
        payload = asm.take_payload()
        if payload is None:
            print("Assembler rejected payload (CRC/size).")
        else:
            print(f"Assembled {len(payload)} bytes: {payload[:120]!r}{'...' if len(payload) > 120 else ''}")
    else:
        print("Incomplete session (need full descriptor + payload frames).")


def scan_video(path: Path, max_frames: int) -> None:
    if cv2 is None:
        raise SystemExit(f"OpenCV is required: {_cv_import_error}")
    cap = cv2.VideoCapture(str(path))
    if not cap.isOpened():
        raise SystemExit("Unable to open video")
    found = 0
    for i in range(max_frames):
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
    print(f"Scanned {max_frames} frames, structured hits: {found}")


def main() -> None:
    parser = argparse.ArgumentParser(description="VDT video scaffold or wire-dir reassembly.")
    parser.add_argument("video", nargs="?", type=Path, default=None, help="Input video path")
    parser.add_argument("--wire-dir", type=Path, default=None, help="Folder of wire frames (*.bin) to reassemble")
    parser.add_argument("--max-frames", type=int, default=200, help="Video frames to scan")
    args = parser.parse_args()

    if args.wire_dir is not None:
        reassemble_wire_directory(args.wire_dir)
    elif args.video is not None:
        scan_video(args.video, args.max_frames)
    else:
        parser.error("Provide a video path or --wire-dir")


if __name__ == "__main__":
    main()
