import SerenixCore
import SwiftUI

/// One Nightly Metric's tile on the Today screen (spec 002, Tiles): its name, value, difference
/// from Baseline (or SpO2's level) and trend line. The value and the line under it take the
/// Zone's colour.
struct MetricTileView: View {
    let tile: MetricTile

    var body: some View {
        TileCard(
            name: tile.metric.name,
            valueText: tile.valueText,
            detailText: tile.differenceText,
            colour: tile.zone?.colour,
            trend: tile.trend
        )
    }
}

/// The Time Asleep tile (spec 002, Tiles): the duration, Sleep Onset → Final Wake and its trend
/// line. It has no Zone.
struct TimeAsleepTileView: View {
    let tile: TimeAsleepTile

    var body: some View {
        TileCard(
            name: "Time Asleep",
            valueText: tile.valueText,
            detailText: tile.spanText,
            colour: nil,
            trend: tile.trend
        )
    }
}

/// The card both kinds of tile draw.
private struct TileCard: View {
    let name: String
    let valueText: String
    let detailText: String
    /// The Zone's colour; nil draws the value in the primary colour and the line in secondary.
    let colour: Color?
    let trend: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(valueText)
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(colour ?? .primary)
            Text(detailText)
                .font(.footnote)
                .foregroundStyle(colour ?? .secondary)
            TrendLine(values: trend)
                .stroke(colour ?? .secondary, lineWidth: 1.5)
                .frame(height: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// A trend line through the Today view's values, oldest on the left, scaled to fill the frame.
/// Fewer than two values draw nothing.
private struct TrendLine: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count >= 2, let low = values.min(), let high = values.max() else {
            return path
        }
        let range = high - low
        let step = rect.width / CGFloat(values.count - 1)
        for (index, value) in values.enumerated() {
            // A flat line sits in the middle.
            let height = range > 0 ? (value - low) / range : 0.5
            let point = CGPoint(
                x: rect.minX + step * CGFloat(index),
                y: rect.maxY - rect.height * height
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

extension Zone {
    /// The Zone's colour (spec 002, Zones): green, amber, red.
    var colour: Color {
        switch self {
        case .inRange: .green
        case .watch: .orange
        case .outOfRange: .red
        }
    }
}
