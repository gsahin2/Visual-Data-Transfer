import SwiftUI

/// Narrow decorative strip inspired by a “Matrix” column — keep beside the grid, not over cells.
public struct MatrixRainStrip: View {
    private let charSet: [Character]

    public init() {
        charSet = Array("01ｱｲｳｴｵ789ﾊﾋﾌﾍｶｷｸｹｺ")
    }

    public var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    Color.black.opacity(0.92)
                    ForEach(0..<48, id: \.self) { i in
                        let idx = (i * 31 &+ Int(t * 5.0)) % charSet.count
                        let c = charSet[idx]
                        let rowY = CGFloat(i) * 14.0
                        let scroll = CGFloat((t * 55.0).truncatingRemainder(dividingBy: 14.0))
                        let y = (rowY + scroll).truncatingRemainder(dividingBy: max(geo.size.height + 14, 1))
                        Text(String(c))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.green.opacity(0.3))
                            .position(x: geo.size.width * 0.5, y: y)
                    }
                }
                .clipped()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
