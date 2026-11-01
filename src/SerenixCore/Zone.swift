import Foundation

/// Where one Nightly Metric sits against its Baseline, or for SpO2 against fixed levels
/// (GLOSSARY, specs 002 and 004, Zones). Worked out on unrounded values.
///
/// Every cut-off is an assumption: from the 002 prototype or, where spec 004 says so, issue #14
/// and docs/research/nightly-metric-deviation.md. Tune with real Nights.
public enum Zone: Equatable, Sendable {
    case inRange
    case watch
    case outOfRange

    /// HRV's z, its change from Baseline on ln(RMSSD) in Spreads (spec 004): In range from −1.5
    /// up to +2.5, Watch down to −2.5 and anywhere above +2.5. High HRV is never Out of range.
    private static let hrvZInRangeFrom = -1.5
    private static let hrvZInRangeUpTo = 2.5
    private static let hrvZWatchFrom = -2.5
    /// Resting HR above Baseline, bpm, up only (spec 004): Watch from +3, Out of range from +5.
    /// A lower Resting HR is never a warning. The Watch cut-off is also the band's upper limit.
    private static let restingHRWatchFrom = 3.0
    private static let restingHROutOfRangeFrom = 5.0
    /// Respiratory rate's |z|, its distance from Baseline in Spreads, either side (spec 004): In
    /// range up to 1.5, Watch up to 2.5.
    private static let respiratoryRateZInRangeUpTo = 1.5
    private static let respiratoryRateZWatchUpTo = 2.5
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

    /// The Zone of `value`; nil when the metric needs a Baseline and has none (Calibrating), when
    /// HRV's Baseline is 0 or less, which gives no meaningful change, or when an HRV or
    /// respiratory rate Baseline has no Spread.
    init?(_ metric: NightlyMetric, value: Double, baseline: Baseline?) {
        switch (metric, baseline?.median) {
        case (.spo2, _):
            self = Self.atLeast(value, inRange: Self.spo2InRangeFrom, watch: Self.spo2WatchFrom)
        case (.hrv, _):
            guard let z = Self.z(metric, value: value, baseline: baseline) else { return nil }
            self =
                z > Self.hrvZInRangeUpTo + Self.boundaryTolerance
                ? .watch
                : Self.atLeast(z, inRange: Self.hrvZInRangeFrom, watch: Self.hrvZWatchFrom)
        case (.restingHR, let median?):
            self = Self.risingFrom(
                value - median,
                watch: Self.restingHRWatchFrom,
                outOfRange: Self.restingHROutOfRangeFrom
            )
        case (.respiratoryRate, _):
            guard let z = Self.z(metric, value: value, baseline: baseline) else { return nil }
            self = Self.atMost(
                abs(z),
                inRange: Self.respiratoryRateZInRangeUpTo,
                watch: Self.respiratoryRateZWatchUpTo
            )
        case (.skinTemperature, let median?):
            self = Self.atMost(
                abs(value - median),
                inRange: Self.skinTemperatureInRangeUpTo,
                watch: Self.skinTemperatureWatchUpTo
            )
        default:
            return nil
        }
    }

    /// The values around `baseline` that are In range, for the Nightly Metric popup's band (spec
    /// 004, In range band); nil on a side with no limit. Both nil for SpO2, which has no Baseline,
    /// for HRV against a Baseline of 0 or less, while the Baseline is Calibrating, and for an HRV
    /// or respiratory rate Baseline with no Spread.
    static func inRangeLimits(_ metric: NightlyMetric, baseline: Baseline)
        -> (low: Double?, high: Double?)
    {
        guard let median = baseline.median else { return (nil, nil) }
        return switch (metric, baseline.spread) {
        case (.hrv, let spread?) where median > 0:
            (median * exp(hrvZInRangeFrom * spread), median * exp(hrvZInRangeUpTo * spread))
        case (.restingHR, _):
            (nil, median + restingHRWatchFrom)
        case (.respiratoryRate, let spread?):
            (
                median - respiratoryRateZInRangeUpTo * spread,
                median + respiratoryRateZInRangeUpTo * spread
            )
        case (.skinTemperature, _):
            (median - skinTemperatureInRangeUpTo, median + skinTemperatureInRangeUpTo)
        case (.hrv, _), (.respiratoryRate, nil), (.spo2, _):
            (nil, nil)
        }
    }

    /// Where `value` sits on its tile's gauge, 0 (bottom) to 1 (top), clamped (spec 004, Gauge):
    /// the Baseline at 0.5 and, on each side, where Watch turns into Out of range at the ends, or
    /// for SpO2 a fixed scale. Resting HR's ends are symmetric though only a rise changes its Zone.
    /// Nil when the metric needs a Baseline and has none, HRV's Baseline is 0 or less, or an HRV
    /// or respiratory rate Baseline has no Spread.
    static func gaugePosition(_ metric: NightlyMetric, value: Double, baseline: Baseline?)
        -> Double?
    {
        let position: Double
        switch (metric, baseline?.median) {
        case (.spo2, _):
            position = (value - spo2GaugeBottom) / (spo2GaugeTop - spo2GaugeBottom)
        case (.hrv, _):
            guard let z = z(metric, value: value, baseline: baseline) else { return nil }
            position = centred(z, limit: -hrvZWatchFrom)
        case (.restingHR, let median?):
            position = centred(value - median, limit: restingHROutOfRangeFrom)
        case (.respiratoryRate, _):
            guard let z = z(metric, value: value, baseline: baseline) else { return nil }
            position = centred(z, limit: respiratoryRateZWatchUpTo)
        case (.skinTemperature, let median?):
            position = centred(value - median, limit: skinTemperatureWatchUpTo)
        default:
            return nil
        }
        // A value that gives no real position (e.g. NaN) shows an empty gauge.
        return position.isFinite ? min(max(position, 0), 1) : nil
    }

    /// How far `value` sits from its Baseline in Spreads (spec 004, Zones): on ln(RMSSD) for HRV.
    /// Nil for metrics with no Spread, while Calibrating, and for HRV against a Baseline of 0 or
    /// less, which gives no meaningful change.
    private static func z(_ metric: NightlyMetric, value: Double, baseline: Baseline?) -> Double? {
        guard let median = baseline?.median, let spread = baseline?.spread else { return nil }
        switch metric {
        case .hrv:
            return median > 0 ? (log(value) - log(median)) / spread : nil
        case .respiratoryRate:
            return (value - median) / spread
        case .restingHR, .skinTemperature, .spo2:
            return nil
        }
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

    /// For measures where only a rise is a warning, and a value on a cut-off already counts as
    /// the Zone above it (spec 004, Zones).
    private static func risingFrom(_ measure: Double, watch: Double, outOfRange: Double) -> Zone {
        let tolerance = boundaryTolerance
        return measure >= outOfRange - tolerance
            ? .outOfRange : measure >= watch - tolerance ? .watch : .inRange
    }
}
