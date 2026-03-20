import Foundation

/// Per-cell majority over the last up to `depth` symbol frames (values 0…3). Reduces single-frame noise.
public struct TemporalSymbolMajority: Sendable {
    public let cellCount: Int
    public let depth: Int

    private var frames: [[UInt8]] = []

    public init(cellCount: Int, depth: Int = 3) {
        self.cellCount = cellCount
        self.depth = max(1, depth)
    }

    public mutating func reset() {
        frames.removeAll(keepingCapacity: true)
    }

    /// Pushes one row-major symbol grid; returns a voted grid using all buffered frames (1…`depth`).
    public mutating func push(_ symbols: [UInt8]) -> [UInt8]? {
        guard symbols.count == cellCount else { return nil }
        if frames.count >= depth {
            frames.removeFirst()
        }
        frames.append(symbols)
        var out = [UInt8](repeating: 0, count: cellCount)
        for i in 0..<cellCount {
            var counts = [0, 0, 0, 0]
            for f in frames {
                let s = Int(f[i]) & 3
                counts[s] += 1
            }
            let best = counts.enumerated().max(by: { a, b in
                if a.element != b.element { return a.element < b.element }
                return a.offset < b.offset
            })?.offset ?? 0
            out[i] = UInt8(best)
        }
        return out
    }
}
