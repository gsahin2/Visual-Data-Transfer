import Foundation
import VDTCoreC

/// C++ `FullBleedMarkerDetector` → homography → `GridSampler` (bilinear luma per cell).
public enum VDTFullBleedGridSampler: Sendable {
    /// Row-major cell luma (`rows * cols` bytes), or `nil` if dimensions or buffer are invalid.
    public static func sampleCells(luma: Data, width: Int, height: Int, rows: Int, cols: Int) -> Data? {
        guard width >= 2, height >= 2, rows > 0, cols > 0 else { return nil }
        let npix = width * height
        guard luma.count >= npix else { return nil }
        let outCount = rows * cols
        var out = Data(count: outCount)
        let ok: Int32 = out.withUnsafeMutableBytes { dst in
            guard let db = dst.bindMemory(to: UInt8.self).baseAddress else { return Int32(0) }
            return luma.withUnsafeBytes { src in
                guard let sb = src.bindMemory(to: UInt8.self).baseAddress else { return Int32(0) }
                return vdt_sample_grid_full_bleed(
                    sb,
                    UInt32(width),
                    UInt32(height),
                    UInt16(rows),
                    UInt16(cols),
                    db,
                    outCount
                )
            }
        }
        return ok != 0 ? out : nil
    }
}
