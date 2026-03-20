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

### 3. Python Tools
- Offline video decoding
- Test data generation
- Benchmarking
- Prototyping experiments

---

## Features (V1)

- Symbol-grid based transmission
- Frame-based protocol (chunked payload)
- CRC16 integrity validation
- Session-based reconstruction
- Deterministic rendering layout
- Recorded-video decoding (first target)

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