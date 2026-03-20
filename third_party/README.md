# Third-party dependencies

This directory is reserved for vendored or git-submoduled libraries.

- **C++ tests** fetch [Catch2](https://github.com/catchorg/Catch2) via CMake `FetchContent` into the build tree (not stored here).
- **SwiftPM** builds the C++ core from source; no prebuilt binaries are required for local development.

Add new third-party code only when it carries a clear license file and is referenced from the top-level `README.md`.
