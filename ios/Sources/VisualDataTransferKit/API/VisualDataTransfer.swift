import Foundation

/// Top-level namespace for Visual Data Transfer kit operations (Phase 6 public API).
public enum VisualDataTransfer {
    /// Encodes `message` into a single transmit **loop cycle** using `configuration`.
    @inlinable
    public static func encodeLoopCycle(
        message: Data,
        configuration: VDTTransferConfiguration = VDTTransferConfiguration()
    ) -> VDTFramedSession? {
        VDTFramedSession(
            sessionId: configuration.sessionId,
            message: message,
            encodingMode: configuration.encodingMode,
            maxPayloadBytes: configuration.maxPayloadBytes,
            loopOptions: configuration.loopOptions
        )
    }
}
