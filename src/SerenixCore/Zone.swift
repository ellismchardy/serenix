import Foundation

/// Where one Nightly Metric sits against its Baseline, or for SpO2 against fixed levels
/// (GLOSSARY, spec 002, Zones). Worked out on unrounded values.
///
/// Every cut-off is an assumption: from the 002 prototype, tune with real Nights.
public enum Zone: Equatable, Sendable {
    case inRange
    case watch
    case outOfRange

    /// HRV's change from Baseline as a fraction of it: In range from −5%, Watch from −15%.
    private static let hrvInRangeFrom = -0.05
    private static let hrvWatchFrom = -0.15
    /// Resting HR above Baseline, bpm: In range up to +1, Watch up to +4.
    private static let restingHRInRangeUpTo = 1.0
    private static let restingHRWatchUpTo = 4.0
    /// Respiratory rate either side of Baseline, br/min: In range up to 0.5, Watch up to 1.0.
    private static let respiratoryRateInRangeUpTo = 0.5
    private static let respiratoryRateWatchUpTo = 1.0
    /// Skin temperature either side of Baseline, °C: In range up to 0.3, Watch up to 0.6.
    private static let skinTemperatureInRangeUpTo = 0.3
    private static let skinTemperatureWatchUpTo = 0.6
    /// SpO2, %: In range from 95, Watch from 92.
    private static let spo2InRangeFrom = 95.0
    private static let spo2WatchFrom = 92.0
    /// How far a measure may sit past a cut-off and still count as on it, so floating-point
    /// error can't move a value on the boundary into the next Zone (34.6 − 34.0 is
    /// 0.6000000000000014). Far below any reading's precision.
    private static let boundaryTolerance = 1e-9

    /// The Zone of `value`; nil when the metric needs a Baseline and has none (Calibrating), or
    /// HRV's Baseline is 0 or less, which gives no meaningful change.
    init?(_ metric: NightlyMetric, value: Double, baseline: Double?) {
        switch (metric, baseline) {
        case (.spo2, _):
            self = Self.atLeast(value, inRange: Self.spo2InRangeFrom, watch: Self.spo2WatchFrom)
        case (.hrv, let baseline?) where baseline > 0:
            self = Self.atLeast(
                (value - baseline) / baseline,
                inRange: Self.hrvInRangeFrom,
                watch: Self.hrvWatchFrom
            )
        case (.restingHR, let baseline?):
            self = Self.atMost(
                value - baseline,
                inRange: Self.restingHRInRangeUpTo,
                watch: Self.restingHRWatchUpTo
            )
        case (.respiratoryRate, let baseline?):
            self = Self.atMost(
                abs(value - baseline),
                inRange: Self.respiratoryRateInRangeUpTo,
                watch: Self.respiratoryRateWatchUpTo
            )
        case (.skinTemperature, let baseline?):
            self = Self.atMost(
                abs(value - baseline),
                inRange: Self.skinTemperatureInRangeUpTo,
                watch: Self.skinTemperatureWatchUpTo
            )
        default:
            return nil
        }
    }

    /// The values around `baseline` that are In range, for the Nightly Metric popup's band (spec
    /// 002, Popups); nil on a side with no limit. Both nil for SpO2, which has no Baseline, and
    /// for HRV against a Baseline of 0 or less.
    static func inRangeLimits(_ metric: NightlyMetric, baseline: Double)
        -> (low: Double?, high: Double?)
    {
        switch metric {
        case .hrv:
            baseline > 0 ? (baseline * (1 + hrvInRangeFrom), nil) : (nil, nil)
        case .restingHR:
            (nil, baseline + restingHRInRangeUpTo)
        case .respiratoryRate:
            (baseline - respiratoryRateInRangeUpTo, baseline + respiratoryRateInRangeUpTo)
        case .skinTemperature:
            (baseline - skinTemperatureInRangeUpTo, baseline + skinTemperatureInRangeUpTo)
        case .spo2:
            (nil, nil)
        }
    }

    /// Where `value` sits on its tile's gauge, 0 (bottom) to 1 (top), clamped (spec 002, Tiles):
    /// the Baseline at 0.5 and the Watch limit on each side at the ends, or for SpO2 a fixed
    /// scale. Nil when the metric needs a Baseline and has none, or HRV's Baseline is 0 or less.
    static func gaugePosition(_ metric: NightlyMetric, value: Double, baseline: Double?)
        -> Double?
    {
        let position: Double
        switch (metric, baseline) {
        case (.spo2, _):
            position = (value - spo2GaugeBottom) / (spo2GaugeTop - spo2GaugeBottom)
        case (.hrv, let baseline?) where baseline > 0:
            position = centred((value - baseline) / baseline, limit: -hrvWatchFrom)
        case (.restingHR, let baseline?):
            position = centred(value - baseline, limit: restingHRWatchUpTo)
        case (.respiratoryRate, let baseline?):
            position = centred(value - baseline, limit: respiratoryRateWatchUpTo)
        case (.skinTemperature, let baseline?):
            position = centred(value - baseline, limit: skinTemperatureWatchUpTo)
        default:
            return nil
        }
        // A value that gives no real position (e.g. NaN) shows an empty gauge.
        return position.isFinite ? min(max(position, 0), 1) : nil
    }

    /// The Baseline at 0.5, `limit` either side at 0 and 1.
    private static func centred(_ difference: Double, limit: Double) -> Double {
        0.5 + difference / (2 * limit)
    }

    /// The SpO2 at the bottom of its gauge, % (spec 002, Tiles).
    private static let spo2GaugeBottom = 88.0
    /// The SpO2 at the top of its gauge, % (spec 002, Tiles).
    private static let spo2GaugeTop = 100.0

    /// For measures where higher is better.
    private static func atLeast(_ measure: Double, inRange: Double, watch: Double) -> Zone {
        let tolerance = boundaryTolerance
        return measure >= inRange - tolerance
            ? .inRange : measure >= watch - tolerance ? .watch : .outOfRange
    }

    /// For measures where lower is better.
    private static func atMost(_ measure: Double, inRange: Double, watch: Double) -> Zone {
        let tolerance = boundaryTolerance
        return measure <= inRange + tolerance
            ? .inRange : measure <= watch + tolerance ? .watch : .outOfRange
    }
}
