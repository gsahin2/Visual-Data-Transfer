import Foundation
import VDTCoreC

/// Thread-safe wrapper around the core **SessionAssembler** (descriptor + payload chunks → merged bytes + CRC32).
public final class VDTSessionReassembler: @unchecked Sendable {
    private var handle: OpaquePointer?
    private let lock = NSLock()

    public init() {
        handle = vdt_session_assembler_create()
    }

    deinit {
        if let handle {
            vdt_session_assembler_destroy(handle)
        }
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        if let handle {
            vdt_session_assembler_reset(handle)
        }
    }

    /// Push a full VT wire frame (magic, header, payload, CRC16).
    @discardableResult
    public func pushWire(_ data: Data) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let handle else { return false }
        return data.withUnsafeBytes { raw -> Bool in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return false }
            return vdt_session_assembler_push_wire(handle, base, data.count) != 0
        }
    }

    /// Push a logically decoded frame (same fields as `VDTWireFrameParser`).
    @discardableResult
    public func pushDecoded(_ frame: VDTWireFrame) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pushDecodedLocked(frame)
    }

    public var isComplete: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let handle else { return false }
        return vdt_session_assembler_is_complete(handle) != 0
    }

    /// When the buffer is complete and CRC32 matches the descriptor, returns merged payload and clears state.
    public func takeMergedPayloadIfReady() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return takeMergedPayloadIfReadyLocked()
    }

    /// Push one decoded frame; if the session completes and CRC32 passes, returns merged payload (single lock).
    /// `pushed` is false when the core rejected the frame (e.g. session / chunk mismatch).
    public func pushDecodedReportCompletion(_ frame: VDTWireFrame) -> (pushed: Bool, merged: Data?) {
        lock.lock()
        defer { lock.unlock() }
        guard pushDecodedLocked(frame) else { return (false, nil) }
        let merged = takeMergedPayloadIfReadyLocked()
        return (true, merged)
    }

    private func pushDecodedLocked(_ frame: VDTWireFrame) -> Bool {
        guard let handle else { return false }
        var hdr = VDTFrameHeaderC(
            version: frame.version,
            frame_type: frame.frameType,
            flags: frame.flags,
            session_id: frame.sessionId,
            chunk_index: frame.chunkIndex,
            chunk_count: frame.chunkCount,
            payload_length: frame.payloadLength
        )
        if frame.payload.isEmpty {
            return vdt_session_assembler_push_decoded(handle, &hdr, nil, 0) != 0
        }
        return frame.payload.withUnsafeBytes { raw -> Bool in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return false }
            return vdt_session_assembler_push_decoded(handle, &hdr, base, frame.payload.count) != 0
        }
    }

    private func takeMergedPayloadIfReadyLocked() -> Data? {
        guard let handle else { return nil }
        let cap = Int(vdt_max_transfer_payload_bytes())
        var buf = [UInt8](repeating: 0, count: cap)
        let n: Int = buf.withUnsafeMutableBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return 0 }
            return Int(vdt_session_assembler_take_merged_payload(handle, base, ptr.count))
        }
        guard n > 0 else { return nil }
        return Data(buf.prefix(n))
    }
}
