import CoreGraphics
import SwiftUI

/// Deterministic **2 bits per cell** (4 luminance levels), MSB-first within each byte, row-major — matches V1 constraints.
public struct SymbolGridRenderer {
    public let rows: Int
    public let cols: Int
    private let symbols: [UInt8]

    public init(message: Data, rows: Int, cols: Int) {
        self.rows = max(1, rows)
        self.cols = max(1, cols)
        let totalCells = self.rows * self.cols
        var out = [UInt8](repeating: 0, count: totalCells)
        var bitBuffer: UInt32 = 0
        var bitCount = 0
        var byteIndex = 0
        let bytes = [UInt8](message)
        for i in 0..<totalCells {
            while bitCount < 2 {
                if byteIndex < bytes.count {
                    let b = bytes[byteIndex]
                    byteIndex += 1
                    bitBuffer = (bitBuffer << 8) | UInt32(b)
                    bitCount += 8
                } else {
                    bitBuffer <<= 2
                    bitCount += 2
                }
            }
            let shift = bitCount - 2
            let twoBits = UInt8((bitBuffer >> shift) & 0x03)
            bitCount -= 2
            out[i] = twoBits
        }
        symbols = out
    }

    public func color(forSymbol symbol: UInt8) -> Color {
        let s = Double(symbol & 0x03)
        let v = s / 3.0
        return Color(white: v)
    }

    public func symbol(atRow row: Int, col: Int) -> UInt8 {
        guard row >= 0, col >= 0, row < rows, col < cols else { return 0 }
        return symbols[row * cols + col]
    }
}

public struct SymbolGridView: View {
    private let renderer: SymbolGridRenderer
    private let spec: VDTLayoutSpec

    public init(message: Data, spec: VDTLayoutSpec) {
        self.spec = spec
        renderer = SymbolGridRenderer(message: message, rows: Int(spec.gridRows), cols: Int(spec.gridCols))
    }

    public var body: some View {
        Canvas { context, size in
            let w = UInt32(max(1, Int(size.width.rounded())))
            let h = UInt32(max(1, Int(size.height.rounded())))
            var localSpec = spec
            localSpec.viewportWidth = w
            localSpec.viewportHeight = h
            for r in 0..<Int(spec.gridRows) {
                for c in 0..<Int(spec.gridCols) {
                    let rect = localSpec.cellRect(row: UInt16(r), col: UInt16(c))
                    let sym = renderer.symbol(atRow: r, col: c)
                    let path = Path(rect)
                    context.fill(path, with: .color(renderer.color(forSymbol: sym)))
                }
            }
        }
        .background(Color.black)
    }
}
