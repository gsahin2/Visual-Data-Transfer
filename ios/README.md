# iOS layer

`VisualDataTransferKit` ships as a SwiftPM library product and includes:

- **C bridge** — wraps `vdt_*` functions from `VDTCoreC` (built from `core/` sources).
- **Sender** — `SenderScreen` builds a loop cycle via `VDTFramedSession`, drives **`TransferLoopPlayer`** (FPS / play/step / **completed loop count** / optional **auto-stop** after N loops; **CADisplayLink** on iOS, `Timer` on macOS for SwiftPM), and **`SenderTransmissionView`** shows each wire frame (payload grid vs descriptor panel) with **`MatrixRainGutterOverlay`** (Matrix glyphs only in gutters, decode-safe) and **corner markers** (`CornerMarkersView`).
- **Receiver** — `ReceiverScreen` + `CaptureSessionController`; throttled decode (12×20): default **`LumaGridDecoder`** with Swift margin/gap (matches sender UI), or optional **`VDTFullBleedGridSampler`** (`vdt_sample_grid_full_bleed`: C++ homography + bilinear sample); toggles for **temporal vote** (`TemporalSymbolMajority`, 3 frames) and **adaptive cell thresholds**; **`ReceiverPhase`** status line + **RX:** auxiliary (listening / ingesting / reject / complete + sticky last payload); full VT magic → **`VDTWireFrameParser`** + **`VDTSessionReassembler`** (default sender grid is **payload-only**, not whole wire per frame).

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
