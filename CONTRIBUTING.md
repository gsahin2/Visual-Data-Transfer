# Contributing to Visual Data Transfer

Thank you for helping improve Visual Data Transfer.

## Values

- Reliability over visual complexity.
- Deterministic behavior over implicit state.
- Clear boundaries between the C++ core and platform UI.

## Areas

- **Core (C++)** — protocol, codec, vision, tests.
- **iOS (Swift)** — SwiftUI, AVFoundation, bridging to the C API.
- **Python** — offline tools, golden vectors, benchmarks.
- **Docs** — keep `docs/` aligned with code changes.

## Local checks

### C++

```bash
cmake -S core -B build-core
cmake --build build-core -j
ctest --test-dir build-core --output-on-failure
```

### Swift

```bash
swift build
```

`Package.swift` excludes `core/build` from the `VDTCoreC` target so a local CMake build tree (e.g. Catch2 under `FetchContent`) is not picked up by SwiftPM.

`swift test` with XCTest is best run from **Xcode** (iOS Simulator destination) if you add a test target there; command-line SwiftPM may not resolve `XCTest` on all hosts.

### Python (optional)

```bash
cd python && pip install -r requirements.txt
python3 generate_test_frames.py --out-dir ../samples/generated
python3 -m unittest discover -v -p 'test_*.py'
```

Protocol / assembler smoke tests live in `python/test_vdt_protocol_v1.py` (stdlib `unittest` only; no pytest required).

## Pull requests

- Describe the problem and the approach.
- Keep changes focused; avoid unrelated refactors.
- Update documentation when behavior or wire formats change.

All project text (code, comments, docs) should be in **English**.
