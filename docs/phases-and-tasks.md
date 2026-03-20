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
| `build_transfer_loop_cycle` (Safe / Normal + `TransferLoopOptions`) | [x] — `transfer_loop.*`, `vdt_transfer_loop_cycle_ex` |
| `SessionAssembler` + duplicate identical-chunk + duplicate descriptor (same metadata) no-op | [x] |
| Bit packing (MSB-first) | [x] — `bit_packing.*` |
| 2-bit / 4-level symbol helpers (V1 visual) | [x] — `symbol_mapping.hpp`, Swift/Python |
| C API: CRC, frame build/parse, loop cycle, layout, **session assembler** | [x] — `capi.*`, `vdt_session_assembler_*`; Python `SessionAssembler.push_decoded` matches `push_decoded` |
| Unit tests (CRC16/32, frames, loop, symbols, roundtrip) | [x] — `core/tests/` (Catch2); Python `unittest` `python/test_vdt_protocol_v1.py` |
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
| From **video frames**: classify → **wire** `parse_frame` / chunk assembly | [~] — `--assemble-grid`: `parse_frame` → `SessionAssembler.push_decoded` (needs **full** VT wire in grid decode; typical sender payload grid is too short per frame) |
| Timestamp / frame-skip policy for video | [~] — `--frame-stride` |
| Dump grid-decoded blobs to disk | [x] — `--write-decoded DIR` |
| Dump **merged** payloads from grid assembly | [x] — `--write-assembled DIR` (with `--assemble-grid`) |
| Optional `parse_frame` on grid output (debug) | [x] — `--try-parse-wire` |
| Debug overlays, missing-frame stats, logging | [~] — `--decode-grid` prints **read vs decoded** counts, stride skips, stop reason (`eof` / `max_frames`); with `--try-parse-wire`: magic prefix / short / parse_ok / parse_fail; **`--quiet`** skips per-frame lines; **`--wire-dir`** summary: push_ok / push_fail |
| End-to-end: **video file → full payload** (optical) | [ ] |

**Note:** C++ vision is wired on **iOS** via `vdt_sample_grid_full_bleed` (`VDTFullBleedGridSampler`). The **Python** video path still uses Swift/Python margin/gap sampling only (no homography in `decode_recorded_video.py` yet).

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
| Wire C++ `GridSampler` / homography in app | [x] — `vdt_sample_grid_full_bleed` (`FullBleedMarkerDetector` → normalized quad → `GridSampler`); Swift `VDTFullBleedGridSampler`; Receiver toggle **C++ full-bleed grid** |
| Session state machine (detect transfer, progress, complete) | [x] — `ReceiverPhase` + `phaseLabel`: idle → listening → decoded raw → wire → assembling → complete / rejected |
| Progress UI, errors / retry hints | [x] — phase caption + luma line + **RX:** auxiliary (sticky last payload); reject line suggests retry / alignment |
| Duplicate / confidence / adaptive thresholding | [x] — `TemporalSymbolMajority` (3-frame per-cell vote); optional **adaptive** min–max quartile thresholds in `LumaGridDecoder`; chunk/session consistency still enforced in core assembler |

---

## Phase 5 — Reliability & loop optimization

| Task | Status |
|------|--------|
| Loop ordering / descriptor frequency tuning | [x] — `TransferLoopOptions` (`repeat_descriptor_every_k_payloads`, `trailing_descriptor`); `vdt_transfer_loop_cycle_ex`; Swift `VDTTransferLoopBuildOptions` + sender stepper / toggle |
| Adaptive redundancy | [x] — Sender **Auto-stop (by frame count)** → `max(2, min(30, frames/2))` completed loops; user still overrides with fixed loop caps |
| Classifier + temporal smoothing / majority vote | [x] — Receiver vote depth 1…7; Python `majority_symbols` + `decode_recorded_video.py --vote-frames`; adaptive quartiles in `grid_codec` / `LumaGridDecoder` |
| Low-light / motion tolerance work | [x] — Adaptive thresholds; receiver **mean luma** + motion proxy hints; documented mitigations in `performance-baseline.md` |
| Measured success-rate improvements documented | [x] — `performance-baseline.md` Phase 5 table + reminder to log before/after in throughput worksheet (`constraints.md` targets unchanged) |

---

## Phase 6 — Product integration

| Task | Status |
|------|--------|
| Clean public Swift API (`encode`, `SenderView`, `ReceiverController`, config) | [x] — `VisualDataTransfer.encodeLoopCycle`, `VDTTransferConfiguration`, `SenderView` (`SenderScreen` alias), `ReceiverController` + `ReceiverView` |
| Feature flag, dedicated product screen, share/export | [x] — `VDTProductFlags.integratedExperienceEnabled` + demo **Settings** toggle; `ProductTransferExperience`; `ShareLink` on completed payload + JSON export from session log menu |
| Onboarding copy (“hold steady”), retry flows | [x] — `VDTOnboardingCopy`; first-run banner in product shell; **Reset assembly** + reject copy in `ReceiverView` |
| Device matrix / lighting / distance test log | [x] — `VDTSessionTestLog` / `VDTSessionTestEntry` (Application Support JSON); log sheet + export in product shell |
| “Production-ready” SDK packaging (XCFramework / docs) | [x] — [`sdk-packaging.md`](sdk-packaging.md) (SPM primary, optional CMake static lib / XCFramework notes) |

---

## Quick reference — where things live

| Area | Location |
|------|-----------|
| Protocol / loop / CRC | `core/include/vdt/`, `core/src/` |
| Tests | `core/tests/`, CMake + Catch2 |
| Swift kit + demo | `ios/Sources/`, `ios/Demo/`, root `Package.swift`; public API under `API/`, `ProductTransferExperience`, [`docs/sdk-packaging.md`](sdk-packaging.md) |
| Swift luma grid decode | `ios/Sources/VisualDataTransferKit/Vision/LumaGridDecoder.swift` |
| Python tools | `python/` (`unittest`: `test_vdt_protocol_v1.py`) |
| Specs & constraints | `docs/` |

---

*Update this file when you close tasks; keep [`roadmap.md`](roadmap.md) for narrative and milestones.*

---

## Development rhythm (for contributors / AI assist)

When continuing implementation in small steps, use: **implement next tasks → update this checklist → provide a concise `git commit` message** for the change set. (Same idea when messaging **“proceed”** in chat.)
