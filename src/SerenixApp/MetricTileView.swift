import SerenixCore
import SwiftUI

/// One Nightly Metric's tile on the Today screen (spec 002, Tiles): its name, value and
/// difference from Baseline.
struct MetricTileView: View {
    let tile: MetricTile

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tile.metric.name)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(tile.valueText)
                .font(.title2.bold())
                .monospacedDigit()
            Text(tile.differenceText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

extension NightlyMetric {
    /// The metric's name on its tile (GLOSSARY terms).
    var name: String {
        switch self {
        case .restingHR: "Resting HR"
        case .hrv: "HRV"
        }
    }
}
