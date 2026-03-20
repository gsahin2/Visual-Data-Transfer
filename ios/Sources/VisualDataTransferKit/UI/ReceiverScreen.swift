#if os(iOS)
import AVFoundation
import SwiftUI
import UIKit

public struct ReceiverScreen: View {
    @StateObject private var model = ReceiverModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Receiver").font(.title2).bold()
            Text(model.status)
                .font(.footnote)
                .foregroundStyle(.secondary)
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

@MainActor
private final class ReceiverModel: ObservableObject, CaptureSessionControllerDelegate {
    @Published var status: String = "Camera idle"
    @Published var running: Bool = false

    let controller = CaptureSessionController()

    init() {
        controller.delegate = self
    }

    func toggle() {
        if running {
            controller.stop()
            running = false
            status = "Camera idle"
        } else {
            do {
                try controller.configureIfNeeded()
                controller.start()
                running = true
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
        Task { @MainActor in
            self.status = "Frame \(width)x\(height), \(buffer.count) bytes (vision decode hooks go here)"
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
