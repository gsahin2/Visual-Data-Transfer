import CoreGraphics
import SwiftUI

/// Matrix-style glyphs drawn only in **gutters** (outer margin + inter-cell gaps). Cell interiors stay untouched so
/// `LumaGridDecoder` center samples match a plain `SymbolGridView`.
public struct MatrixRainGutterOverlay: View {
    private let spec: VDTLayoutSpec
    private let animating: Bool
    private let charSet: [Character]

    public init(spec: VDTLayoutSpec, animating: Bool = true) {
        self.spec = spec
        self.animating = animating
        charSet = Array("01ｱｲｳｴｵ789ﾊﾋﾌﾍｶｷｸｹｺ")
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !animating)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(Array(MatrixRainGutterOverlay.gutterRects(
                    spec: spec,
                    viewport: CGSize(width: CGFloat(spec.viewportWidth), height: CGFloat(spec.viewportHeight))
                ).enumerated()), id: \.offset) { pair in
                    MatrixRainGutterStrip(gutterIndex: pair.offset, time: t, charSet: charSet)
                        .frame(width: max(1, pair.element.width), height: max(1, pair.element.height))
                        .position(x: pair.element.midX, y: pair.element.midY)
                }
            }
            .frame(width: CGFloat(spec.viewportWidth), height: CGFloat(spec.viewportHeight))
            .clipShape(MatrixRainGuttersShape(spec: spec))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Rectangles that do not intersect any cell interior (same layout as core / `LumaGridDecoder`).
    public static func gutterRects(spec: VDTLayoutSpec, viewport: CGSize) -> [CGRect] {
        let vw = viewport.width
        let vh = viewport.height
        let m = CGFloat(spec.marginPx)
        let g = CGFloat(spec.gapPx)
        let cols = Int(spec.gridCols)
        let rows = Int(spec.gridRows)
        guard cols > 0, rows > 0, m >= 0, g >= 0, vw > m * 2, vh > m * 2 else { return [] }

        let innerW = vw - 2 * m
        let innerH = vh - 2 * m
        let cellW = (innerW - g * CGFloat(max(cols - 1, 0))) / CGFloat(cols)
        let cellH = (innerH - g * CGFloat(max(rows - 1, 0))) / CGFloat(rows)

        var rects: [CGRect] = []
        rects.reserveCapacity(2 * (rows + cols) + 4)

        rects.append(CGRect(x: 0, y: 0, width: vw, height: m))
        rects.append(CGRect(x: 0, y: vh - m, width: vw, height: m))
        rects.append(CGRect(x: 0, y: 0, width: m, height: vh))
        rects.append(CGRect(x: vw - m, y: 0, width: m, height: vh))

        if rows > 1 {
            for r in 0..<(rows - 1) {
                let yTop = m + CGFloat(r) * (cellH + g) + cellH
                rects.append(CGRect(x: m, y: yTop, width: innerW, height: g))
            }
        }
        if cols > 1 {
            for c in 0..<(cols - 1) {
                let xLeft = m + CGFloat(c) * (cellW + g) + cellW
                rects.append(CGRect(x: xLeft, y: m, width: g, height: innerH))
            }
        }
        return rects
    }
}

/// Clip mask = union of gutter rects (cell data never covered).
public struct MatrixRainGuttersShape: Shape {
    public var spec: VDTLayoutSpec

    public init(spec: VDTLayoutSpec) {
        self.spec = spec
    }

    public func path(in rect: CGRect) -> Path {
        let gutters = MatrixRainGutterOverlay.gutterRects(
            spec: spec,
            viewport: CGSize(width: rect.width, height: rect.height)
        )
        var p = Path()
        for r in gutters {
            p.addRect(r)
        }
        return p
    }
}

private struct MatrixRainGutterStrip: View {
    let gutterIndex: Int
    let time: TimeInterval
    let charSet: [Character]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let step: CGFloat = 13
            let scroll = CGFloat((time * 48.0).truncatingRemainder(dividingBy: 14.0))
            let pts = Self.glyphPositions(width: w, height: h, step: step, scroll: scroll)
            let n = max(charSet.count, 1)
            ZStack(alignment: .topLeading) {
                ForEach(Array(pts.enumerated()), id: \.offset) { pair in
                    let pt = pair.element
                    let hidx = ((gutterIndex * 17 + Int(pt.x) * 3 + Int(pt.y) + Int(time * 7.0)) % n + n) % n
                    Text(String(charSet[hidx]))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.green.opacity(0.38))
                        .position(x: pt.x, y: pt.y)
                }
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
    }

    private static func glyphPositions(width: CGFloat, height: CGFloat, step: CGFloat, scroll: CGFloat) -> [CGPoint] {
        guard width > 0, height > 0, step > 0 else { return [] }
        var out: [CGPoint] = []
        var y = scroll.truncatingRemainder(dividingBy: step)
        while y < height + step {
            var x = CGFloat(0)
            while x < width {
                out.append(CGPoint(x: x + step * 0.45, y: y))
                x += step
            }
            y += step
        }
        return out
    }
}
