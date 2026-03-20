# Getting Started

## Prerequisites

- **C++:** CMake, a C++17 toolchain  
- **Swift (Apple):** Xcode or Swift toolchain + SwiftPM  
- **Python 3:** `pip` (see `python/requirements.txt`)

## Clone

```bash
git clone https://github.com/YOUR_ORG/Visual_Data_Transfer.git
cd Visual_Data_Transfer
```

Replace `YOUR_ORG` with your GitHub user or organization.

## C++ core

```bash
cmake -S core -B build-core
cmake --build build-core -j
ctest --test-dir build-core --output-on-failure
```

## Swift package

From the repository root:

```bash
swift build
```

SwiftPM uses `Package.swift`; the C++ core is exposed via `VDTCoreC`. See [`ios/README.md`](https://github.com/YOUR_ORG/Visual_Data_Transfer/blob/main/ios/README.md) in the repo for the app layout.

## Python tools

```bash
cd python
pip install -r requirements.txt
python3 -m unittest discover -v -p 'test_*.py'
```

Optional: generate sample frames (paths may vary):

```bash
python3 generate_test_frames.py --out-dir ../samples/generated
```

More detail: [Python Tools](Python-Tools).

## Where to read next

- [Architecture](Architecture) — layers and data flow  
- [Development](Development) — full check list and PR expectations  
- Main [README](https://github.com/YOUR_ORG/Visual_Data_Transfer/blob/main/README.md) — feature summary and repo layout  
