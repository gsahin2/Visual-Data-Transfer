# Performance Baseline (Phase 0)

Use this file to record **measured** numbers. Targets live in `constraints.md`.

## How to benchmark

1. **Wire channel (C++)**  
   - Build: `cmake -S core -B build-core && cmake --build build-core`  
   - Use `python/benchmark_symbols.py` for Python-side bit expansion sanity checks.  
   - Optional: add a small `vdt_benchmark` target later for `FrameEncoder` throughput.

2. **Visual channel**  
   - For each grid (12×20, 16×24) and 2 bits/cell:  
     `raw_visual_bits_per_frame = rows × cols × 2`  
   - **Effective bytes/frame (visual)** = `raw_visual_bits_per_frame / 8`.

3. **End-to-end**  
   - Record: distance, lighting (lux estimate or label), device models, mode (Safe/Normal), time-to-100%-payload, and whether CRC32 matched.

## Theoretical capacity (reference)

| Grid | Cells | 2 bits/cell | Bytes/frame (visual layer) |
|------|-------|-------------|-----------------------------|
| 12×20 | 240 | 480 bits | 60 |
| 16×24 | 384 | 768 bits | 96 |

Wire chunks are independent (see `kMaxPayloadBytesPerFrame`). Loop length in **frames** depends on chunk count + descriptor policy.

## Throughput worksheet

Fill after measurements:

| Mode | Display Hz | Avg decoded frames/s | Visual bytes/s (est.) | Notes |
|------|------------|----------------------|------------------------|-------|
| Normal | | | | |
| Safe | | | | |

## Decoding error patterns

| Pattern | Symptoms | Mitigation (V1 → V5) |
|---------|----------|---------------------|
| Blur | Soft edges, wrong symbol | More loop repeats; temporal vote |
| Exposure | Clipping / low contrast | Adaptive thresholding; user hint |
| Motion | Streaks, inter-frame disagreement | Faster exposure; majority vote |
| Geometry | Warped grid | Homography + margin tuning |

## Revision log

| Date | Author | Change |
|------|--------|--------|
| — | — | Template created |
