# Architecture

Visual Data Transfer separates **protocol and vision mathematics** from **platform UI and capture**. The goal is a single, testable core that every platform can bind to, while rendering and camera code stay native.

## Layers

| Layer | Role |
|-------|------|
| **C++ core** | Framing, CRC, session assembly, layout math, vision primitives (homography, sampling, marker hooks). |
| **Swift (iOS)** | SwiftUI surfaces, AVFoundation capture, deterministic drawing of the symbol grid. |
| **Python** | Offline generators, benchmarks, and experiments that mirror the wire format for cross-checks. |

## C++ modules

- **common** — CRC-16 (CCITT-FALSE), bit packing utilities, shared types.
- **protocol** — Constants, frame header, packet views, session reassembly buffer.
- **encode** — Session chunking, frame encoder, symbol index helpers.
- **decode** — Frame parsing (CRC + layout), session assembler for ordered chunks.
- **render** — Viewport → cell rectangles and normalized sample coordinates.
- **vision** — Interfaces plus reference implementations: full-bleed marker corners, DLT homography, bilinear grid sampling.

## Data flow (sender)

1. Application payload (bytes) enters the **encoder**, which chunks according to `kMaxPayloadBytesPerFrame` (1024 B) until the full message (≤ **20 KiB**, `kMaxTransferPayloadBytes`) is covered. A **loop cycle** prepends descriptor frame(s) per `EncodingMode` (`build_transfer_loop_cycle`).
2. Each chunk becomes a **wire frame**: fixed header + payload + CRC16 over header+payload.
3. Swift **renders** the *visual* channel (grid of symbols, **2 bits/cell** in V1) deterministically from the same payload bytes (orthogonal to wire chunking; see `docs/constraints.md`).

## Data flow (receiver)

1. **Camera** delivers luma frames via AVFoundation (Swift).
2. **Vision** (C++) estimates geometry (markers → homography) and samples the normalized grid.
3. **Decoder** validates frames and **assembles** the session; upper layers interpret the payload.

## Bridging

The stable C API in `core/include/vdt/capi.h` is mirrored under `core/ffi/include` for Swift Package Manager. Swift code should call these entry points instead of reimplementing protocol rules.

## Build surfaces

- **CMake** (`core/`) — static library + Catch2 tests.
- **SwiftPM** (repository root `Package.swift`) — `VDTCoreC` + `VisualDataTransferKit` for Apple platforms.
