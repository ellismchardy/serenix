import Foundation

/// One Night's Baseline for one Nightly Metric (GLOSSARY, specs 002 and 004): the median of that
/// metric over the most recent earlier Nights that have it, and its Spread. The Night itself is
/// never part of it.
struct Baseline: Equatable, Sendable {
    /// How many earlier Nights have a value for the metric, all of them, not only those used.
    let earlierNights: Int
    /// Nil while the Baseline is Calibrating.
    let median: Double?
    /// How much the metric usually varies from Night to Night (GLOSSARY, Spread), on ln(RMSSD)
    /// for HRV. Nil while Calibrating, and for metrics whose Spread isn't worked out yet.
    let spread: Double?

    /// At most this many of the most recent earlier Nights count (spec 004, Baseline).
    static let maxNights = 14
    /// Calibrating until this many earlier Nights have a value, so the 4th Night with one is the
    /// first with a Baseline (spec 004; docs/architecture.md, "calibrating until 4 Nights").
    static let minEarlierNights = 3
    /// HRV's typical Spread, on ln(RMSSD) (spec 004, Spread). Assumption from issue #14 and
    /// docs/research/nightly-metric-deviation.md: tune with real Nights.
    static let hrvTypicalSpread = 0.15
    /// Respiratory rate's typical Spread, br/min (spec 004, Spread). Assumption from issue #14
    /// and docs/research/nightly-metric-deviation.md: tune with real Nights.
    static let respiratoryRateTypicalSpread = 0.5
    /// HRV's smallest Spread, on ln(RMSSD) (spec 004, Spread). Assumption from issue #14: tune
    /// with real Nights.
    static let hrvSpreadFloor = 0.10
    /// Respiratory rate's smallest Spread, br/min (spec 004, Spread). Assumption from issue #14:
    /// tune with real Nights.
    static let respiratoryRateSpreadFloor = 0.3
    /// From this many earlier Nights with a value, the Spread is measured from them instead of
    /// the typical value (spec 004, Spread; issue #14).
    static let minEarlierNightsForMeasuredSpread = 7
    /// Scales a median absolute deviation to estimate a standard deviation for normally
    /// distributed values (spec 004, Spread). Unitless: 1 / Φ⁻¹(0.75), the standard
    /// normal-consistency constant.
    static let madScale = 1.4826

    init(_ metric: NightlyMetric, for night: Night, among nights: [Night]) {
        // Newest first; missing values are skipped, never counted as 0.
        let earlier =
            nights
            .filter { $0.day < night.day }
            .sorted { $0.day > $1.day }
            .compactMap { $0.value(of: metric) }
        earlierNights = earlier.count
        let used = Array(earlier.prefix(Self.maxNights))
        let median = earlier.count < Self.minEarlierNights ? nil : SerenixCore.median(of: used)
        self.median = median
        spread = median.flatMap { median in
            Self.spread(of: metric, over: used, around: median, earlierNights: earlier.count)
        }
    }

    /// The Spread over the Nights the median used (spec 004, Spread): the typical value until
    /// enough earlier Nights have the metric, then their scaled MAD, never below the floor. HRV's
    /// is on ln(RMSSD). Nil for metrics whose Spread isn't worked out yet.
    private static func spread(
        of metric: NightlyMetric,
        over values: [Double],
        around median: Double,
        earlierNights: Int
    ) -> Double? {
        let typical: Double
        let minSpread: Double
        let scaled: [Double]
        let centre: Double
        switch metric {
        case .hrv:
            (typical, minSpread) = (hrvTypicalSpread, hrvSpreadFloor)
            (scaled, centre) = (values.map { log($0) }, log(median))
        case .respiratoryRate:
            (typical, minSpread) = (respiratoryRateTypicalSpread, respiratoryRateSpreadFloor)
            (scaled, centre) = (values, median)
        case .restingHR, .skinTemperature, .spo2:
            return nil
        }
        guard earlierNights >= minEarlierNightsForMeasuredSpread else { return typical }
        let mad = SerenixCore.median(of: scaled.map { abs($0 - centre) })
        return max(madScale * mad, minSpread)
    }

    var isCalibrating: Bool { median == nil }
}
