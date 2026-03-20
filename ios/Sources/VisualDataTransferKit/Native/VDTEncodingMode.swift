import Foundation

/// Matches `vdt/protocol/descriptor.hpp` `EncodingMode` and C API `vdt_transfer_loop_cycle` encoding byte.
public enum VDTEncodingMode: UInt8, CaseIterable, Identifiable, Sendable {
    case safe = 0
    case normal = 1

    public var id: UInt8 { rawValue }

    public var title: String {
        switch self {
        case .safe: return "Safe"
        case .normal: return "Normal"
        }
    }
}
