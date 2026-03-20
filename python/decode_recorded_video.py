#!/usr/bin/env python3
"""
Recorded video: optional **grid decode** on each frame, wire-dir reassembly, or legacy scaffold scan.
With `--assemble-grid`, each successful `parse_frame` is passed to `SessionAssembler.push_decoded` (avoids re-parsing the same blob in `push_wire`).
"""

from __future__ import annotations

import argparse
import json
from collections import Counter, deque
from pathlib import Path
from typing import List, Optional, Tuple

import numpy as np

try:
    import cv2
except ImportError as exc:  # pragma: no cover - optional dependency path
    cv2 = None
    _cv_import_error = exc
else:
    _cv_import_error = None

from grid_codec import (
    bitstream_to_bytes,
    decode_grid_from_ndarray_bgr_mode,
    grid_symbols_from_ndarray_bgr,
    grid_symbols_full_bleed_from_ndarray_bgr,
    grid_symbols_quad_from_ndarray_bgr,
    majority_symbols,
    symbols_to_bitstream,
)
from vdt_protocol_v1 import FRAME_DESCRIPTOR, FRAME_PAYLOAD, SessionAssembler, parse_frame


def scan_frame_buffer(gray: np.ndarray) -> Optional[bytes]:
    """Try margin-layout grid decode + ``parse_frame`` (legacy video scan path)."""
    if cv2 is None:
        return None
    bgr = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
    blob = decode_grid_from_ndarray_bgr_mode(bgr, 12, 20, 8, 2, None, False, "margin", None)
    if len(blob) < 20:
        return None
    if parse_frame(blob):
        return blob
    return None


def reassemble_wire_directory(directory: Path) -> None:
    asm = SessionAssembler()
    files = sorted(directory.glob("*.bin"))
    if not files:
        raise SystemExit(f"No .bin files in {directory}")
    ok_n = 0
    fail_n = 0
    for path in files:
        wire = path.read_bytes()
        ok = asm.push_wire(wire)
        if ok:
            ok_n += 1
        else:
            fail_n += 1
        print(f"{path.name}: push {'ok' if ok else 'FAIL'}")
    print("---")
    print(f"wire-dir: {len(files)} files  push_ok={ok_n}  push_fail={fail_n}")
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


def _parse_quad_corners(s: str) -> List[Tuple[float, float]]:
    parts = [float(x.strip()) for x in s.split(",")]
    if len(parts) != 8:
        raise ValueError("expected 8 comma-separated numbers: x0,y0,…,x3,y3 (TL,TR,BR,BL)")
    return [
        (parts[0], parts[1]),
        (parts[2], parts[3]),
        (parts[4], parts[5]),
        (parts[6], parts[7]),
    ]


def _wire_line(parsed) -> str:
    hdr, payload = parsed
    if hdr.frame_type == FRAME_DESCRIPTOR:
        name = "descriptor"
    elif hdr.frame_type == FRAME_PAYLOAD:
        name = "payload"
    else:
        name = str(hdr.frame_type)
    return f"wire OK type={name} sid={hdr.session_id} chunk={hdr.chunk_index}/{hdr.chunk_count} plen={len(payload)}"


def decode_video_grid(
    path: Path,
    max_frames: int,
    stride: int,
    rows: int,
    cols: int,
    margin: int,
    gap: int,
    byte_length: Optional[int],
    resize_wh: Optional[Tuple[int, int]],
    write_decoded: Optional[Path],
    try_parse_wire: bool,
    assemble_grid: bool,
    write_assembled: Optional[Path],
    quiet: bool,
    vote_frames: int,
    adaptive_cells: bool,
    grid_sample_mode: str = "margin",
    quad_tl_tr_br_bl: Optional[List[Tuple[float, float]]] = None,
    summary_json: Optional[Path] = None,
) -> None:
    if cv2 is None:
        raise SystemExit(f"OpenCV is required: {_cv_import_error}")
    cap = cv2.VideoCapture(str(path))
    if not cap.isOpened():
        raise SystemExit("Unable to open video")
    decoded: List[bytes] = []
    i = 0
    processed = 0
    frames_read = 0
    parse_short = 0
    parse_ok = 0
    parse_fail = 0
    magic_prefix = 0
    asm = SessionAssembler() if assemble_grid else None
    asm_push_ok = 0
    asm_push_fail = 0
    asm_sessions_ok = 0
    asm_sessions_crc_fail = 0
    last_assembled_preview: Optional[bytes] = None
    assembled_seq = 0
    last_grid_frame_index = -1
    vf = max(1, vote_frames)
    sym_history: deque[List[int]] = deque(maxlen=vf)
    frame_timestamps_ms: List[Tuple[int, float]] = []

    def save_assembled_payload(merged: bytes, frame_idx: int) -> None:
        nonlocal assembled_seq
        if write_assembled is None:
            return
        write_assembled.mkdir(parents=True, exist_ok=True)
        assembled_seq += 1
        outp = write_assembled / f"assembled_{assembled_seq:04d}_frame_{frame_idx:06d}.bin"
        outp.write_bytes(merged)

    while processed < max_frames:
        ok, frame = cap.read()
        if not ok:
            break
        frames_read += 1
        if i % stride != 0:
            i += 1
            continue
        if resize_wh is not None:
            rw, rh = resize_wh
            frame = cv2.resize(frame, (rw, rh), interpolation=cv2.INTER_AREA)
        t_msec = float(cap.get(cv2.CAP_PROP_POS_MSEC))
        frame_timestamps_ms.append((i, t_msec))
        sm = grid_sample_mode.lower()
        if sm == "margin":
            syms = grid_symbols_from_ndarray_bgr(frame, rows, cols, margin, gap, adaptive_cells)
        elif sm == "fullbleed":
            syms = grid_symbols_full_bleed_from_ndarray_bgr(frame, rows, cols, adaptive_cells)
        elif sm == "quad":
            if quad_tl_tr_br_bl is None:
                raise SystemExit("--grid-sample quad requires --quad TL,TR,BR,BL coordinates")
            syms = grid_symbols_quad_from_ndarray_bgr(frame, rows, cols, quad_tl_tr_br_bl, adaptive_cells)
        else:
            raise SystemExit(f"unknown --grid-sample {grid_sample_mode!r}")
        sym_history.append(syms)
        voted = majority_symbols(list(sym_history)) if vf > 1 else syms
        blob = bitstream_to_bytes(symbols_to_bitstream(voted), max_bytes=byte_length)
        decoded.append(blob)
        preview = blob[:24]
        extra = ""
        parsed_blob = None
        if (try_parse_wire or assemble_grid) and len(blob) >= 20:
            parsed_blob = parse_frame(blob)
        if try_parse_wire:
            if len(blob) < 20:
                parse_short += 1
            else:
                if len(blob) >= 2 and blob[0] == 0x56 and blob[1] == 0x54:
                    magic_prefix += 1
                if parsed_blob:
                    parse_ok += 1
                    extra = f"  {_wire_line(parsed_blob)}"
                else:
                    parse_fail += 1
        if asm is not None and parsed_blob is not None:
            hdr, pl = parsed_blob
            if asm.push_decoded(hdr, pl):
                asm_push_ok += 1
            else:
                asm_push_fail += 1
            if asm.is_complete():
                merged = asm.take_payload()
                if merged is not None:
                    asm_sessions_ok += 1
                    last_assembled_preview = merged[:120]
                    save_assembled_payload(merged, i)
                    if not quiet:
                        print(
                            f"frame {i}: ASSEMBLED {len(merged)} B  "
                            f"{merged[:80]!r}{'...' if len(merged) > 80 else ''}"
                        )
                else:
                    asm_sessions_crc_fail += 1
                    if not quiet:
                        print(f"frame {i}: assembler complete but CRC/size rejected")
        if not quiet:
            print(f"frame {i}: decoded {len(blob)} B  head={preview!r}{extra}")
        if write_decoded is not None:
            write_decoded.mkdir(parents=True, exist_ok=True)
            outp = write_decoded / f"frame_{i:06d}.bin"
            outp.write_bytes(blob)
        last_grid_frame_index = i
        processed += 1
        i += 1
    cap.release()
    skipped_stride = max(0, frames_read - processed)
    stop_reason = "max_frames" if processed >= max_frames else "eof"
    print("---")
    print(
        f"read: {frames_read} video frames  decoded: {processed}  "
        f"stride={stride} (not decoded due to stride: {skipped_stride})  stop={stop_reason}  "
        f"vote_frames={vf}  adaptive_cells={adaptive_cells}"
    )
    if try_parse_wire:
        print(
            f"wire parse: magic_0x5654_prefix={magic_prefix}  "
            f"too_short_lt20={parse_short}  parse_ok={parse_ok}  parse_fail={parse_fail}"
        )
    if assemble_grid and asm is not None:
        eof_drained_ok = False
        if asm.is_complete():
            pl = asm.take_payload()
            if pl is not None:
                asm_sessions_ok += 1
                last_assembled_preview = pl[:120]
                eof_drained_ok = True
                save_assembled_payload(pl, max(0, last_grid_frame_index))
                print(
                    f"assembly: session finished at EOF → {len(pl)} B  "
                    f"{pl[:100]!r}{'...' if len(pl) > 100 else ''}"
                )
            else:
                asm_sessions_crc_fail += 1
                print("assembly: EOF state was complete but take_payload rejected (CRC/size)")
        preview_note = (
            f"  last_ok_preview={last_assembled_preview!r}" if last_assembled_preview is not None else ""
        )
        print(
            f"assembly: push_ok={asm_push_ok}  push_fail={asm_push_fail}  "
            f"sessions_ok={asm_sessions_ok}  crc_or_size_reject={asm_sessions_crc_fail}{preview_note}"
        )
        if asm_push_ok == 0:
            print("assembly: no valid wire frames were pushed (grid blobs are not full VT wire?)")
        elif (
            not asm.is_complete()
            and not eof_drained_ok
            and asm_sessions_ok == 0
        ):
            print("assembly: incomplete at EOF (partial session; need more frames or full-wire grid)")
        if write_assembled is not None and assembled_seq > 0:
            print(f"assembly: wrote {assembled_seq} payload file(s) → {write_assembled}")
    ctr = Counter(decoded)
    if not decoded:
        print("No grid decodes accumulated.")
    else:
        most_common = ctr.most_common(3)
        print(f"Unique decodes: {len(ctr)}  (top {len(most_common)} by count)")
        for blob, count in most_common:
            print(f"  x{count}: {blob[:48]!r}{'...' if len(blob) > 48 else ''}")

    summary: dict = {
        "video_path": str(path),
        "frames_read": frames_read,
        "frames_decoded": processed,
        "skipped_by_stride": max(0, frames_read - processed),
        "stop_reason": stop_reason,
        "frame_stride": stride,
        "grid_sample_mode": grid_sample_mode,
        "vote_frames": vf,
        "adaptive_cells": adaptive_cells,
        "unique_decode_blobs": len(ctr),
        "frame_timestamps_ms": frame_timestamps_ms[:200],
    }
    if try_parse_wire:
        summary["wire_parse"] = {
            "magic_0x5654_prefix": magic_prefix,
            "too_short_lt20": parse_short,
            "parse_ok": parse_ok,
            "parse_fail": parse_fail,
        }
    if assemble_grid and asm is not None:
        summary["assembly"] = {
            "push_ok": asm_push_ok,
            "push_fail": asm_push_fail,
            "sessions_ok": asm_sessions_ok,
            "crc_or_size_reject": asm_sessions_crc_fail,
            "complete_at_eof": asm.is_complete(),
        }
    if summary_json is not None:
        summary_json.parent.mkdir(parents=True, exist_ok=True)
        summary_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")
        if not quiet:
            print(f"summary-json: {summary_json}")


def main() -> None:
    parser = argparse.ArgumentParser(description="VDT: wire-dir, video grid decode, or legacy video scan.")
    parser.add_argument("video", nargs="?", type=Path, default=None, help="Input video path")
    parser.add_argument("--wire-dir", type=Path, default=None, help="Folder of wire frames (*.bin) to reassemble")
    parser.add_argument(
        "--decode-grid",
        action="store_true",
        help="Decode 2-bit grid from each video frame (see --grid-sample)",
    )
    parser.add_argument("--max-frames", type=int, default=200, help="Max frames to process (grid or scan)")
    parser.add_argument("--frame-stride", type=int, default=1, help="Use every Nth frame for --decode-grid")
    parser.add_argument("--rows", type=int, default=12)
    parser.add_argument("--cols", type=int, default=20)
    parser.add_argument("--margin", type=int, default=8)
    parser.add_argument("--gap", type=int, default=2)
    parser.add_argument("--byte-length", type=int, default=None, help="Trim decoded bytes (payload length hint)")
    parser.add_argument(
        "--resize",
        type=str,
        default=None,
        help="WxH resize before decode e.g. 640x480 (match generator resolution)",
    )
    parser.add_argument(
        "--write-decoded",
        type=Path,
        default=None,
        help="With --decode-grid: write each grid-decoded blob to this directory",
    )
    parser.add_argument(
        "--try-parse-wire",
        action="store_true",
        help="After grid decode, try v1 parse_frame(blob) (e.g. if screen showed raw wire)",
    )
    parser.add_argument(
        "--assemble-grid",
        action="store_true",
        help="With --decode-grid: feed parseable wire frames into SessionAssembler (video → payload when grid carries full wire)",
    )
    parser.add_argument(
        "--write-assembled",
        type=Path,
        default=None,
        help="With --assemble-grid: write each merged payload to this directory (assembled_NNNN_frame_FFFFFF.bin)",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="With --decode-grid: no per-frame lines; still print summary stats",
    )
    parser.add_argument(
        "--vote-frames",
        type=int,
        default=1,
        help="With --decode-grid: per-cell majority over last N symbol frames (temporal smoothing)",
    )
    parser.add_argument(
        "--adaptive-cells",
        action="store_true",
        help="With --decode-grid: min–max quartile thresholds per frame (low-light contrast stretch)",
    )
    parser.add_argument(
        "--grid-sample",
        choices=["margin", "fullbleed", "quad"],
        default="margin",
        help="Video frame sampling: margin/gap (sender layout), full-bleed bilinear, or quad homography",
    )
    parser.add_argument(
        "--quad",
        type=str,
        default=None,
        help="With --grid-sample quad: TL,TR,BR,BL as x0,y0,x1,y1,x2,y2,x3,y3 (pixels)",
    )
    parser.add_argument(
        "--summary-json",
        type=Path,
        default=None,
        help="Write decode statistics + frame timestamps (CAP_PROP_POS_MSEC) to this JSON file",
    )
    args = parser.parse_args()

    resize_wh: Optional[Tuple[int, int]] = None
    if args.resize:
        try:
            w_s, h_s = args.resize.lower().split("x", 1)
            resize_wh = (int(w_s), int(h_s))
        except ValueError as exc:
            raise SystemExit("--resize must be like 640x480") from exc

    if args.wire_dir is not None:
        reassemble_wire_directory(args.wire_dir)
    elif args.decode_grid:
        if args.video is None:
            parser.error("--decode-grid requires a video path")
        if args.write_assembled is not None and not args.assemble_grid:
            parser.error("--write-assembled requires --assemble-grid")
        quad_pts: Optional[List[Tuple[float, float]]] = None
        if args.grid_sample == "quad":
            if not args.quad:
                parser.error("--grid-sample quad requires --quad")
            try:
                quad_pts = _parse_quad_corners(args.quad)
            except ValueError as exc:
                parser.error(str(exc))
        decode_video_grid(
            args.video,
            args.max_frames,
            args.frame_stride,
            args.rows,
            args.cols,
            args.margin,
            args.gap,
            args.byte_length,
            resize_wh,
            args.write_decoded,
            args.try_parse_wire,
            args.assemble_grid,
            args.write_assembled,
            args.quiet,
            args.vote_frames,
            args.adaptive_cells,
            args.grid_sample,
            quad_pts,
            args.summary_json,
        )
    elif args.video is not None:
        scan_video(args.video, args.max_frames)
    else:
        parser.error("Provide a video path, --wire-dir, or --decode-grid with video")


if __name__ == "__main__":
    main()
