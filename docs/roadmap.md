# V1 Roadmap — 20 KiB target

This roadmap tracks delivery of **reliable ~20 KB** transfers via **looping visual frames**, with the receiver recovering the full payload by observing long enough.

**Task-level checklist (done / partial / todo):** [`phases-and-tasks.md`](phases-and-tasks.md)

## V1 goal

- Transfer up to **20 KiB** using repeated visual frames.
- **5–20 s** typical completion in Normal mode under nominal conditions.
- **≥ 95%** success at **~30–50 cm**, handheld-friendly.
- **≥ 2** validated device models.

## Phase 0 — Constraints & baseline

**Goal:** Lock parameters and measure reality.

- Payload cap, timing budget, success metrics.
- Benchmark bits/frame and effective throughput; grid sizes **12×20** and **16×24**; 2-bit cells; Safe vs Normal.
- Characterize blur, exposure, motion.

**Deliverables:** [`constraints.md`](constraints.md), [`performance-baseline.md`](performance-baseline.md), chosen configuration (summarized in `constraints.md`).

## Phase 1 — Protocol V1 (core design)

**Goal:** Deterministic framing and integrity.

- Transfer session model (ID, size, modes, hash).
- Frame header + **Descriptor** + **Payload** types; descriptor repeats in loop.
- CRC16 per frame; **CRC32** over full payload in descriptor; assembler verification.
- Bit packing, segmentation, **2 bits/cell** symbol mapping (visual).

**Deliverables:** [`protocol-v1.md`](protocol-v1.md), C++ encoder/decoder + loop builder (`build_transfer_loop_cycle`, `SessionAssembler`).

## Phase 2 — Sender pipeline

**Goal:** Continuous on-screen loop.

- Input → chunking → framed loop cycle; scheduler (repeat Safe/Normal policies).
- Fixed layout, symbol grid, **corner markers**, timing; Matrix-style column animation / glow that **preserves** decodability.
- iOS: sender screen, preview, **mode selection**, loop playback controls.

**Deliverables:** Swift sender demo with looping transmission (extends current `SenderScreen` / scheduler).

**Progress (repo):** `TransferLoopPlayer` (FPS + play/step), `SenderTransmissionView` (parse wire via `vdt_frame_parse`, DATA vs DESCRIPTOR preview), **corner L-markers** with subtle pulse (data cells unchanged). **`MatrixRainStrip`** side columns (grid width reduced so symbols stay clear of decoration). Heavier Matrix effects over cells remain **out of scope** until classified as decode-safe.

## Phase 3 — Recorded decode (receiver V1)

**Goal:** Decode from **video files** first (stable).

- Frame extract, timestamps, skip strategy; marker + homography; crop; grid sample; 2-bit classification.
- Bitstream reassembly, CRC checks, duplicate handling, hash verify.
- Debug overlays, logging, missing-frame stats.

**Deliverables:** Python or C++ recorded decoder achieving full payload reconstruction.

**Progress (repo):** `python/vdt_protocol_v1.SessionAssembler` + `decode_recorded_video.py --wire-dir` to reassemble from raw `.bin` wire files (golden / simulator dumps). **`grid_codec.py`** + **`grid_decode_image.py`** for PNGs; **`decode_recorded_video.py --decode-grid`** samples the same grid on each video frame (full-bleed, optional `--resize`). Homography / markers / wire extraction from video still **todo**.

## Phase 4 — Live camera receiver

**Goal:** Real-time iOS camera path.

- AVFoundation buffering & rate control; per-frame vision; session lifecycle; progress UI; errors/retry hints.
- Duplicate filtering, confidence, adaptive thresholding (initial versions).

**Deliverables:** Live receiver with progress and completion states.

## Phase 5 — Reliability & loop optimization

**Goal:** Improve real-world success.

- Loop ordering, descriptor frequency, adaptive redundancy, classifier accuracy, temporal smoothing, majority vote, low-light and motion tolerance.

**Deliverables:** Measurable success-rate gains; stable UX.

## Phase 6 — Product integration

**Goal:** Ship as a feature + SDK.

- Swift API: `encode(payload:)`, `SenderView`, `ReceiverController`, config (mode, speed, density).
- Feature flag, Visual Transfer screen, share/export; copy and onboarding (“hold steady”); device matrix tests.

**Deliverables:** Production-ready feature surface; documented SDK.

---

## V1 completion checklist

- [ ] 20 KiB payload transferred end-to-end.
- [ ] ≤ ~20 s average completion (Normal, nominal setup).
- [ ] ≥ 95% success in defined “normal” conditions.
- [ ] ≥ 2 devices validated.
- [ ] Sender + receiver UX stable.

## Design principles

1. **Deterministic layout** over visual randomness.  
2. **Loop redundancy** over single-pass delivery.  
3. **Small-payload reliability** before chasing larger sizes.  
4. **Separate** visual presentation from binary framing (protocol in C++, render/capture in Swift).

## Optional GitHub milestone names

| Milestone | Focus |
|-----------|--------|
| `v0.1.0-protocol` | Phase 1 |
| `v0.2.0-sender` | Phase 2 |
| `v0.3.0-recorded-decode` | Phase 3 |
| `v0.4.0-live-receiver` | Phase 4 |
| `v0.5.0-reliability` | Phase 5 |
| `v1.0.0-release` | Phase 6 + completion criteria |
