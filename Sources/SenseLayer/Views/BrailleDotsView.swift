import SwiftUI

/// Predefined braille sizing for deafblind-first layout.
public enum BrailleStyle {
    case normal
    case large

    public var dotSize: CGFloat {
        switch self {
        case .normal: return 4
        case .large: return 6
        }
    }

    public var cellSpacing: CGFloat {
        switch self {
        case .normal: return 6
        case .large: return 8
        }
    }

    public var dotSpacing: CGFloat {
        switch self {
        case .normal: return 3
        case .large: return 4
        }
    }
}

/// Renders a row of braille cells as visual dot grids.
/// Each cell is 2 columns x 3 rows. Raised = bright, flat = dim.
public struct BrailleDotsView: View {
    public let cells: [BrailleCell]
    public var dotSize: CGFloat = 5
    public var cellSpacing: CGFloat = 8
    public var dotSpacing: CGFloat = 3

    public init(cells: [BrailleCell], dotSize: CGFloat = 5, cellSpacing: CGFloat = 8, dotSpacing: CGFloat = 3) {
        self.cells = cells
        self.dotSize = dotSize
        self.cellSpacing = cellSpacing
        self.dotSpacing = dotSpacing
    }

    public var body: some View {
        HStack(spacing: cellSpacing) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                singleCell(cell)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .clipped()
    }

    private func singleCell(_ cell: BrailleCell) -> some View {
        // Dot layout: col0 = dots 1,2,3  col1 = dots 4,5,6
        HStack(spacing: dotSpacing) {
            VStack(spacing: dotSpacing) {
                dot(cell.dots[0])
                dot(cell.dots[1])
                dot(cell.dots[2])
            }
            VStack(spacing: dotSpacing) {
                dot(cell.dots[3])
                dot(cell.dots[4])
                dot(cell.dots[5])
            }
        }
    }

    private func dot(_ raised: Bool) -> some View {
        Circle()
            .fill(raised ? Color.white : Color.white.opacity(0.15))
            .frame(width: dotSize, height: dotSize)
    }
}

/// Convenience: render a text string as braille dots.
public struct BrailleTextDotsView: View {
    public let text: String
    public var dotSize: CGFloat
    public var cellSpacing: CGFloat

    public init(_ text: String, dotSize: CGFloat = 4, cellSpacing: CGFloat = 6) {
        self.text = text
        self.dotSize = dotSize
        self.cellSpacing = cellSpacing
    }

    public var body: some View {
        BrailleDotsView(
            cells: BrailleCellMapper.cells(for: text),
            dotSize: dotSize,
            cellSpacing: cellSpacing
        )
    }
}
