import Foundation

/// The Readiness popup (spec 002, Popups): Readiness with HRV and Resting HR against their
/// Baselines and Sleep Score, or instead, while Calibrating, why there's no Readiness yet.
public struct ReadinessPopup: Equatable, Sendable {
    /// As on the ring: the number, or "n/4" while Calibrating.
    public let readinessText: String
    public let band: ReadinessBand?
    /// HRV, then Resting HR; none while Calibrating.
    public let rows: [ReadinessPopupRow]
    /// Nil while Calibrating.
    public let sleepScoreText: String?
    /// "Baseline: your last N Nights"; nil while Calibrating.
    public let baselineNote: String?
    /// Why there's no Readiness yet; nil once there's a Baseline.
    public let calibratingText: String?
}

/// One metric in the Readiness popup.
public struct ReadinessPopupRow: Equatable, Sendable {
    public let metric: NightlyMetric
    /// As on the tile.
    public let valueText: String
    /// The Baseline as a whole number with its unit, e.g. "60 ms"; "Calibrating" while it is.
    public let baselineText: String
    /// As on the tile.
    public let differenceText: String

    init(_ tile: MetricTile) {
        metric = tile.metric
        valueText = tile.valueText
        baselineText = tile.baseline.map { formattedValue(of: tile.metric, $0) } ?? "Calibrating"
        differenceText = tile.differenceText
    }
}

/// The Sleep popup (spec 002, Popups).
public struct SleepPopup: Equatable, Sendable {
    public let sleepScoreText: String
    /// Start–end in local time, e.g. "22:30–07:05"; "—" if either is missing.
    public let timeInBedText: String
    /// e.g. "8h 35m"; "—" if missing.
    public let timeInBedDurationText: String
    public let sleepOnsetText: String
    public let finalWakeText: String
    public let timeAsleepText: String
    /// Minutes awake within the Sleep Period: Final Wake − Sleep Onset − Time Asleep, e.g.
    /// "32 min"; "—" if any is missing or it comes out negative.
    public let minutesAwakeText: String

    init(_ night: Night, sleepScoreText: String, timeZone: TimeZone) {
        self.sleepScoreText = sleepScoreText
        let timeInBed = night.timeInBedStart.flatMap { start in
            night.timeInBedEnd.map { (start: start, end: $0) }
        }
        timeInBedText =
            timeInBed.map {
                "\(clockText($0.start, in: timeZone))\u{2013}\(clockText($0.end, in: timeZone))"
            } ?? missingText
        timeInBedDurationText =
            timeInBed.map { durationText($0.end.timeIntervalSince($0.start)) } ?? missingText
        sleepOnsetText = night.sleepOnset.map { clockText($0, in: timeZone) } ?? missingText
        finalWakeText = night.finalWake.map { clockText($0, in: timeZone) } ?? missingText
        let timeAsleep = night.plausibleTimeAsleep
        timeAsleepText = timeAsleep.map(durationText) ?? missingText
        minutesAwakeText =
            if let onset = night.sleepOnset, let wake = night.finalWake, let timeAsleep,
                let minutes = Int(
                    exactly: ((wake.timeIntervalSince(onset) - timeAsleep) / 60).rounded()
                ),
                minutes >= 0
            {
                "\(minutes) min"
            } else {
                missingText
            }
    }
}

/// The Nightly Metric popup (spec 002, Popups).
public struct MetricPopup: Equatable, Sendable {
    public let metric: NightlyMetric
    /// As on the tile.
    public let valueText: String
    /// As on the tile: the difference, or SpO2's level.
    public let differenceText: String
    public let zone: Zone?
    /// The Night shown and up to 13 earlier Nights, oldest first, without missing values.
    public let chart: [MetricPopupPoint]
    /// The 5 most recent of those, newest first.
    public let recent: [MetricPopupEntry]
    /// Nil while Calibrating, and always for SpO2.
    public let baseline: Double?
    /// The In range limits around the Baseline; nil on a side with no limit, and both nil
    /// without a Baseline.
    public let inRangeLow: Double?
    public let inRangeHigh: Double?

    /// How many Nights the chart covers, including the one shown (spec 002, Popups).
    static let chartNights = 14
    /// How many of them are listed (spec 002, Popups).
    static let listedNights = 5

    init(_ tile: MetricTile, for night: Night, among nights: [Night]) {
        metric = tile.metric
        valueText = tile.valueText
        differenceText = tile.differenceText
        zone = tile.zone
        chart = recentNights(Self.chartNights, upTo: night, among: nights).compactMap { night in
            night.value(of: tile.metric).map { MetricPopupPoint(day: night.day, value: $0) }
        }
        recent = chart.reversed().prefix(Self.listedNights).map {
            MetricPopupEntry(
                dayText: $0.day.text,
                valueText: formattedValue(of: tile.metric, $0.value)
            )
        }
        baseline = tile.baseline
        let limits = tile.comparedBaseline.map { Zone.inRangeLimits(tile.metric, baseline: $0) }
        inRangeLow = limits?.low
        inRangeHigh = limits?.high
    }
}

/// One Night's value on the Nightly Metric popup's chart.
public struct MetricPopupPoint: Equatable, Sendable {
    public let day: Day
    public let value: Double
}

/// One Night in the Nightly Metric popup's list.
public struct MetricPopupEntry: Equatable, Sendable {
    /// e.g. "Sun 1 Nov".
    public let dayText: String
    /// As on the tile, e.g. "62 ms".
    public let valueText: String
}
