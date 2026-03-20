# SDK packaging (Phase 6)

## Recommended: Swift Package Manager

1. Add the **repository root** as a local or remote Swift package dependency.
2. Link **`VisualDataTransferKit`** (library product).
3. iOS apps: set **`NSCameraUsageDescription`** in `Info.plist`.

The package builds **`VDTCoreC`** (C++20 sources + `capi.h`) and links it into the Swift target automatically.

## Public API surface (Swift)

| Symbol | Role |
|--------|------|
| `VisualDataTransfer.encodeLoopCycle(message:configuration:)` | Headless encode → `VDTFramedSession` |
| `VDTTransferConfiguration` | Session id, encoding mode, payload cap, loop options |
| `SenderView` | Full sender UI (alias `SenderScreen`) |
| `ReceiverController` / `ReceiverView` | Camera + decode + assembly; share / retry |
| `ProductTransferExperience` | Send/Receive shell, onboarding, session log sheet |
| `VDTProductFlags` | UserDefaults-backed integrated UI + onboarding dismissal |
| `VDTSessionTestLog` | Append / load / export JSON field-test entries |

## XCFramework (optional, advanced)

SwiftPM does **not** emit an XCFramework for the mixed Swift + C++ target by itself. Options:

1. **Consume via SPM** (simplest for app targets).
2. **Binary target**: prebuild `libvdt_core.a` per platform, wrap in an `xcframework`, and expose only the C API from a small Swift wrapper target (you maintain the binary artifact).
3. **Xcode workspace**: add the package to an Xcode project and use **File → Packages**; archive for distribution as usual.

For a reproducible **static library** from CMake (without Swift):

```bash
cmake -S core -B build-core -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
cmake --build build-core
```

Use the resulting `libvdt_core.a` only for C/C++ clients; Swift apps should prefer SPM so `VisualDataTransferKit` and `VDTCoreC` stay in sync.

## Versioning

Tag releases when the wire format or public Swift API changes; note breaking changes in the tag message and update `docs/protocol-v1.md` if the envelope changes.
