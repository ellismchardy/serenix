import SerenixCore
import SwiftUI

/// One Nightly Metric's tile on the Today screen (spec 002, Tiles): its icon and name, value, a ✓
/// status word and a vertical gauge, the status word and gauge in the Zone's colour.
struct MetricTileView: View {
    let tile: MetricTile

    var body: some View {
        TileCard(
            icon: tile.metric.icon,
            name: tile.metric.name,
            valueText: tile.valueText,
            detailText: tile.statusText,
            colour: tile.zone?.colour,
            gauge: tile.gauge,
            showsGauge: true
        )
    }
}

/// The Time Asleep tile (spec 002, Tiles): the duration and Sleep Onset → Final Wake, with no
/// Zone, status word or gauge.
struct TimeAsleepTileView: View {
    let tile: TimeAsleepTile

    var body: some View {
        TileCard(
            icon: "bed.double",
            name: "Time Asleep",
            valueText: tile.valueText,
            detailText: tile.spanText,
            colour: nil,
            gauge: nil,
            showsGauge: false
        )
    }
}

/// The Resting HR tile (spec 007): the Day's Resting HR with Sleeping HR's heart icon, "So far
/// today" on today, and no Zone, so a white card with an empty gauge. It opens no popup.
struct RestingHRTileView: View {
    let tile: RestingHRTile

    var body: some View {
        TileCard(
            icon: NightlyMetric.sleepingHR.icon,
            name: tile.name,
            valueText: tile.valueText,
            detailText: tile.statusText ?? "",
            colour: tile.zone?.colour,
            gauge: tile.gauge,
            showsGauge: true
        )
    }
}

/// The card every kind of tile draws.
private struct TileCard: View {
    let icon: String
    let name: String
    let valueText: String
    /// The status word, for Time Asleep the Sleep Onset → Final Wake span, or for Resting HR "So
    /// far today" or nothing.
    let detailText: String
    /// The Zone's colour; nil for no Zone (Calibrating, missing, Time Asleep or Resting HR).
    let colour: Color?
    let gauge: Double?
    let showsGauge: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(name).foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: icon).foregroundStyle(Theme.accent)
                }
                .font(.footnote)
                .lineLimit(1)
                Text(valueText)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 4) {
                    if let colour {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(colour)
                            .accessibilityHidden(true)
                    }
                    Text(detailText)
                        .foregroundStyle(colour ?? .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.footnote.weight(.semibold))
            }
            Spacer(minLength: 0)
            if showsGauge {
                VerticalGauge(position: gauge, colour: colour ?? .secondary)
                    .frame(width: 14, height: 64)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .themeCard()
        .accessibilityElement(children: .combine)
    }
}

/// A vertical track filled from the bottom to the Today view's position, 0 to 1, with a knob at
/// the top of the fill. An empty track when there's no position.
private struct VerticalGauge: View {
    let position: Double?
    let colour: Color

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let width = geometry.size.width
            ZStack(alignment: .bottom) {
                Capsule().fill(Theme.accentSoft)
                if let position {
                    let filled = max(width, height * position)
                    Capsule()
                        .fill(colour.opacity(0.7))
                        .frame(height: filled)
                    Circle()
                        .fill(.white)
                        .overlay(Circle().strokeBorder(colour, lineWidth: 3))
                        .frame(width: width + 4, height: width + 4)
                        // Centred on the fill's rounded top, half a track-width below its end.
                        .offset(y: -(filled - width - 2))
                }
            }
            .frame(width: width, height: height, alignment: .bottom)
        }
    }
}

extension NightlyMetric {
    /// The SF Symbol on its tile.
    var icon: String {
        switch self {
        case .sleepingHR: "heart"
        case .hrv: "waveform.path.ecg"
        case .respiratoryRate: "lungs"
        case .skinTemperature: "thermometer.medium"
        case .spo2: "drop"
        }
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
