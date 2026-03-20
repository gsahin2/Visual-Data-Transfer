import SwiftUI

public struct SenderScreen: View {
    @State private var text: String = "Hello, VDT"
    @State private var sessionId: UInt32 = 1
    @State private var encodingMode: VDTEncodingMode = .normal
    @State private var encoded: VDTFramedSession?
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
            Button("Encode loop cycle (core)") {
                let data = Data(text.utf8)
                encoded = VDTFramedSession(sessionId: sessionId, message: data, encodingMode: encodingMode)
                if let encoded {
                    loopPlayer.load(frames: encoded.frames.map(\.data))
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
            }

            GeometryReader { proxy in
                let w = UInt32(max(1, Int(proxy.size.width.rounded())))
                let h = UInt32(max(1, Int(proxy.size.height.rounded())))
                let spec = VDTLayoutSpec(
                    viewportWidth: w,
                    viewportHeight: h,
                    gridRows: grid.gridRows,
                    gridCols: grid.gridCols,
                    marginPx: grid.marginPx,
                    gapPx: grid.gapPx
                )
                if let encoded, !encoded.frames.isEmpty {
                    SenderTransmissionView(spec: spec, player: loopPlayer)
                } else {
                    SymbolGridView(message: Data(text.utf8), spec: spec)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
    }
}
