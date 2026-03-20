import SwiftUI

/// High-contrast L-shaped corner brackets around the data grid (finder-style), outside the symbol cells.
public struct CornerMarkersView: View {
    private let spec: VDTLayoutSpec
    private let pulse: Bool

    public init(spec: VDTLayoutSpec, pulse: Bool = true) {
        self.spec = spec
        self.pulse = pulse
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !pulse)) { timeline in
            Canvas { context, size in
                let w = max(1, Int(size.width.rounded()))
                let h = max(1, Int(size.height.rounded()))
                var s = spec
                s.viewportWidth = UInt32(w)
                s.viewportHeight = UInt32(h)
                let topLeft = s.cellRect(row: 0, col: 0)
                let maxR = s.gridRows > 0 ? s.gridRows - 1 : 0
                let maxC = s.gridCols > 0 ? s.gridCols - 1 : 0
                let bottomRight = s.cellRect(row: maxR, col: maxC)
                let inset: CGFloat = 4
                let x0 = topLeft.minX - inset
                let y0 = topLeft.minY - inset
                let x1 = bottomRight.maxX + inset
                let y1 = bottomRight.maxY + inset
                let arm: CGFloat = max(14, min(topLeft.width, topLeft.height) * 0.9)
                let lw: CGFloat = 3
                let phase = pulse ? 0.12 * sin(timeline.date.timeIntervalSinceReferenceDate * 4) + 0.92 : 1.0
                let color = Color.white.opacity(phase)
                func strokeL(_ innerX: CGFloat, _ innerY: CGFloat, flipH: Bool, flipV: Bool) {
                    var hSeg = CGRect(x: innerX, y: innerY, width: arm, height: lw)
                    var vSeg = CGRect(x: innerX, y: innerY, width: lw, height: arm)
                    if flipH {
                        hSeg.origin.x = innerX - arm + lw
                    }
                    if flipV {
                        vSeg.origin.y = innerY - arm + lw
                    }
                    context.fill(Path(hSeg), with: .color(color))
                    context.fill(Path(vSeg), with: .color(color))
                }
                strokeL(x0, y0, flipH: false, flipV: false)
                strokeL(x1, y0, flipH: true, flipV: false)
                strokeL(x0, y1, flipH: false, flipV: true)
                strokeL(x1, y1, flipH: true, flipV: true)
            }
        }
    }
}
