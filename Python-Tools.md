# Python Tools

Location: `python/` in the main repository.

## Setup

```bash
cd python && pip install -r requirements.txt
```

`opencv-python-headless` is listed for video/grid paths and optional quad tests.

## Tests

```bash
python3 -m unittest discover -v -p 'test_*.py'
```

- `test_vdt_protocol_v1.py` — frames, assembler, session wires.  
- `test_optical_e2e.py` — synthetic optical round-trip (PNG grid); quad case needs OpenCV.

## Notable scripts

| Script | Purpose |
|--------|---------|
| `decode_recorded_video.py` | Extract frames, sample grid (`margin` / `fullbleed` / `quad`), optional `--assemble-grid`, `--summary-json`. |
| `grid_decode_image.py` | PNG grid → bytes. |
| `generate_test_frames.py` | Synthetic sender-style frames / wire dumps. |
| `build_synthetic_optical_video.py` | Short MP4/AVI from wire grids (MJPG `.avi` fallback if MP4 writer fails). |
| `benchmark_phase0.py` | JSON timings for symbol/grid work (see `docs/performance-baseline.md`). |

## Spec mirror

`vdt_protocol_v1.py` mirrors V1 framing and `SessionAssembler` behavior for cross-checks against C++.

---

**Contributing / commands:** [CONTRIBUTING.md](https://github.com/YOUR_ORG/Visual_Data_Transfer/blob/main/CONTRIBUTING.md).
