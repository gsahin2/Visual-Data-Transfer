# Visual Data Transfer

Visual Data Transfer is an open-source system for reliable screen-to-camera data transmission.

It renders structured, machine-readable visual frames on a display and allows another device camera to decode them into digital data.

The project combines deterministic encoding with visually rich presentation (e.g., Matrix-style animation), while maintaining decoding reliability.

---

## Why Visual Data Transfer?

Traditional methods like QR codes are robust but visually static.

Visual Data Transfer explores a new approach:

- Animated visual transmission
- Symbol-grid based encoding
- Frame-by-frame data streaming
- Camera-readable structured layouts
- Offline / air-gapped communication

---

## Core Idea

Separate **appearance** from **data**:

- What the user sees → animated visual layer
- What the system reads → structured symbol grid

---

## Architecture Overview

The project is divided into three main layers:

### 1. Core (C++)
- Protocol definition
- Frame encoding / decoding
- CRC and integrity checks
- Session assembly
- Symbol mapping
- Vision primitives (marker detection, grid sampling, normalization)

### 2. iOS Demo / SDK (Swift)
- Matrix-style rendering
- AVFoundation camera capture
- SwiftUI demo interface
- C++ bridge layer
- Public API (`VisualDataTransfer.encodeLoopCycle`, `ReceiverController`, `ProductTransferExperience`); see [`docs/sdk-packaging.md`](docs/sdk-packaging.md) and [`ios/README.md`](ios/README.md)

### 3. Python Tools
- Offline video decoding
- Test data generation
- Benchmarking
- Prototyping experiments

---

## Features (V1)

- **20 KiB** max assembled payload (`kMaxTransferPayloadBytes`)
- Loop-friendly framing: **descriptor** + **payload** frames (`build_transfer_loop_cycle`, Safe / Normal, optional `vdt_transfer_loop_cycle_ex` cadence / trailing descriptor)
- **CRC-16** per wire frame; **CRC-32 (IEEE)** over full payload (descriptor + verify on assemble)
- Symbol grid: **2 bits/cell** (4 levels) for the visual channel
- Session assembly with **duplicate chunk** tolerance (loop redundancy)
- Deterministic layout; recorded-video decode path (tools)

---

## Non-Goals (V1)

- Maximum throughput optimization
- Arbitrary artistic symbol sets
- Full cross-platform SDK parity
- Production-grade transport encryption

---

## Repository Structure

```text
core/        → C++ engine
ios/         → Swift demo + SDK
python/      → tools & experiments
docs/        → specifications
samples/     → test assets
```

---

## Build & documentation

- **C++:** `cmake -S core -B build-core && cmake --build build-core && ctest --test-dir build-core`
- **Swift:** `swift build` (root `Package.swift`)
- **Python (examples):** `pip install -r python/requirements.txt` then `python3 python/generate_test_frames.py --out-dir samples/generated` and `python3 python/grid_decode_image.py samples/generated/grid_preview.png --compare "VDT test"` (lossless round-trip on synthetic PNGs). `python3 python/decode_recorded_video.py --wire-dir samples/generated` reassembles raw `.bin` wire files. Screen recordings: `python3 python/decode_recorded_video.py --decode-grid --resize 640x480 path/to.mp4` (optional `--byte-length`, `--frame-stride`, `--write-decoded DIR`, `--try-parse-wire`, `--assemble-grid` + `--write-assembled DIR` for merged payloads, `--quiet` for summary-only; summary includes read/decode/stride counts and parse/assembly counters).
- **Docs:** [Architecture](docs/architecture.md) · [Protocol V1](docs/protocol-v1.md) · [Frame layout](docs/frame-layout.md) · [Constraints](docs/constraints.md) · [Performance baseline](docs/performance-baseline.md) · [Roadmap](docs/roadmap.md) · [**Phases & tasks (status)**](docs/phases-and-tasks.md) · [Contributing](CONTRIBUTING.md)

**License:** [LICENSE](LICENSE) (Apache-2.0)