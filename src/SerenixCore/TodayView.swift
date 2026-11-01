import Foundation

/// Everything the Today screen shows for one Day (spec 002). It decides; the shell draws.
public struct TodayView: Equatable, Sendable {
    /// The Day's date, e.g. "Sun 1 Nov".
    public let title: String
    /// The Days the date picker offers: from the Day of the earliest Night to today, or just
    /// today with no Nights.
    public let pickerRange: ClosedRange<Day>
    /// Midday on the first and last Days of `pickerRange`, and on the Day shown, for the shell's
    /// date picker.
    public let pickerDates: ClosedRange<Date>
    public let shownDate: Date
    /// Whether the Today pill shows: on any Day other than today.
    public let showsTodayPill: Bool
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
    /// Nil on a Day without a Night.
    public let readinessPopup: ReadinessPopup?
    /// Nil on a Day without a Night.
    public let sleepPopup: SleepPopup?
    private let metricPopups: [MetricPopup]
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
        title = day.text
        let earliestNight = nights.map(\.day).min()
        pickerRange = min(earliestNight ?? today, today)...today
        pickerDates =
            pickerRange.lowerBound.midday(
                in: timeZone
            )...pickerRange.upperBound.midday(in: timeZone)
        shownDate = day.midday(in: timeZone)
        showsTodayPill = !isToday

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

        readinessPopup =
            if let readinessBaselines {
                if let calibratingNightsSoFar {
                    ReadinessPopup(
                        readinessText: readinessText,
                        band: nil,
                        rows: [],
                        sleepScoreText: nil,
                        baselineNote: nil,
                        calibratingText:
                            "Readiness needs \(nightsForBaseline) Nights to form your Baseline. "
                            + "You have \(calibratingNightsSoFar) so far."
                    )
                } else {
                    ReadinessPopup(
                        readinessText: readinessText,
                        band: readinessBand,
                        rows: VsBaseline.metrics.compactMap { metric in
                            tiles.first { $0.metric == metric }.map(ReadinessPopupRow.init)
                        },
                        sleepScoreText: sleepScoreText,
                        baselineNote:
                            "Baseline: your last \(Self.baselineNights(readinessBaselines)) Nights",
                        calibratingText: nil
                    )
                }
            } else {
                nil
            }
        sleepPopup =
            if let night {
                SleepPopup(night, sleepScoreText: sleepScoreText, timeZone: timeZone)
            } else {
                nil
            }
        metricPopups =
            night.map { night in
                tiles.map { MetricPopup($0, for: night, among: nights) }
            } ?? []
    }

    /// How many Nights Readiness's Baselines are taken over: the fewer of HRV's and Resting HR's,
    /// at most `Baseline.maxNights`.
    private static func baselineNights(_ baselines: (hrv: Baseline, restingHR: Baseline)) -> Int {
        min(Baseline.maxNights, baselines.hrv.earlierNights, baselines.restingHR.earlierNights)
    }

    /// A Nightly Metric's popup; nil on a Day without a Night.
    public func metricPopup(_ metric: NightlyMetric) -> MetricPopup? {
        metricPopups.first { $0.metric == metric }
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
