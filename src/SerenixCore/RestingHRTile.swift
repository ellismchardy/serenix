import Foundation

/// The Resting HR tile on the Today screen (spec 007, Today screen): the Day's Resting HR, not a
/// Nightly Metric, so it has no Zone, an empty gauge and no popup.
public struct RestingHRTile: Equatable, Sendable {
    public let name = "Resting HR"
    /// In whole bpm, e.g. "62 bpm"; "—" when the Day has none.
    public let valueText: String
    /// "So far today" on today, where other tiles have their status word; nil on an earlier Day.
    public let statusText: String?
    /// Always nil: an empty gauge.
    public let gauge: Double? = nil
    /// Always nil: no Zone.
    public let zone: Zone? = nil

    init(restingHR: Double?, isToday: Bool) {
        valueText = restingHR.map { "\(wholeText($0)) bpm" } ?? missingText
        statusText = isToday ? "So far today" : nil
    }
}

/// A tile in the Today screen's 2-column grid, under the full-width Time Asleep tile.
public enum TodayTile: Equatable, Sendable, Identifiable {
    case metric(MetricTile)
    case restingHR(RestingHRTile)

    /// What the tile shows, so a list keeps each tile's identity across Days.
    public var id: String {
        switch self {
        case .metric(let tile): "metric.\(tile.metric)"
        case .restingHR: "restingHR"
        }
    }
}
