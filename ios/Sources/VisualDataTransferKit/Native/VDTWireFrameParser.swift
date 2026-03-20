import Foundation
import VDTCoreC

/// Parsed wire frame from the C core (`vdt_frame_parse`).
public struct VDTWireFrame: Sendable {
    public var version: UInt8
    public var frameType: UInt8
    public var flags: UInt8
    public var sessionId: UInt32
    public var chunkIndex: UInt16
    public var chunkCount: UInt16
    public var payloadLength: UInt16
    public var payload: Data

    public var isDescriptor: Bool { frameType == 1 }
    public var isPayload: Bool { frameType == 0 }
}

public enum VDTWireFrameParser {
    private static let maxPayload = 1024

    public static func parse(_ wire: Data) -> VDTWireFrame? {
        var hdr = VDTFrameHeaderC()
        var buf = [UInt8](repeating: 0, count: maxPayload)
        var written: size_t = 0
        let ok = wire.withUnsafeBytes { raw -> Int32 in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return vdt_frame_parse(base, wire.count, &hdr, &buf, maxPayload, &written)
        }
        guard ok != 0 else { return nil }
        return VDTWireFrame(
            version: hdr.version,
            frameType: hdr.frame_type,
            flags: hdr.flags,
            sessionId: hdr.session_id,
            chunkIndex: hdr.chunk_index,
            chunkCount: hdr.chunk_count,
            payloadLength: hdr.payload_length,
            payload: Data(buf.prefix(Int(written)))
        )
    }
}
