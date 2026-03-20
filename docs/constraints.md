# V1 Constraints & Baseline (Phase 0)

This document locks **targets** and **success criteria** for Visual Data Transfer V1. Values here are the engineering contract; `performance-baseline.md` records measured results as they are collected.

## Payload target

| Parameter | Value |
|-----------|--------|
| **Maximum transfer payload** | **20,480 bytes (20 KiB)** |
| Per-frame payload cap (wire) | 1,024 bytes (`kMaxPayloadBytesPerFrame` in core) — requires ≥ 20 data frames for a full 20 KiB transfer unless the cap is raised later |

## Time budget

| Parameter | Target |
|-----------|--------|
| **Acceptable transfer duration** | **5–20 seconds** end-to-end (user perception), for Normal mode at nominal display/camera rates |
| Sender loop rate | Tied to display refresh (typ. 60 Hz); effective throughput is `(bits per visual frame × successful decode rate) / loop length` |

## Success criteria (normal conditions)

| Criterion | Target |
|-----------|--------|
| **Success rate** | **≥ 95%** full payload recovery |
| **Working distance** | **~30–50 cm** phone-to-phone / phone-to-screen |
| **Stability** | Handheld: mild shake tolerated; decoder should exploit **loop redundancy** and temporal voting (Phase 5) |
| **Devices** | V1 completion: **≥ 2 distinct device models** validated (see roadmap) |

“Normal conditions” means indoor lighting without extreme glare, exposure not saturated, and framing that keeps the full grid visible.

## Transmission modes

| Mode | Intent | Descriptor cadence (initial policy) |
|------|--------|-------------------------------------|
| **Normal** | Balanced latency vs robustness | One descriptor at the **start of each loop cycle**, then all payload frames in order, repeat |
| **Safe** | High redundancy for difficult scenes | **Descriptor before every payload frame** (or every *k* payload frames — policy hook in `transfer_loop`) |

Encoding mode is carried in descriptor payloads (`encoding_mode` field) and should match sender UI selection.

## Grid sizes under test

| Layout | Cells | Bits @ 2 bits/cell | Notes |
|--------|-------|---------------------|--------|
| **12 × 20** | 240 | 480 bits (60 bytes) visual channel capacity per rendered frame (orthogonal to wire chunk size) |
| **16 × 24** | 384 | 768 bits (96 bytes) per rendered frame |

The **wire** still carries framed binary chunks (CRC16 per frame + session assembly). The **visual** grid is a separate channel that must stay **deterministic** and aligned with docs in `frame-layout.md`.

## Symbol set (V1)

| Setting | Choice |
|---------|--------|
| **Bits per cell** | **2** (4 discrete levels / symbols) for V1 classification simplicity |
| Robustness | Four luminance steps with guard bands; avoid near-confusable pairs (calibration in `performance-baseline.md`) |

Future symbol shapes/orientation (Phase 3+) are out of scope for the initial 2-bit luminance alphabet.

## Error categories to characterize

Document in `performance-baseline.md` as measurements land:

- Blur / defocus
- Exposure (crushed highlights / lifted blacks)
- Motion blur and rolling shutter
- Perspective error vs marker detection
- Partial occlusion

## Chosen V1 configuration (summary)

| Item | Selection |
|------|-----------|
| Max payload | 20 KiB |
| Frame wire CRC | CRC-16/CCITT-FALSE per frame |
| Full-payload integrity | **CRC-32** (IEEE/Ethernet polynomial) in **descriptor** + verify after assembly |
| Primary grids | 12×20 and 16×24 |
| Bits per symbol cell | 2 |
| Modes | Safe / Normal |
| Loop order | **Descriptor → payload frames → repeat** (see `protocol-v1.md`) |

This configuration is what the C++ reference encoder/decoder and docs are converging on for V1.
