# Phases & tasks — status

This is the working checklist for **Visual Data Transfer V1** (20 KiB target). It complements [`roadmap.md`](roadmap.md) with finer tasks and **done / not done** markers as of the current repository.

**Legend:** `[x]` implemented or documented in-repo · `[~]` partial / scaffold only · `[ ]` not started

---

## V1 completion criteria (product)

| Task | Status |
|------|--------|
| 20 KiB payload transferred end-to-end (optical path) | [ ] |
| ≤ ~20 s average completion (Normal, nominal setup) | [ ] |
| ≥ 95% success in defined “normal” conditions | [ ] |
| ≥ 2 device models validated | [ ] |
| Sender + receiver UX stable | [~] |

---

## Phase 0 — Constraints & baseline

**Goal:** Lock parameters; record measurements.

| Task | Status |
|------|--------|
| Document payload cap (20 KiB), timing budget, success metrics | [x] — [`constraints.md`](constraints.md) |
| Document grids 12×20, 16×24; 2-bit cells; Safe / Normal | [x] |
| `performance-baseline.md` template (throughput table, error categories) | [x] |
| **Filled-in** benchmark numbers (measured bits/s, real throughput) | [ ] |
| **Filled-in** decoding error pattern notes from hardware tests | [ ] |

---

## Phase 1 — Protocol V1 (core)

**Goal:** Deterministic framing and integrity in C++ (and mirrors).

| Task | Status |
|------|--------|
| Frame header + magic, version, types, CRC16 per frame | [x] — `protocol/frame.*`, tests |
| Max 20 KiB transfer, 1024 B per-frame payload cap | [x] — `constants.hpp` |
| `Payload` vs `Descriptor` frame types | [x] |
| Descriptor body (20 B): size, frame count, CRC32, encoding mode | [x] — `descriptor.*` |
| CRC32 IEEE + verify on assemble after descriptor | [x] — `crc32.*`, `session_assembler.cpp` |
| Session chunking + `FrameEncoder` | [x] |
| `build_transfer_loop_cycle` (Safe / Normal) | [x] — `transfer_loop.*` |
| `SessionAssembler` + duplicate identical-chunk tolerance | [x] |
| Bit packing (MSB-first) | [x] — `bit_packing.*` |
| 2-bit / 4-level symbol helpers (V1 visual) | [x] — `symbol_mapping.hpp`, Swift/Python |
| C API: CRC, frame build/parse, loop cycle, layout, **session assembler** | [x] — `capi.*`, `vdt_session_assembler_*` |
| Unit tests (CRC16/32, frames, loop, symbols, roundtrip) | [x] — `core/tests/` |
| `protocol-v1.md` | [x] |

---

## Phase 2 — Sender pipeline

**Goal:** Continuous on-screen loop and decode-safe chrome.

| Task | Status |
|------|--------|
| Input → core loop cycle (Swift `VDTFramedSession`) | [x] |
| Safe / Normal mode selection (UI + wire) | [x] |
| Loop playback: play / pause, FPS, step, reset | [x] — `TransferLoopPlayer` |
| Per-frame wire parse + DATA vs DESCRIPTOR preview | [x] — `VDTWireFrameParser`, `SenderTransmissionView` |
| Fixed grid layout + `VDTLayoutSpec` / core `cell_rect` | [x] |
| Corner L-markers (pulse does not change cell pixels) | [x] — `CornerMarkersView` |
| Matrix-style **side** strips (grid not covered) | [x] — `MatrixRainStrip` |
| Idle + transmit preview share same inner grid width | [x] — `SenderScreen` |
| **CADisplayLink**-locked timing vs wall clock | [x] — iOS: `CADisplayLink` in `TransferLoopPlayer`; macOS/SPM: `Timer` |
| Matrix animation **over** data cells (decode-proven safe) | [x] — `MatrixRainGutterOverlay`: glyphs only in margin + inter-cell **gaps** (cell centers unchanged for `LumaGridDecoder`) |
| Automated “loop until user stops” **product** scheduler (beyond one cycle buffer) | [x] — `TransferLoopPlayer.completedLoopCount`, optional `maxCompletedLoops` auto-pause; Sender **Auto-stop** menu (1 / 3 / 10 loops or until paused) |

---

## Phase 3 — Recorded decode (receiver V1)

**Goal:** Reconstruct payload from recordings / pixels.

| Task | Status |
|------|--------|
| Wire-level `SessionAssembler` (Python) | [x] — `vdt_protocol_v1.py` |
| Reassemble from folder of `.bin` wire dumps | [x] — `decode_recorded_video.py --wire-dir` |
| Synthetic **PNG** grid → bytes (optical round-trip) | [x] — `grid_decode_image.py` |
| OpenCV: extract frames from video | [x] — `decode_recorded_video.py` |
| From **video frames**: full-bleed grid sample + 2-bit → bytes | [x] — `--decode-grid` + `grid_codec.py` (no homography) |
| From **video frames**: markers, homography, crop | [ ] |
| From **video frames**: classify → **wire** `parse_frame` / chunk assembly | [~] — `--assemble-grid` streams valid `parse_frame` hits into `SessionAssembler` (needs **full** VT wire in grid decode; typical sender payload grid is too short per frame) |
| Timestamp / frame-skip policy for video | [~] — `--frame-stride` |
| Dump grid-decoded blobs to disk | [x] — `--write-decoded DIR` |
| Optional `parse_frame` on grid output (debug) | [x] — `--try-parse-wire` |
| Debug overlays, missing-frame stats, logging | [~] — `--decode-grid` prints **read vs decoded** counts, stride skips, stop reason (`eof` / `max_frames`); with `--try-parse-wire`: magic prefix / short / parse_ok / parse_fail; **`--quiet`** skips per-frame lines; **`--wire-dir`** summary: push_ok / push_fail |
| End-to-end: **video file → full payload** (optical) | [ ] |

**Note:** C++ has `GridSampler`, `homography`, `FullBleedMarkerDetector` for future wiring; not yet driven from Python video path.

---

## Phase 4 — Live camera receiver (iOS)

**Goal:** Real-time decode on device.

| Task | Status |
|------|--------|
| AVFoundation capture + preview | [x] — `CaptureSessionController`, `ReceiverScreen` |
| Luma buffer callback to delegate | [x] |
| Full-bleed **2-bit grid** decode from luma (Swift, Python-parity) | [x] — `LumaGridDecoder` + `ReceiverScreen` status |
| If luma decodes to raw **VT** wire, show parse in status | [x] — magic `0x56 0x54` + `VDTWireFrameParser` |
| **`VDTSessionReassembler`** (core assembler via C API) | [x] — when a **full** wire frame parses; normal sender grid is **payload-only** (~60 B/cell budget), so E2E optical assembly needs larger grid or full-wire mode later |
| Wire C++ `GridSampler` / homography in app | [ ] |
| Session state machine (detect transfer, progress, complete) | [ ] |
| Progress UI, errors / retry hints | [~] — basic status text |
| Duplicate / confidence / adaptive thresholding | [ ] |

---

## Phase 5 — Reliability & loop optimization

| Task | Status |
|------|--------|
| Loop ordering / descriptor frequency tuning | [ ] |
| Adaptive redundancy | [ ] |
| Classifier + temporal smoothing / majority vote | [ ] |
| Low-light / motion tolerance work | [ ] |
| Measured success-rate improvements documented | [ ] |

---

## Phase 6 — Product integration

| Task | Status |
|------|--------|
| Clean public Swift API (`encode`, `SenderView`, `ReceiverController`, config) | [ ] |
| Feature flag, dedicated product screen, share/export | [ ] |
| Onboarding copy (“hold steady”), retry flows | [ ] |
| Device matrix / lighting / distance test log | [ ] |
| “Production-ready” SDK packaging (XCFramework / docs) | [ ] |

---

## Quick reference — where things live

| Area | Location |
|------|-----------|
| Protocol / loop / CRC | `core/include/vdt/`, `core/src/` |
| Tests | `core/tests/`, CMake + Catch2 |
| Swift kit + demo | `ios/Sources/`, `ios/Demo/`, root `Package.swift` |
| Swift luma grid decode | `ios/Sources/VisualDataTransferKit/Vision/LumaGridDecoder.swift` |
| Python tools | `python/` |
| Specs & constraints | `docs/` |

---

*Update this file when you close tasks; keep [`roadmap.md`](roadmap.md) for narrative and milestones.*

---

## Development rhythm (for contributors / AI assist)

When continuing implementation in small steps, use: **implement next tasks → update this checklist → provide a concise `git commit` message** for the change set. (Same idea when messaging **“proceed”** in chat.)
