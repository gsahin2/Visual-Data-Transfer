import SwiftUI

public struct SenderScreen: View {
    @State private var text: String = "Hello, VDT"
    @State private var sessionId: UInt32 = 1
    @State private var encodingMode: VDTEncodingMode = .normal
    @State private var repeatDescriptorEveryK: Int = 0
    @State private var trailingDescriptor: Bool = false
    @State private var encoded: VDTFramedSession?
    @State private var repeatCap: LoopRepeatCap = .untilPaused
    @StateObject private var loopPlayer = TransferLoopPlayer()

    private let grid = VDTLayoutSpec(viewportWidth: 390, viewportHeight: 844, gridRows: 12, gridCols: 20)

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sender").font(.title2).bold()
            TextField("Payload", text: $text)
                .textFieldStyle(.roundedBorder)
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
            Stepper(value: Binding(
                get: { Int(sessionId) },
                set: { sessionId = UInt32(clamping: $0) }
            ), in: 1...Int(UInt32.max)) {
                Text("Session ID: \(sessionId)")
            }
            Picker("Mode", selection: $encodingMode) {
                ForEach(VDTEncodingMode.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)
            if encodingMode == .normal {
                Stepper(value: $repeatDescriptorEveryK, in: 0...8) {
                    Text(
                        repeatDescriptorEveryK == 0
                            ? "Descriptor: once at start (Normal)"
                            : "Descriptor every \(repeatDescriptorEveryK) payload(s)"
                    )
                    .font(.footnote)
                }
            }
            Toggle("Trailing descriptor (after last payload)", isOn: $trailingDescriptor)
                .font(.footnote)
            Button("Encode loop cycle (core)") {
                let data = Data(text.utf8)
                let k = encodingMode == .normal ? repeatDescriptorEveryK : 0
                let loopOpts = VDTTransferLoopBuildOptions(
                    repeatDescriptorEveryKPayloads: UInt16(clamping: k),
                    trailingDescriptor: trailingDescriptor
                )
                encoded = VDTFramedSession(
                    sessionId: sessionId,
                    message: data,
                    encodingMode: encodingMode,
                    loopOptions: loopOpts
                )
                if let encoded {
                    loopPlayer.load(frames: encoded.frames.map(\.data))
                    applyRepeatCapPolicy(frameCount: encoded.frames.count)
                }
            }
            .buttonStyle(.borderedProminent)

            if let encoded {
                Text("Frames: \(encoded.frames.count)  CRC16: \(VDTCRC16.checksum(Data(text.utf8)))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    Toggle("Play loop", isOn: $loopPlayer.isPlaying)
                    Button("Step") { loopPlayer.stepForward() }
                    Button("Reset") { loopPlayer.reset() }
                }
                .font(.subheadline)
                HStack {
                    Text("FPS")
                    Slider(value: $loopPlayer.framesPerSecond, in: 4...24, step: 1)
                    Text("\(Int(loopPlayer.framesPerSecond))")
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text("Loops done: \(loopPlayer.completedLoopCount)")
                        .font(.footnote.monospacedDigit())
                    Spacer(minLength: 8)
                    Picker("Auto-stop", selection: $repeatCap) {
                        ForEach(LoopRepeatCap.allCases) { opt in
                            Text(opt.title).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 180, alignment: .trailing)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .onChange(of: repeatCap) { _ in
                    applyRepeatCapPolicy(frameCount: encoded.frames.count)
                }
            }

            GeometryReader { proxy in
                let strip: CGFloat = 20
                let innerW = max(32, proxy.size.width - 2 * strip)
                let innerH = proxy.size.height
                let spec = VDTLayoutSpec(
                    viewportWidth: UInt32(max(1, Int(innerW.rounded()))),
                    viewportHeight: UInt32(max(1, Int(innerH.rounded()))),
                    gridRows: grid.gridRows,
                    gridCols: grid.gridCols,
                    marginPx: grid.marginPx,
                    gapPx: grid.gapPx
                )
                if let encoded, !encoded.frames.isEmpty {
                    SenderTransmissionView(spec: spec, player: loopPlayer)
                } else {
                    HStack(spacing: 0) {
                        MatrixRainStrip()
                            .frame(width: strip, height: innerH)
                        SymbolGridView(message: Data(text.utf8), spec: spec)
                            .frame(width: innerW, height: innerH)
                        MatrixRainStrip()
                            .frame(width: strip, height: innerH)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
    }

    private func applyRepeatCapPolicy(frameCount: Int) {
        switch repeatCap {
        case .adaptive:
            let n = max(2, min(30, frameCount / 2))
            loopPlayer.maxCompletedLoops = n
        default:
            loopPlayer.maxCompletedLoops = repeatCap.maxLoops
        }
    }
}

private enum LoopRepeatCap: String, CaseIterable, Identifiable {
    case untilPaused
    case adaptive
    case one
    case three
    case ten

    var id: String { rawValue }

    var title: String {
        switch self {
        case .untilPaused: return "Until paused"
        case .adaptive: return "Auto-stop (by frame count)"
        case .one: return "After 1 loop"
        case .three: return "After 3 loops"
        case .ten: return "After 10 loops"
        }
    }

    var maxLoops: Int? {
        switch self {
        case .untilPaused: return nil
        case .adaptive: return nil
        case .one: return 1
        case .three: return 3
        case .ten: return 10
        }
    }
}
