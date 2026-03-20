import SwiftUI

/// Live transmission preview: current wire frame → parsed payload grid or descriptor state, with corner markers.
public struct SenderTransmissionView: View {
    private let spec: VDTLayoutSpec
    @ObservedObject private var player: TransferLoopPlayer

    public init(spec: VDTLayoutSpec, player: TransferLoopPlayer) {
        self.spec = spec
        self.player = player
    }

    public var body: some View {
        GeometryReader { proxy in
            let w = UInt32(max(1, Int(proxy.size.width.rounded())))
            let h = UInt32(max(1, Int(proxy.size.height.rounded())))
            let localSpec = VDTLayoutSpec(
                viewportWidth: w,
                viewportHeight: h,
                gridRows: spec.gridRows,
                gridCols: spec.gridCols,
                marginPx: spec.marginPx,
                gapPx: spec.gapPx
            )
            ZStack {
                transmissionBackground(parsed: player.parsedCurrent, spec: localSpec)
                CornerMarkersView(spec: localSpec, pulse: player.isPlaying)
                VStack {
                    Spacer()
                    statusBar(parsed: player.parsedCurrent, index: player.frameIndex, total: player.frames.count)
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func transmissionBackground(parsed: VDTWireFrame?, spec: VDTLayoutSpec) -> some View {
        if let p = parsed {
            if p.isPayload {
                SymbolGridView(message: p.payload, spec: spec)
            } else if p.isDescriptor {
                ZStack {
                    Color(red: 0.05, green: 0.12, blue: 0.08)
                    VStack(spacing: 6) {
                        Text("DESCRIPTOR")
                            .font(.caption.bold())
                            .foregroundStyle(.green.opacity(0.9))
                        Text("\(p.payload.count) B metadata")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Color.black
            }
        } else {
            Color.black
        }
    }

    private func statusBar(parsed: VDTWireFrame?, index: Int, total: Int) -> some View {
        HStack {
            Text("Frame \(index + 1)/\(max(total, 1))")
            if let p = parsed {
                Text("·")
                Text(p.isDescriptor ? "SYNC" : "DATA")
                Text("· id \(p.sessionId)")
                if p.isPayload {
                    Text("· \(p.chunkIndex)/\(p.chunkCount)")
                }
            } else {
                Text("· —")
            }
            Spacer()
        }
        .font(.caption2.monospaced())
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
