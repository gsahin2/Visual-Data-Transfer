import Foundation

/// Options for `vdt_transfer_loop_cycle_ex` (Phase 5 descriptor cadence). Safe mode ignores `repeatDescriptorEveryKPayloads`.
public struct VDTTransferLoopBuildOptions: Sendable {
    /// Normal mode: insert an extra descriptor before payload index `i` when `i > 0 && i % k == 0`. `0` = single leading descriptor only.
    public var repeatDescriptorEveryKPayloads: UInt16
    /// Append a duplicate descriptor after the last payload (wrap / late-join hint).
    public var trailingDescriptor: Bool

    public init(repeatDescriptorEveryKPayloads: UInt16 = 0, trailingDescriptor: Bool = false) {
        self.repeatDescriptorEveryKPayloads = repeatDescriptorEveryKPayloads
        self.trailingDescriptor = trailingDescriptor
    }
}
