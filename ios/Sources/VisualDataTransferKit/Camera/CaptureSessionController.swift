#if os(iOS)
import AVFoundation
import CoreVideo
import Darwin
import Foundation
import UIKit

public protocol CaptureSessionControllerDelegate: AnyObject {
    func captureSessionController(_ controller: CaptureSessionController, didOutputLuma8 buffer: Data, width: Int, height: Int)
}

/// Minimal AVFoundation pipeline: video frames converted to grayscale 8-bit for vision experiments.
public final class CaptureSessionController: NSObject {
    public weak var delegate: CaptureSessionControllerDelegate?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "vdt.capture.output")
    private let output = AVCaptureVideoDataOutput()

    public override init() {
        super.init()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
    }

    public func configureIfNeeded() throws {
        session.beginConfiguration()
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(output)
        else {
            session.commitConfiguration()
            throw NSError(domain: "VDT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Camera unavailable"])
        }
        session.addInput(input)
        session.addOutput(output)
        if let conn = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                conn.videoRotationAngle = 90
            } else {
                conn.videoOrientation = .portrait
            }
        }
        session.commitConfiguration()
    }

    public func start() {
        if !session.isRunning {
            session.startRunning()
        }
    }

    public func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    public func previewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
}

extension CaptureSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureVideoDataOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        var data = Data(count: width * height)
        data.withUnsafeMutableBytes { dst in
            guard let dptr = dst.bindMemory(to: UInt8.self).baseAddress else { return }
            for row in 0..<height {
                let srcRow = base.advanced(by: row * bytesPerRow)
                memcpy(dptr.advanced(by: row * width), srcRow, width)
            }
        }
        delegate?.captureSessionController(self, didOutputLuma8: data, width: width, height: height)
    }
}
#endif
