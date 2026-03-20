#if os(iOS)
import AVFoundation
import Foundation
import SwiftUI
import UIKit

public struct ReceiverScreen: View {
    @StateObject private var model = ReceiverModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Receiver").font(.title2).bold()
            VStack(alignment: .leading, spacing: 4) {
                Text(model.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !model.auxiliaryStatus.isEmpty {
                    Text(model.auxiliaryStatus)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            CameraPreviewRepresentable(controller: model.controller)
                .frame(maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Button(model.running ? "Stop camera" : "Start camera") {
                model.toggle()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

/// Thread-safe frame counter for throttling decode work off the capture queue.
private final class FrameTickCounter: @unchecked Sendable {
    private var value = 0
    private let lock = NSLock()
    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

@MainActor
private final class ReceiverModel: ObservableObject, CaptureSessionControllerDelegate {
    @Published var status: String = "Camera idle"
    /// Second-row hints: assembly state machine + last successful payload (when any).
    @Published var auxiliaryStatus: String = ""
    @Published var running: Bool = false

    let controller = CaptureSessionController()
    private let frameTick = FrameTickCounter()
    private let gridDecoder = LumaGridDecoder()
    private let reassembler = VDTSessionReassembler()

    /// Matches sender default visual grid (`SenderScreen`).
    private let gridRows = 12
    private let gridCols = 20
    private let decodeEveryNthFrame = 12
    private var lastDeliveredLine: String?

    init() {
        controller.delegate = self
    }

    func toggle() {
        if running {
            controller.stop()
            running = false
            reassembler.reset()
            lastDeliveredLine = nil
            auxiliaryStatus = ""
            status = "Camera idle"
        } else {
            do {
                try controller.configureIfNeeded()
                controller.start()
                running = true
                lastDeliveredLine = nil
                auxiliaryStatus = "RX: listening — payload grid decode; full VT wire needed for assembly"
                status = "Streaming luma frames to delegate"
            } catch {
                status = "Camera error: \(error.localizedDescription)"
            }
        }
    }

    nonisolated func captureSessionController(
        _ controller: CaptureSessionController,
        didOutputLuma8 buffer: Data,
        width: Int,
        height: Int
    ) {
        let tick = frameTick.next()
        guard tick % decodeEveryNthFrame == 0 else { return }
        let decoded = gridDecoder.decode(
            luma: buffer,
            width: width,
            height: height,
            gridRows: gridRows,
            gridCols: gridCols,
            marginPx: 8,
            gapPx: 2,
            maxOutputBytes: 64
        )
        Task { @MainActor in
            guard self.running else { return }
            var line = "Luma \(width)×\(height) · full-bleed grid \(self.gridRows)×\(self.gridCols)"
            var stateLine = "RX: listening — awaiting decodable VT wire in grid"
            if let decoded, !decoded.isEmpty {
                let hex = decoded.prefix(12).map { String(format: "%02x", $0) }.joined()
                let head = Data(decoded.prefix(40))
                let ascii = head.allSatisfy { (32...126).contains($0) || $0 == 9 || $0 == 10 || $0 == 13 }
                let preview = ascii ? " · “\(String(decoding: head, as: UTF8.self))”" : ""
                line += " · decoded \(decoded.count) B [\(hex)]\(preview)"
                if decoded.count >= 20, decoded[0] == 0x56, decoded[1] == 0x54, let w = VDTWireFrameParser.parse(decoded) {
                    let kind = w.isDescriptor ? "DESC" : (w.isPayload ? "DATA" : "?")
                    line += " · wire:\(kind) id=\(w.sessionId) \(w.chunkIndex)/\(w.chunkCount)"
                    if w.isDescriptor {
                        self.lastDeliveredLine = nil
                    }
                    let ar = self.reassembler.pushDecodedReportCompletion(w)
                    if !ar.pushed {
                        line += " · asm:reject"
                        stateLine = "RX: ingest — rejected (session/chunk mismatch?)"
                    } else if let merged = ar.merged {
                        let text = String(decoding: merged, as: UTF8.self)
                        let safe = text.allSatisfy { $0.isASCII && !$0.unicodeScalars.contains { $0.properties.generalCategory == .control } }
                        let tail = safe ? " “\(text.prefix(80))”" : ""
                        line += " · asm:done \(merged.count) B\(tail)"
                        let summary = "RX: complete — \(merged.count) B\(tail)"
                        self.lastDeliveredLine = summary
                        stateLine = summary
                    } else {
                        stateLine =
                            "RX: ingesting — \(kind) chunk \(w.chunkIndex)/\(w.chunkCount) session \(w.sessionId)"
                    }
                }
            } else {
                line += " · grid decode —"
            }
            var auxParts: [String] = []
            if let d = self.lastDeliveredLine, stateLine != d {
                auxParts.append(d)
            }
            if !stateLine.isEmpty {
                auxParts.append(stateLine)
            }
            self.auxiliaryStatus = auxParts.joined(separator: "\n")
            self.status = line
        }
    }
}

private struct CameraPreviewRepresentable: UIViewRepresentable {
    let controller: CaptureSessionController

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let layer = controller.previewLayer()
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        context.coordinator.previewLayer = layer
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var view: UIView?
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
#else
import SwiftUI

public struct ReceiverScreen: View {
    public init() {}
    public var body: some View {
        Text("Receiver requires iOS")
            .padding()
    }
}
#endif
