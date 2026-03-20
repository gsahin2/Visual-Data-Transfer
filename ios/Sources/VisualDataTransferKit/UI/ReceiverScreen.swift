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
                Text(model.phaseLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(model.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !model.auxiliaryStatus.isEmpty {
                    Text(model.auxiliaryStatus)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Toggle("C++ full-bleed grid (homography)", isOn: $model.useCoreSampler)
                    .font(.footnote)
                Toggle("Temporal vote", isOn: $model.useTemporalVote)
                    .font(.footnote)
                if model.useTemporalVote {
                    Stepper("Vote depth: \(model.temporalVoteDepth)", value: $model.temporalVoteDepth, in: 1...7)
                        .font(.footnote)
                }
                Toggle("Adaptive cell thresholds", isOn: $model.useAdaptiveCellLevels)
                    .font(.footnote)
            }
            .padding(.vertical, 4)
            CameraPreviewRepresentable(controller: model.controller)
                .frame(maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Button(model.running ? "Stop camera" : "Start camera") {
                model.toggle()
            }
            .buttonStyle(.bordered)
            if model.running {
                Text("Tip: margin/gap Swift path matches the sender UI; C++ path is uniform full-frame sampling (good for homography tests).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
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

private enum ReceiverPhase: String {
    case idle = "Phase: idle"
    case listening = "Phase: listening (camera on)"
    case decodedRaw = "Phase: grid decoded (no VT wire yet)"
    case wireFrame = "Phase: VT wire recognized"
    case assembling = "Phase: assembling transfer"
    case complete = "Phase: transfer complete"
    case rejected = "Phase: chunk rejected (retry / align camera)"
    case cameraError = "Phase: camera error"
}

@MainActor
private final class ReceiverModel: ObservableObject, CaptureSessionControllerDelegate {
    @Published var phaseLabel: String = ReceiverPhase.idle.rawValue
    @Published var status: String = "Camera idle"
    /// Second-row hints: assembly state machine + last successful payload (when any).
    @Published var auxiliaryStatus: String = ""
    @Published var running: Bool = false
    @Published var useCoreSampler = false
    @Published var useTemporalVote = true
    @Published var temporalVoteDepth = 3
    @Published var useAdaptiveCellLevels = false

    let controller = CaptureSessionController()
    private let frameTick = FrameTickCounter()
    private let gridDecoder = LumaGridDecoder()
    private let reassembler = VDTSessionReassembler()

    /// Matches sender default visual grid (`SenderScreen`).
    private let gridRows = 12
    private let gridCols = 20
    private let decodeEveryNthFrame = 12
    private var lastDeliveredLine: String?
    private var lastMeanLuma: Float = -1
    private var symbolVoter = TemporalSymbolMajority(cellCount: 12 * 20, depth: 3)

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
            symbolVoter.reset()
            lastMeanLuma = -1
            phaseLabel = ReceiverPhase.idle.rawValue
            status = "Camera idle"
        } else {
            do {
                try controller.configureIfNeeded()
                symbolVoter.reset()
                controller.start()
                running = true
                lastDeliveredLine = nil
                auxiliaryStatus = "RX: listening — payload grid decode; full VT wire needed for assembly"
                phaseLabel = ReceiverPhase.listening.rawValue
                status = "Streaming luma frames to delegate"
            } catch {
                phaseLabel = ReceiverPhase.cameraError.rawValue
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
        let buf = buffer
        let w = width
        let h = height
        Task { @MainActor in
            self.handleLumaFrame(buffer: buf, width: w, height: h)
        }
    }

    private func ensureSymbolVoter() {
        let n = gridRows * gridCols
        let d = useTemporalVote ? max(1, min(7, temporalVoteDepth)) : 1
        if symbolVoter.cellCount != n || symbolVoter.depth != d {
            symbolVoter = TemporalSymbolMajority(cellCount: n, depth: d)
        }
    }

    private static func meanLuma(buffer: Data, width: Int, height: Int) -> Float {
        let n = width * height
        guard buffer.count >= n, n > 0 else { return 128 }
        var s = 0
        buffer.withUnsafeBytes { raw in
            let p = raw.bindMemory(to: UInt8.self)
            for i in 0..<n { s += Int(p[i]) }
        }
        return Float(s) / Float(n)
    }

    private func handleLumaFrame(buffer: Data, width: Int, height: Int) {
        guard running else { return }

        ensureSymbolVoter()
        let mean = Self.meanLuma(buffer: buffer, width: width, height: height)
        let motion = lastMeanLuma >= 0 ? abs(mean - lastMeanLuma) : 0
        lastMeanLuma = mean
        var sceneHints: [String] = []
        if mean < 52 {
            sceneHints.append("Scene dark — add light or enable adaptive + longer vote.")
        }
        if motion > 14 {
            sceneHints.append("Brightness shifting — hold steadier (motion tolerance).")
        }

        let symbols: [UInt8]? = {
            if useCoreSampler {
                guard let cells = VDTFullBleedGridSampler.sampleCells(
                    luma: buffer,
                    width: width,
                    height: height,
                    rows: gridRows,
                    cols: gridCols
                ) else { return nil }
                return LumaGridDecoder.symbolsFromCellLuma(
                    cells,
                    gridRows: gridRows,
                    gridCols: gridCols,
                    adaptiveLevels: useAdaptiveCellLevels
                )
            }
            return gridDecoder.cellSymbolsFromViewport(
                luma: buffer,
                width: width,
                height: height,
                gridRows: gridRows,
                gridCols: gridCols,
                marginPx: 8,
                gapPx: 2,
                adaptiveLevels: useAdaptiveCellLevels
            )
        }()

        let votedSymbols: [UInt8]? = {
            guard let symbols else { return nil }
            if useTemporalVote {
                return symbolVoter.push(symbols)
            }
            return symbols
        }()

        let decoded: Data? = {
            guard let votedSymbols else { return nil }
            return LumaGridDecoder.bytes(fromSymbols: votedSymbols, maxOutputBytes: 64)
        }()

        var line = "Luma \(width)×\(height) · grid \(gridRows)×\(gridCols)"
        line += useCoreSampler ? " · C++ sample" : " · Swift margin/gap"
        if useTemporalVote {
            line += " · vote×\(symbolVoter.depth)"
        }
        line += useAdaptiveCellLevels ? " · adaptive" : ""
        line += String(format: " · meanY=%.0f", mean)

        var phase: ReceiverPhase = .listening
        var stateLine = "RX: listening — awaiting decodable VT wire in grid"

        if let decoded, !decoded.isEmpty {
            phase = .decodedRaw
            let hex = decoded.prefix(12).map { String(format: "%02x", $0) }.joined()
            let head = Data(decoded.prefix(40))
            let ascii = head.allSatisfy { (32...126).contains($0) || $0 == 9 || $0 == 10 || $0 == 13 }
            let preview = ascii ? " · “\(String(decoding: head, as: UTF8.self))”" : ""
            line += " · decoded \(decoded.count) B [\(hex)]\(preview)"
            if decoded.count >= 20, decoded[0] == 0x56, decoded[1] == 0x54, let w = VDTWireFrameParser.parse(decoded) {
                phase = .wireFrame
                let kind = w.isDescriptor ? "DESC" : (w.isPayload ? "DATA" : "?")
                line += " · wire:\(kind) id=\(w.sessionId) \(w.chunkIndex)/\(w.chunkCount)"
                if w.isDescriptor {
                    lastDeliveredLine = nil
                }
                let ar = reassembler.pushDecodedReportCompletion(w)
                if !ar.pushed {
                    phase = .rejected
                    line += " · asm:reject"
                    stateLine = "RX: ingest — rejected (session/chunk mismatch?) — retry or wait for descriptor"
                } else if let merged = ar.merged {
                    phase = .complete
                    let text = String(decoding: merged, as: UTF8.self)
                    let safe = text.allSatisfy { $0.isASCII && !$0.unicodeScalars.contains { $0.properties.generalCategory == .control } }
                    let tail = safe ? " “\(text.prefix(80))”" : ""
                    line += " · asm:done \(merged.count) B\(tail)"
                    let summary = "RX: complete — \(merged.count) B\(tail)"
                    lastDeliveredLine = summary
                    stateLine = summary
                } else {
                    phase = .assembling
                    stateLine =
                        "RX: ingesting — \(kind) chunk \(w.chunkIndex)/\(w.chunkCount) session \(w.sessionId)"
                }
            }
        } else {
            line += " · grid decode —"
        }

        phaseLabel = phase.rawValue
        var auxParts: [String] = []
        if !sceneHints.isEmpty {
            auxParts.append(sceneHints.joined(separator: " "))
        }
        if let d = lastDeliveredLine, stateLine != d {
            auxParts.append(d)
        }
        if !stateLine.isEmpty {
            auxParts.append(stateLine)
        }
        auxiliaryStatus = auxParts.joined(separator: "\n")
        status = line
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
