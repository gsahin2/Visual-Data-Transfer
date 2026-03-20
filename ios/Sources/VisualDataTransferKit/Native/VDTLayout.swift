import CoreGraphics
import Foundation
import VDTCoreC

public struct VDTLayoutSpec: Sendable {
    public var viewportWidth: UInt32
    public var viewportHeight: UInt32
    public var gridRows: UInt16
    public var gridCols: UInt16
    public var marginPx: UInt32
    public var gapPx: UInt32

    public init(
        viewportWidth: UInt32,
        viewportHeight: UInt32,
        gridRows: UInt16,
        gridCols: UInt16,
        marginPx: UInt32 = 8,
        gapPx: UInt32 = 2
    ) {
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.gridRows = gridRows
        self.gridCols = gridCols
        self.marginPx = marginPx
        self.gapPx = gapPx
    }

    public func cellRect(row: UInt16, col: UInt16) -> CGRect {
        var x0: Float = 0
        var y0: Float = 0
        var x1: Float = 0
        var y1: Float = 0
        vdt_layout_cell_rect(
            viewportWidth,
            viewportHeight,
            gridRows,
            gridCols,
            marginPx,
            gapPx,
            row,
            col,
            &x0,
            &y0,
            &x1,
            &y1
        )
        return CGRect(x: CGFloat(x0), y: CGFloat(y0), width: CGFloat(x1 - x0), height: CGFloat(y1 - y0))
    }

    public func linearIndex(row: UInt16, col: UInt16) -> UInt32 {
        vdt_symbol_cell_to_index(gridRows, gridCols, row, col)
    }
}
