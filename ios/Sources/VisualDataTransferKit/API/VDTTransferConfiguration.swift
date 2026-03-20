import Foundation

/// Configuration for building one **loop cycle** (descriptor + payload wire frames) via the C core.
public struct VDTTransferConfiguration: Sendable {
    public var sessionId: UInt32
    public var encodingMode: VDTEncodingMode
    public var maxPayloadBytes: UInt16
    public var loopOptions: VDTTransferLoopBuildOptions

    public init(
        sessionId: UInt32 = 1,
        encodingMode: VDTEncodingMode = .normal,
        maxPayloadBytes: UInt16 = 1024,
        loopOptions: VDTTransferLoopBuildOptions = VDTTransferLoopBuildOptions()
    ) {
        self.sessionId = sessionId
        self.encodingMode = encodingMode
        self.maxPayloadBytes = maxPayloadBytes
        self.loopOptions = loopOptions
    }
}
