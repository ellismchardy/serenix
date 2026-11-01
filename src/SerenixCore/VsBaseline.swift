import Foundation

/// The "vs your Baseline" section (spec 002): HRV and Resting HR against their Baselines, or one
/// line while either Baseline is Calibrating.
public enum VsBaseline: Equatable, Sendable {
    /// HRV, then Resting HR.
    case comparisons([BaselineComparison])
    case calibrating(String)

    /// The metrics compared, in order.
    static let metrics: [NightlyMetric] = [.hrv, .restingHR]
}

/// Which way a metric moved from its Baseline.
public enum BaselineDirection: Equatable, Sendable {
    case up
    case down
}

/// One metric in "vs your Baseline".
public struct BaselineComparison: Equatable, Sendable {
    public let metric: NightlyMetric
    /// As on the metric's tile.
    public let valueText: String
    /// As on the metric's tile, e.g. "+14%" or "−3 bpm".
    public let differenceText: String
    /// Nil when the value is missing or the difference shows as zero.
    public let direction: BaselineDirection?
    /// HRV up and Resting HR down are the good way; nil without a direction.
    public let movedTheGoodWay: Bool?

    init(_ tile: MetricTile) {
        metric = tile.metric
        valueText = tile.valueText
        differenceText = tile.differenceText
        direction = tile.differenceDirection
        let goodWay: BaselineDirection = tile.metric == .restingHR ? .down : .up
        movedTheGoodWay = direction.map { $0 == goodWay }
    }
}
