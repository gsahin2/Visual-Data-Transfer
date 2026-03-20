import Foundation
import VDTCoreC

public enum VDTCRC16 {
    public static func checksum(_ data: Data) -> UInt16 {
        data.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return vdt_crc16(base, raw.count)
        }
    }
}
