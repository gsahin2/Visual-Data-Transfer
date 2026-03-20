# Architecture

VDT separates **protocol and vision math** from **platform UI and capture**: one testable **C++ core**, with **Swift** for on-device UI/camera and **Python** for offline tools and golden checks.

## Layers

| Layer | Role |
|--------|------|
| **C++ core** | Framing, CRC, session assembly, layout, vision primitives (markers, homography, grid sampling). |
| **Swift (iOS)** | SwiftUI, AVFoundation, grid rendering, bridge to the C API. |
| **Python** | Wire/session mirrors, PNG/video decode experiments, benchmarks. |

## Sender flow (conceptual)

1. Payload is chunked and wrapped in a **loop cycle** (descriptor + payload frames, Safe / Normal policies).  
2. Each logical chunk becomes a **wire frame** (header + payload + CRC-16).  
3. The **visual** channel encodes bits as a **2-bit/cell** symbol grid (V1), independent of wire chunk size details; layout is deterministic.

## Receiver flow (conceptual)

1. **Camera** → luma (or video file in Python tools).  
2. **Geometry** → markers / homography / full-bleed sampling (platform-dependent).  
3. **Parse** wire frames → **SessionAssembler** → merged payload + **CRC-32** check against descriptor.

## Stable API surface

The C API in `core/include/vdt/capi.h` (also exposed for SwiftPM) is what Swift should call for protocol rules and session assembly — avoid duplicating framing logic in UI code.

---

**Full detail:** [docs/architecture.md](https://github.com/YOUR_ORG/Visual_Data_Transfer/blob/main/docs/architecture.md) in the main repository.
