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

3. **Synthetic Phase 0 timings (Python, developer machine)**  
   Run from `python/`: `python3 benchmark_phase0.py` (prints JSON). Example capture (re-run on your hardware):

   ```json
   {
     "tool": "benchmark_phase0.py",
     "symbol_expand_iters": 200,
     "symbol_expand_total_s": 0.02027,
     "symbol_expand_per_iter_us": 101.35,
     "grid_decode_png_iters": 200,
     "grid_decode_total_s": 0.163105,
     "grid_decode_per_iter_us": 815.53,
     "note": "Synthetic CPU timings on developer machine; re-run for your hardware."
   }
   ```

   This is **not** optical throughput; it sanity-checks symbol expansion + PNG grid decode cost offline.

4. **End-to-end (field / camera)**  
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

## Phase 5 — reliability levers (reference, not lab-measured here)

Use these when filling the throughput worksheet above; numbers are **design intent** until you replace them with device trials.

| Lever | Location | Expected effect |
|-------|----------|-----------------|
| Descriptor every *K* payloads (Normal) | `build_transfer_loop_cycle` + `vdt_transfer_loop_cycle_ex` | Late joiners / mid-loop resync without Safe’s per-frame descriptor cost |
| Trailing descriptor | same | Easier wrap boundary for optical receivers |
| Duplicate-compatible descriptor | `SessionAssembler` (C++ / Python) | Safe + periodic Normal cycles no longer wipe partial assembly |
| Temporal vote depth 1…7 | `ReceiverScreen`, `TemporalSymbolMajority` | Fewer single-frame symbol errors; more latency |
| Adaptive cell thresholds | `LumaGridDecoder`, Python `grid_codec.lumas_to_symbols` | Low-contrast frames when min–max span is usable |
| `--vote-frames` / `--adaptive-cells` | `decode_recorded_video.py` | Offline video grid path aligned with live receiver options |
| Auto-stop loops (sender) | `SenderScreen` “Auto-stop (by frame count)” | `max(2, min(30, frameCount/2))` loop cap heuristic for longer cycles |

**Success-rate target** remains in `constraints.md` (e.g. ≥95% at nominal distance); record **before/after** in the throughput table once you have two comparable runs.

## Revision log

| Date | Author | Change |
|------|--------|--------|
| — | — | Template created |
| 2025-03-20 | — | Phase 5 reference table + measurement reminder |
| 2026-03-20 | — | Synthetic `benchmark_phase0.py` sample JSON in “How to benchmark” |
