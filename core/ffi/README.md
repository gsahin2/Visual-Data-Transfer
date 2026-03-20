# FFI headers (SwiftPM)

Swift Package Manager requires the **public C headers** for `VDTCoreC` to live inside the `core/` target directory.

`include/vdt/capi.h` is symlinked here from `core/include/vdt/capi.h`. Keep both paths identical; update the primary header under `core/include` and refresh the link if needed.

CMake builds continue to use `core/include` as the authoritative include root.
