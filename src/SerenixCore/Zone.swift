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
    /// Sleeping HR above Baseline, bpm, up only (spec 004): Watch from +3, Out of range from +5.
    /// A lower Sleeping HR is never a warning. The Watch cut-off is also the In range row's upper limit (spec 011).
    private static let sleepingHRWatchFrom = 3.0
    private static let sleepingHROutOfRangeFrom = 5.0
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
        case (.sleepingHR, let median?):
            self = Self.risingFrom(
                value - median,
                watch: Self.sleepingHRWatchFrom,
                outOfRange: Self.sleepingHROutOfRangeFrom
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

    /// Where each Zone ends (spec 011, Your Zones): the In range limits, and where Watch turns into
    /// Out of range, nil on a side with no limit. Around `baseline`, or for SpO2 its fixed
    /// levels. Nil when there's no Baseline to measure from: Calibrating, HRV's Baseline 0 or
    /// less, or an HRV or respiratory rate Baseline with no Spread.
    static func edges(_ metric: NightlyMetric, baseline: Baseline?) -> ZoneEdges? {
        if metric == .spo2 {
            return ZoneEdges(inRange: (spo2InRangeFrom, nil), watch: (spo2WatchFrom, nil))
        }
        guard let baseline, let median = baseline.median else { return nil }
        switch (metric, baseline.spread) {
        case (.hrv, let spread?) where median > 0:
            let edge = { (z: Double) in median * exp(z * spread) }
            return ZoneEdges(
                inRange: (edge(hrvZInRangeFrom), edge(hrvZInRangeUpTo)),
                watch: (edge(hrvZWatchFrom), nil)
            )
        case (.respiratoryRate, let spread?):
            let inRange = respiratoryRateZInRangeUpTo * spread
            let watch = respiratoryRateZWatchUpTo * spread
            return ZoneEdges(
                inRange: (median - inRange, median + inRange),
                watch: (median - watch, median + watch)
            )
        case (.sleepingHR, _):
            return ZoneEdges(
                inRange: (nil, median + sleepingHRWatchFrom),
                watch: (nil, median + sleepingHROutOfRangeFrom)
            )
        case (.skinTemperature, _):
            return ZoneEdges(
                inRange: (median - skinTemperatureInRangeUpTo, median + skinTemperatureInRangeUpTo),
                watch: (median - skinTemperatureWatchUpTo, median + skinTemperatureWatchUpTo)
            )
        case (.hrv, _), (.respiratoryRate, nil), (.spo2, _):
            return nil
        }
    }

    /// Where `value` sits on its tile's gauge, 0 (bottom) to 1 (top), clamped (spec 004, Gauge):
    /// the Baseline at 0.5 and, on each side, where Watch turns into Out of range at the ends, or
    /// for SpO2 a fixed scale. Sleeping HR's ends are symmetric though only a rise changes its
    /// Zone. Nil when the metric needs a Baseline and has none, HRV's Baseline is 0 or less, or an
    /// HRV or respiratory rate Baseline has no Spread.
    static func gaugePosition(_ metric: NightlyMetric, value: Double, baseline: Baseline?)
        -> Double?
    {
        position(metric, value: value, baseline: baseline, reach: 1)
    }

    /// Where `value` sits on the Nightly Metric popup's Zone scale, 0 (left) to 1 (right),
    /// clamped (spec 011, Zone scale): as on the gauge, but each end `scaleReach` times as far
    /// from the Baseline, so Out of range has room. SpO2's scale is the gauge's.
    static func scalePosition(_ metric: NightlyMetric, value: Double, baseline: Baseline?)
        -> Double?
    {
        position(metric, value: value, baseline: baseline, reach: scaleReach)
    }

    /// The Zone scale's segments, left to right (spec 011, Zone scale): fixed per metric, with
    /// each cut-off placed as a value on it would be.
    static func scaleSegments(_ metric: NightlyMetric) -> [MetricPopupScaleSegment] {
        // The cut-offs in the measure the scale is centred on: z, or the difference from Baseline.
        let (zones, cutOffs): ([Zone], [Double]) =
            switch metric {
            case .hrv:
                (
                    [.outOfRange, .watch, .inRange, .watch],
                    [hrvZWatchFrom, hrvZInRangeFrom, hrvZInRangeUpTo]
                )
            case .respiratoryRate:
                (
                    [.outOfRange, .watch, .inRange, .watch, .outOfRange],
                    [
                        -respiratoryRateZWatchUpTo, -respiratoryRateZInRangeUpTo,
                        respiratoryRateZInRangeUpTo, respiratoryRateZWatchUpTo,
                    ]
                )
            case .sleepingHR:
                ([.inRange, .watch, .outOfRange], [sleepingHRWatchFrom, sleepingHROutOfRangeFrom])
            case .skinTemperature:
                (
                    [.outOfRange, .watch, .inRange, .watch, .outOfRange],
                    [
                        -skinTemperatureWatchUpTo, -skinTemperatureInRangeUpTo,
                        skinTemperatureInRangeUpTo, skinTemperatureWatchUpTo,
                    ]
                )
            case .spo2:
                ([.outOfRange, .watch, .inRange], [spo2WatchFrom, spo2InRangeFrom])
            }
        let cuts = cutOffs.map { cutOff in
            gaugeLimit(metric).map { centred(cutOff, limit: $0 * scaleReach) }
                ?? spo2Position(cutOff)
        }
        let edges = [0] + cuts + [1]
        return zones.indices.map {
            MetricPopupScaleSegment(zone: zones[$0], from: edges[$0], to: edges[$0 + 1])
        }
    }

    /// How much farther from the Baseline the Zone scale's ends are than the gauge's, which end
    /// where Watch turns into Out of range (spec 011, Zone scale): 1.5×, so Out of range shows.
    private static let scaleReach = 1.5

    /// The gauge's or the scale's position, with each end `reach` times the gauge's limit.
    private static func position(
        _ metric: NightlyMetric,
        value: Double,
        baseline: Baseline?,
        reach: Double
    ) -> Double? {
        let measure: Double
        switch (metric, baseline?.median) {
        case (.spo2, _):
            measure = value
        case (.hrv, _), (.respiratoryRate, _):
            guard let z = Self.z(metric, value: value, baseline: baseline) else { return nil }
            measure = z
        case (.sleepingHR, let median?), (.skinTemperature, let median?):
            measure = value - median
        default:
            return nil
        }
        let position =
            gaugeLimit(metric).map { centred(measure, limit: $0 * reach) } ?? spo2Position(measure)
        // A value that gives no real position (e.g. NaN) shows an empty gauge.
        return position.isFinite ? min(max(position, 0), 1) : nil
    }

    /// How far either side of the Baseline the gauge ends: where Watch turns into Out of range,
    /// in z for HRV and respiratory rate, bpm for Sleeping HR, °C for skin temperature. Nil for
    /// SpO2, whose gauge is on fixed levels.
    private static func gaugeLimit(_ metric: NightlyMetric) -> Double? {
        switch metric {
        case .hrv: -hrvZWatchFrom
        case .respiratoryRate: respiratoryRateZWatchUpTo
        case .sleepingHR: sleepingHROutOfRangeFrom
        case .skinTemperature: skinTemperatureWatchUpTo
        case .spo2: nil
        }
    }

    /// SpO2 on its fixed scale, 0 at the bottom and 1 at the top; unclamped.
    private static func spo2Position(_ value: Double) -> Double {
        (value - spo2GaugeBottom) / (spo2GaugeTop - spo2GaugeBottom)
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
        case .sleepingHR, .skinTemperature, .spo2:
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

/// Where a metric's Zones end (spec 011, Your Zones); nil on a side with no limit.
struct ZoneEdges {
    /// In range lies between these.
    let inRange: (low: Double?, high: Double?)
    /// Watch lies between these and In range; Out of range lies beyond them.
    let watch: (low: Double?, high: Double?)
}
