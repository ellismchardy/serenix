import Foundation

/// Everything the Today screen shows for one Day (spec 002). It decides; the shell draws.
public struct TodayView: Equatable, Sendable {
    /// "Today" on today, else the Day's date, e.g. "Sat 31 Oct".
    public let title: String
    /// The date on today, else "Night".
    public let subtitle: String
    /// Where ‹ goes; nil when it's disabled, on the Day of the earliest Night.
    public let earlierDay: Day?
    /// Where › goes; nil when it's disabled, on today.
    public let laterDay: Day?
    /// "No Night yet" on today or "No Night recorded" on an earlier Day; nil when the Day has a
    /// Night. Another Day's Night is never shown in its place.
    public let noNightMessage: String?
    /// The Night's Readiness, or "—" when it's missing or there's no Night.
    public let readinessText: String
    /// Nil whenever Readiness is missing.
    public let readinessBand: ReadinessBand?
    /// The Night's Sleep Score, or "—".
    public let sleepScoreText: String
    public let loadLabel: String
    public let loadText: String
    /// How far each ring fills, 0 to 1: its 0–100 score out of 100 (ADR 0005), or 0 when the
    /// score is missing.
    public let readinessFill: Double
    public let sleepScoreFill: Double
    public let loadFill: Double
    public let syncPill: SyncPill
    /// Nil on a Day without a Night.
    public let vsBaseline: VsBaseline?
    /// "Last night" on today, else the Day's date.
    public let tilesHeading: String
    /// Nil on a Day without a Night.
    public let timeAsleepTile: TimeAsleepTile?
    /// The Nightly Metric tiles in their order; none on a Day without a Night.
    public let tiles: [MetricTile]

    public init(
        nights: [Night],
        dayLoads: [DayLoad],
        showing day: Day,
        now: Date,
        timeZone: TimeZone,
        sync: SyncStatus
    ) {
        let today = Day(containing: now, in: timeZone)
        let isToday = day == today
        title = isToday ? "Today" : day.text
        subtitle = isToday ? day.text : "Night"

        let earliestNight = nights.map(\.day).min()
        earlierDay = earliestNight.flatMap { $0 < day ? day.adding(days: -1) : nil }
        laterDay = day < today ? day.adding(days: 1) : nil

        let night = nights.first { $0.day == day }
        noNightMessage = night != nil ? nil : isToday ? "No Night yet" : "No Night recorded"

        // Readiness is Calibrating while either Baseline it's drawn from is (spec 002, Rings).
        // "n/4" counts the Nights so far, by the metric with the fewest.
        let readinessBaselines = night.map { night in
            (
                hrv: Baseline(.hrv, for: night, among: nights),
                restingHR: Baseline(.restingHR, for: night, among: nights)
            )
        }
        let calibratingNightsSoFar = readinessBaselines.flatMap { baselines in
            baselines.hrv.isCalibrating || baselines.restingHR.isCalibrating
                ? 1 + min(baselines.hrv.earlierNights, baselines.restingHR.earlierNights) : nil
        }
        let nightsForBaseline = Baseline.minEarlierNights + 1
        if let calibratingNightsSoFar {
            readinessText = "\(calibratingNightsSoFar)/\(nightsForBaseline)"
            readinessBand = nil
            readinessFill = 0
        } else {
            readinessText = scoreText(night?.readiness)
            readinessBand = night?.readiness.map(ReadinessBand.init)
            readinessFill = ringFill(night?.readiness)
        }
        sleepScoreText = scoreText(night?.sleepScore)
        sleepScoreFill = ringFill(night?.sleepScore)

        loadLabel = isToday ? "Load so far" : "Load"
        let load = dayLoads.first { $0.day == day }?.load
        loadText = scoreText(load)
        loadFill = ringFill(load)

        syncPill = SyncPill(sync, timeZone: timeZone)

        tilesHeading = isToday ? "Last night" : day.text
        timeAsleepTile = night.map { TimeAsleepTile(for: $0, among: nights, timeZone: timeZone) }
        let tiles =
            night.map { night in
                NightlyMetric.tileOrder.map { MetricTile($0, for: night, among: nights) }
            } ?? []
        self.tiles = tiles

        vsBaseline =
            if night == nil {
                nil
            } else if let calibratingNightsSoFar {
                .calibrating(
                    "Calibrating. Readiness starts once \(nightsForBaseline) Nights form your "
                        + "Baseline. \(nightsForBaseline - calibratingNightsSoFar) to go."
                )
            } else {
                .comparisons(
                    VsBaseline.metrics.compactMap { metric in
                        tiles.first { $0.metric == metric }.map(BaselineComparison.init)
                    }
                )
            }
    }

    /// A Nightly Metric's tile; nil on a Day without a Night.
    public func tile(_ metric: NightlyMetric) -> MetricTile? {
        tiles.first { $0.metric == metric }
    }
}

/// How a missing value reads (spec 002, Missing values).
let missingText = "—"

/// A 0–100 score as a whole number, or "—" when it's missing.
private func scoreText(_ score: Int?) -> String {
    score.map(String.init) ?? missingText
}

/// A 0–100 score as a ring's fill, 0 to 1; an empty ring when it's missing.
private func ringFill(_ score: Int?) -> Double {
    score.map { Double($0) / 100 } ?? 0
}
