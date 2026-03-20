import CoreGraphics
import Foundation

/// Full-bleed 2-bit grid decode from an 8-bit luma buffer (same rules as `python/grid_codec.py`).
public struct LumaGridDecoder: Sendable {
    public init() {}

    /// Fixed luminance thresholds (Python parity).
    public static func symbolFixed(luma y: Float) -> UInt8 {
        if y < 63.75 { return 0 }
        if y < 148.75 { return 1 }
        if y < 233.75 { return 2 }
        return 3
    }

    /// Quantize per-cell luma samples (row-major) to 2-bit symbols. Adaptive mode uses min–max quartiles on this frame.
    public static func symbolsFromCellLuma(_ samples: Data, gridRows: Int, gridCols: Int, adaptiveLevels: Bool) -> [UInt8]? {
        let n = gridRows * gridCols
        guard gridRows > 0, gridCols > 0, samples.count >= n else { return nil }
        var ys: [Float] = []
        ys.reserveCapacity(n)
        for i in 0..<n {
            ys.append(Float(samples[i]))
        }
        if adaptiveLevels {
            let lo = ys.min() ?? 0
            let hi = ys.max() ?? 255
            let span = hi - lo
            if span <= 4 {
                return ys.map { symbolFixed(luma: $0) }
            }
            let t1 = lo + span * 0.25
            let t2 = lo + span * 0.50
            let t3 = lo + span * 0.75
            return ys.map { y in
                if y < t1 { return 0 }
                if y < t2 { return 1 }
                if y < t3 { return 2 }
                return 3
            }
        }
        return ys.map { symbolFixed(luma: $0) }
    }

    /// Pack 2-bit symbols MSB-first per byte (same bit order as viewport sampling path).
    public static func bytes(fromSymbols symbols: [UInt8], maxOutputBytes: Int?) -> Data {
        symbolsToBytes(symbols, maxBytes: maxOutputBytes)
    }

    public func decode(
        luma: Data,
        width: Int,
        height: Int,
        gridRows: Int,
        gridCols: Int,
        marginPx: Int = 8,
        gapPx: Int = 2,
        maxOutputBytes: Int? = nil,
        adaptiveLevels: Bool = false
    ) -> Data? {
        guard let symbols = cellSymbolsFromViewport(
            luma: luma,
            width: width,
            height: height,
            gridRows: gridRows,
            gridCols: gridCols,
            marginPx: marginPx,
            gapPx: gapPx,
            adaptiveLevels: adaptiveLevels
        ) else { return nil }
        return Self.symbolsToBytes(symbols, maxBytes: maxOutputBytes)
    }

    /// Decode using precomputed cell luma (e.g. `VDTFullBleedGridSampler`).
    public func decodeFromCellLumaSamples(
        cells: Data,
        gridRows: Int,
        gridCols: Int,
        maxOutputBytes: Int? = nil,
        adaptiveLevels: Bool = false
    ) -> Data? {
        guard let symbols = Self.symbolsFromCellLuma(cells, gridRows: gridRows, gridCols: gridCols, adaptiveLevels: adaptiveLevels)
        else { return nil }
        return Self.symbolsToBytes(symbols, maxBytes: maxOutputBytes)
    }

    public func cellSymbolsFromViewport(
        luma: Data,
        width: Int,
        height: Int,
        gridRows: Int,
        gridCols: Int,
        marginPx: Int,
        gapPx: Int,
        adaptiveLevels: Bool
    ) -> [UInt8]? {
        guard width > 0, height > 0, gridRows > 0, gridCols > 0 else { return nil }
        let need = width * height
        guard luma.count >= need else { return nil }

        var samples = Data()
        samples.reserveCapacity(gridRows * gridCols)
        for r in 0..<gridRows {
            for c in 0..<gridCols {
                let rect = Self.cellRect(
                    viewportWidth: width,
                    viewportHeight: height,
                    rows: gridRows,
                    cols: gridCols,
                    margin: marginPx,
                    gap: gapPx,
                    row: r,
                    col: c
                )
                let cx = Int((rect.minX + rect.maxX) * 0.5)
                let cy = Int((rect.minY + rect.maxY) * 0.5)
                let x = min(max(0, cx), width - 1)
                let y = min(max(0, cy), height - 1)
                let v = luma[y * width + x]
                samples.append(v)
            }
        }
        return Self.symbolsFromCellLuma(samples, gridRows: gridRows, gridCols: gridCols, adaptiveLevels: adaptiveLevels)
    }

    private static func cellRect(
        viewportWidth: Int,
        viewportHeight: Int,
        rows: Int,
        cols: Int,
        margin: Int,
        gap: Int,
        row: Int,
        col: Int
    ) -> CGRect {
        let innerW = CGFloat(viewportWidth - 2 * margin)
        let innerH = CGFloat(viewportHeight - 2 * margin)
        let cellW = (innerW - CGFloat(gap * (cols - 1))) / CGFloat(cols)
        let cellH = (innerH - CGFloat(gap * (rows - 1))) / CGFloat(rows)
        let x0 = CGFloat(margin) + CGFloat(col) * (cellW + CGFloat(gap))
        let y0 = CGFloat(margin) + CGFloat(row) * (cellH + CGFloat(gap))
        return CGRect(x: x0, y: y0, width: cellW, height: cellH)
    }

    private static func symbolsToBytes(_ symbols: [UInt8], maxBytes: Int?) -> Data {
        var bits: [UInt8] = []
        bits.reserveCapacity(symbols.count * 2)
        for s in symbols {
            let v = s & 0x03
            bits.append((v >> 1) & 1)
            bits.append(v & 1)
        }
        var out = Data()
        var i = 0
        while i + 8 <= bits.count {
            var b: UInt8 = 0
            for j in 0..<8 {
                b = (b << 1) | bits[i + j]
            }
            out.append(b)
            i += 8
            if let m = maxBytes, out.count >= m { break }
        }
        return out
    }
}
