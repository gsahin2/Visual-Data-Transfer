#if os(iOS)
import AVFoundation
import Foundation
import SwiftUI
import UIKit

/// High-level receiver state for product UI and programmatic control.
public enum VDTReceiverRunPhase: String, Sendable {
    case idle
    case listening
    case decodedRaw
    case wireFrame
    case assembling
    case complete
    case rejected
    case cameraError

    public var line: String {
        switch self {
        case .idle: return "Phase: idle"
        case .listening: return "Phase: listening (camera on)"
        case .decodedRaw: return "Phase: grid decoded (no VT wire yet)"
        case .wireFrame: return "Phase: VT wire recognized"
        case .assembling: return "Phase: assembling transfer"
        case .complete: return "Phase: transfer complete"
        case .rejected: return "Phase: chunk rejected (retry / align camera)"
        case .cameraError: return "Phase: camera error"
        }
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

/// Controls camera capture, grid decode, and session assembly (`VDTSessionReassembler`).
@MainActor
public final class ReceiverController: ObservableObject, CaptureSessionControllerDelegate {
    @Published public private(set) var phase: VDTReceiverRunPhase = .idle
    @Published public var phaseLabel: String = VDTReceiverRunPhase.idle.line
    @Published public var status: String = "Camera idle"
    @Published public var auxiliaryStatus: String = ""
    @Published public var running: Bool = false
    @Published public var useCoreSampler = false
    @Published public var useTemporalVote = true
    @Published public var temporalVoteDepth = 3
    @Published public var useAdaptiveCellLevels = false
    /// Last successfully merged payload after CRC32 verify (cleared when a new descriptor starts or camera stops).
    @Published public private(set) var lastCompletedPayload: Data?

    public let controller = CaptureSessionController()
    private let frameTick = FrameTickCounter()
    private let gridDecoder = LumaGridDecoder()
    private let reassembler = VDTSessionReassembler()

    public var gridRows: Int
    public var gridCols: Int
    public var decodeEveryNthFrame: Int

    private var lastDeliveredLine: String?
    private var lastMeanLuma: Float = -1
    private var symbolVoter: TemporalSymbolMajority

    public init(gridRows: Int = 12, gridCols: Int = 20, decodeEveryNthFrame: Int = 12) {
        self.gridRows = gridRows
        self.gridCols = gridCols
        self.decodeEveryNthFrame = decodeEveryNthFrame
        symbolVoter = TemporalSymbolMajority(cellCount: gridRows * gridCols, depth: 3)
        controller.delegate = self
    }

    public func toggleCamera() {
        if running {
            controller.stop()
            running = false
            reassembler.reset()
            lastDeliveredLine = nil
            lastCompletedPayload = nil
            auxiliaryStatus = ""
            symbolVoter.reset()
            lastMeanLuma = -1
            phase = .idle
            phaseLabel = phase.line
            status = "Camera idle"
        } else {
            do {
                try controller.configureIfNeeded()
                symbolVoter.reset()
                controller.start()
                running = true
                lastDeliveredLine = nil
                lastCompletedPayload = nil
                auxiliaryStatus = "RX: listening — payload grid decode; full VT wire needed for assembly"
                phase = .listening
                phaseLabel = phase.line
                status = "Streaming luma frames to delegate"
            } catch {
                phase = .cameraError
                phaseLabel = phase.line
                status = "Camera error: \(error.localizedDescription)"
            }
        }
    }

    /// Clears assembler state after a reject or to retry without stopping the camera.
    public func resetAssembly() {
        reassembler.reset()
        lastDeliveredLine = nil
        lastCompletedPayload = nil
        if running {
            phase = .listening
            phaseLabel = phase.line
            auxiliaryStatus = "RX: assembly reset — listening for descriptor / chunks"
        }
    }

    nonisolated public func captureSessionController(
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
            sceneHints.append("Brightness shifting — hold steadier.")
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

        var nextPhase: VDTReceiverRunPhase = .listening
        var stateLine = "RX: listening — awaiting decodable VT wire in grid"

        if let decoded, !decoded.isEmpty {
            nextPhase = .decodedRaw
            let hex = decoded.prefix(12).map { String(format: "%02x", $0) }.joined()
            let head = Data(decoded.prefix(40))
            let ascii = head.allSatisfy { (32...126).contains($0) || $0 == 9 || $0 == 10 || $0 == 13 }
            let preview = ascii ? " · “\(String(decoding: head, as: UTF8.self))”" : ""
            line += " · decoded \(decoded.count) B [\(hex)]\(preview)"
            if decoded.count >= 20, decoded[0] == 0x56, decoded[1] == 0x54, let w = VDTWireFrameParser.parse(decoded) {
                nextPhase = .wireFrame
                let kind = w.isDescriptor ? "DESC" : (w.isPayload ? "DATA" : "?")
                line += " · wire:\(kind) id=\(w.sessionId) \(w.chunkIndex)/\(w.chunkCount)"
                if w.isDescriptor {
                    lastDeliveredLine = nil
                    lastCompletedPayload = nil
                }
                let ar = reassembler.pushDecodedReportCompletion(w)
                if !ar.pushed {
                    nextPhase = .rejected
                    line += " · asm:reject"
                    stateLine = "RX: ingest — rejected — tap “Reset assembly” or align camera"
                } else if let merged = ar.merged {
                    nextPhase = .complete
                    lastCompletedPayload = merged
                    let text = String(decoding: merged, as: UTF8.self)
                    let safe = text.allSatisfy { $0.isASCII && !$0.unicodeScalars.contains { $0.properties.generalCategory == .control } }
                    let tail = safe ? " “\(text.prefix(80))”" : ""
                    line += " · asm:done \(merged.count) B\(tail)"
                    let summary = "RX: complete — \(merged.count) B\(tail)"
                    lastDeliveredLine = summary
                    stateLine = summary
                } else {
                    nextPhase = .assembling
                    stateLine =
                        "RX: ingesting — \(kind) chunk \(w.chunkIndex)/\(w.chunkCount) session \(w.sessionId)"
                }
            }
        } else {
            line += " · grid decode —"
        }

        phase = nextPhase
        phaseLabel = nextPhase.line
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

// MARK: - View

public struct ReceiverView: View {
    @ObservedObject public var controller: ReceiverController
    private let showAdvancedToggles: Bool

    public init(controller: ReceiverController, showAdvancedToggles: Bool = true) {
        self.controller = controller
        self.showAdvancedToggles = showAdvancedToggles
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(controller.phaseLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(controller.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !controller.auxiliaryStatus.isEmpty {
                    Text(controller.auxiliaryStatus)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if showAdvancedToggles {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("C++ full-bleed grid (homography)", isOn: $controller.useCoreSampler)
                        .font(.footnote)
                    Toggle("Temporal vote", isOn: $controller.useTemporalVote)
                        .font(.footnote)
                    if controller.useTemporalVote {
                        Stepper("Vote depth: \(controller.temporalVoteDepth)", value: $controller.temporalVoteDepth, in: 1...7)
                            .font(.footnote)
                    }
                    Toggle("Adaptive cell thresholds", isOn: $controller.useAdaptiveCellLevels)
                        .font(.footnote)
                }
                .padding(.vertical, 4)
            }
            CameraPreviewRepresentable(controller: controller.controller)
                .frame(maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 12) {
                Button(controller.running ? "Stop camera" : "Start camera") {
                    controller.toggleCamera()
                }
                .buttonStyle(.bordered)
                if controller.running {
                    Button("Reset assembly") {
                        controller.resetAssembly()
                    }
                    .buttonStyle(.bordered)
                }
            }
            if controller.phase == .rejected {
                VStack(alignment: .leading, spacing: 4) {
                    Text(VDTOnboardingCopy.retryAfterRejectTitle)
                        .font(.caption.bold())
                    Text(VDTOnboardingCopy.retryAfterRejectBody)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            if let data = controller.lastCompletedPayload, !data.isEmpty {
                shareRow(for: data)
            }
            if controller.running {
                Text(VDTOnboardingCopy.receiverGridTip)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func shareRow(for data: Data) -> some View {
        let text = String(decoding: data, as: UTF8.self)
        let safe = text.allSatisfy { $0.isASCII && !$0.unicodeScalars.contains { $0.properties.generalCategory == .control } }
        VStack(alignment: .leading, spacing: 6) {
            Text("Received payload (\(data.count) B)")
                .font(.subheadline.bold())
            if safe {
                Text(text)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                ShareLink(item: str, subject: Text("VDT payload"), message: Text("\(data.count) bytes")) {
                    Label("Share text", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
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

public enum VDTReceiverRunPhase: String, Sendable {
    case idle
    public var line: String { "Phase: idle (receiver needs iOS)" }
}

@MainActor
public final class ReceiverController: ObservableObject {
    @Published public var phase: VDTReceiverRunPhase = .idle
    @Published public var phaseLabel: String = VDTReceiverRunPhase.idle.line
    @Published public var status: String = "Receiver requires iOS"
    @Published public var auxiliaryStatus: String = ""
    @Published public var running: Bool = false
    @Published public var useCoreSampler = false
    @Published public var useTemporalVote = false
    @Published public var temporalVoteDepth = 3
    @Published public var useAdaptiveCellLevels = false
    @Published public private(set) var lastCompletedPayload: Data?
    public init(gridRows: Int = 12, gridCols: Int = 20, decodeEveryNthFrame: Int = 12) {
        _ = gridRows
        _ = gridCols
        _ = decodeEveryNthFrame
    }
    public func toggleCamera() {}
    public func resetAssembly() {}
}

public struct ReceiverView: View {
    public init(controller: ReceiverController, showAdvancedToggles: Bool = true) {
        _ = controller
        _ = showAdvancedToggles
    }
    public var body: some View {
        Text("Receiver requires iOS").padding()
    }
}
#endif
