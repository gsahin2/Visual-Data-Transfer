import Foundation
import VDTCoreC

/// Owns native memory for one **loop cycle**: descriptor frame(s) + payload frames (`VDTEncodedSession`).
public final class VDTFramedSession {
    public struct Frame {
        public let data: Data
    }

    private var handle: UnsafeMutablePointer<VDTCoreC.VDTEncodedSession>?
    public private(set) var frames: [Frame] = []

    /// Builds a single transmit cycle via `vdt_transfer_loop_cycle` (V1 loop model).
    public init?(sessionId: UInt32, message: Data, encodingMode: VDTEncodingMode = .normal, maxPayloadBytes: UInt16 = 1024) {
        message.withUnsafeBytes { raw in
            let base = raw.bindMemory(to: UInt8.self).baseAddress
            handle = vdt_transfer_loop_cycle(sessionId, base, message.count, encodingMode.rawValue, maxPayloadBytes)
        }
        guard let handle else { return nil }
        frames = (0..<handle.pointee.frame_count).map { i in
            let len = handle.pointee.frame_sizes[i]
            let ptr = handle.pointee.frame_data[i]
            let buffer = UnsafeBufferPointer(start: ptr, count: len)
            return Frame(data: Data(buffer))
        }
    }

    deinit {
        if let handle {
            vdt_encoded_session_free(handle)
        }
    }
}
