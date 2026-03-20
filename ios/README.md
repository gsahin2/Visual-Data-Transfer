# iOS layer

`VisualDataTransferKit` ships as a SwiftPM library product and includes:

- **C bridge** — wraps `vdt_*` functions from `VDTCoreC` (built from `core/` sources).
- **Sender** — `SenderScreen` builds a loop cycle via `VDTFramedSession`, drives **`TransferLoopPlayer`** (FPS / play/step; **CADisplayLink** on iOS, `Timer` on macOS for SwiftPM), and **`SenderTransmissionView`** shows each wire frame (payload grid vs descriptor panel) with **corner markers** (`CornerMarkersView`).
- **Receiver** — `ReceiverScreen` + `CaptureSessionController`; throttled **`LumaGridDecoder`** (12×20, same thresholds as `python/grid_codec.py`) updates status with hex / ASCII preview; if bytes start with VT magic, **`VDTWireFrameParser`** adds a short wire line (full-bleed, no homography yet).

## Integrating into an Xcode app

1. Add the repository root as a **local Swift package** dependency.
2. Link against `VisualDataTransferKit`.
3. Add `NSCameraUsageDescription` to your target `Info.plist`.

## FFI note

SwiftPM requires public C headers inside the `core` target; see `core/ffi/README.md` for the `capi.h` symlink layout.

## Running the bundled demo target

From the repository root:

```bash
swift build --product VisualDataTransferDemo
```

For device camera capture, create an iOS application target in Xcode and embed the package (command-line SwiftPM executables are macOS-oriented unless configured for iOS).
