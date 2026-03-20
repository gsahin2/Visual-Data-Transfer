# iOS layer

`VisualDataTransferKit` ships as a SwiftPM library product and includes:

- **C bridge** — wraps `vdt_*` functions from `VDTCoreC` (built from `core/` sources).
- **Sender** — **`SenderView`** (`SenderScreen` alias) builds a loop cycle via `VDTFramedSession` + **`VDTTransferLoopBuildOptions`** (Phase 5: **descriptor every K payloads** in Normal, **trailing descriptor**); drives **`TransferLoopPlayer`** (FPS / play/step / **completed loop count** / auto-stop presets including **Auto-stop by frame count**); **`SenderTransmissionView`** shows each wire frame with **`MatrixRainGutterOverlay`** and **`CornerMarkersView`**.
- **Receiver** — **`ReceiverController`** + **`ReceiverView`** (or **`ReceiverScreen`** with a default controller); same decode path as above; **`lastCompletedPayload`** + **`ShareLink`** for text export; **Reset assembly** retry; reject-state copy from **`VDTOnboardingCopy`**.
- **Phase 6 product API** — **`VisualDataTransfer.encodeLoopCycle(message:configuration:)`**, **`VDTTransferConfiguration`**, **`ProductTransferExperience`** (Send/Receive shell, onboarding, field-test log + JSON export), **`VDTProductFlags`**, **`VDTSessionTestLog`**. Packaging notes: **[`docs/sdk-packaging.md`](../docs/sdk-packaging.md)**.

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
