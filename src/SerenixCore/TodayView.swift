import Foundation

/// Everything the Today screen shows for one Day (spec 002). It decides; the shell draws.
public struct TodayView: Equatable, Sendable {
    /// The week strip holding the Day shown.
    public let weekStrip: WeekStrip
    /// The Days the date picker offers: from the Day of the earliest Night to today, or just
    /// today with no Nights.
    public let pickerRange: ClosedRange<Day>
    /// Midday on the first and last Days of `pickerRange`, and on the Day shown, for the shell's
    /// date picker.
    public let pickerDates: ClosedRange<Date>
    public let shownDate: Date
    /// e.g. "Good morning!", by the time now, on every Day shown.
    public let greeting: String
    /// The Profile name under the greeting; nil with no name.
    public let greetingName: String?
    /// The first letter of the Profile name, upper-cased; nil with no name.
    public let avatarLetter: String?
    /// The profile menu header's name: the Profile name, or "Add your name".
    public let menuName: String
    /// "No Night yet" on today or "No Night recorded" on an earlier Day; nil when the Day has a
    /// Night. Another Day's Night is never shown in its place.
    public let noNightMessage: String?
    /// The Night's Readiness, or "—" when it's missing or there's no Night.
    public let readinessText: String
    /// Nil whenever Readiness is missing.
    public let readinessBand: ReadinessBand?
    /// The advice on the Readiness message card; nil while Calibrating or missing.
    public let readinessAdvice: String?
    /// The Night's Sleep Score, or "—".
    public let sleepScoreText: String
    /// "Load" on every Day, or "Add your age" when Load is missing for want of a Max HR (spec 005,
    /// Add your age).
    public let loadLabel: String
    public let loadText: String
    /// Whether tapping the Load ring opens the profile menu: only while it asks for the age.
    public let loadOpensProfileMenu: Bool
    /// How far each ring fills, 0 to 1: its 0–100 score out of 100 (ADR 0005), or 0 when the
    /// score is missing.
    public let readinessFill: Double
    public let sleepScoreFill: Double
    public let loadFill: Double
    /// Nil when there is nothing to say.
    public let syncPill: SyncPill?
    /// Whether the profile menu's Sync now reads Retry sync: after a paused or failed sync.
    public let syncOffersRetry: Bool
    /// Nil on a Day without a Night.
    public let vsBaseline: VsBaseline?
    /// Nil on a Day without a Night.
    public let readinessPopup: ReadinessPopup?
    /// Nil on a Day without a Night.
    public let sleepPopup: SleepPopup?
    /// The Load popup (spec 006); nil when the Load ring opens the profile menu instead.
    public let loadPopup: LoadPopup?
    private let metricPopups: [MetricPopup]
    /// "Last night" on today, else the Day's date.
    public let tilesHeading: String
    /// Nil on a Day without a Night.
    public let timeAsleepTile: TimeAsleepTile?
    /// The Nightly Metric tiles in their order; none on a Day without a Night.
    public let tiles: [MetricTile]
    /// The Day's Resting HR tile (spec 007); nil on a Day without a Night, which shows no tiles.
    public let restingHRTile: RestingHRTile?
    /// The Resting HR popup (spec 011), opened from its tile; nil when there's no tile.
    public let restingHRPopup: RestingHRPopup?
    /// The 2-column grid under Time Asleep: Sleeping HR, Resting HR, then the other Nightly
    /// Metrics (spec 007, Today screen); none on a Day without a Night.
    public let gridTiles: [TodayTile]
    /// The Story layout's timeline for the Day shown (spec 013).
    public let story: TodayStory

    public init(
        nights: [Night],
        dayLoads: [DayLoad],
        showing day: Day,
        now: Date,
        timeZone: TimeZone,
        sync: SyncStatus,
        profileName: String? = nil,
        birthYear: Int? = nil,
        lastSyncEnded: Date? = nil
    ) {
        let today = Day(containing: now, in: timeZone)
        let isToday = day == today
        pickerRange = WeekStrip.earliest(among: nights, today: today)...today
        pickerDates =
            pickerRange.lowerBound.midday(
                in: timeZone
            )...pickerRange.upperBound.midday(in: timeZone)
        shownDate = day.midday(in: timeZone)
        weekStrip = WeekStrip(
            showing: day,
            today: today,
            earliest: pickerRange.lowerBound,
            nights: Set(nights.map(\.day))
        )
        let profile = Profile(name: profileName)
        greeting = profile.greeting(at: now, in: timeZone)
        greetingName = profile.name
        avatarLetter = profile.avatarLetter
        menuName = profile.menuName

        let night = nights.first { $0.day == day }
        noNightMessage = night != nil ? nil : Self.noNightMessage(isToday: isToday)

        // Worked out each time, never stored, so it follows the Nights and Days (spec 008).
        let nightReadiness = NightReadiness(
            for: day,
            among: nights,
            dayLoads: dayLoads,
            birthYear: birthYear
        )
        let readinessBaselines = nightReadiness.baselines
        let calibratingNightsSoFar = nightReadiness.calibratingNightsSoFar
        let nightsForBaseline = Baseline.minEarlierNights + 1
        let previousDayLoad = nightReadiness.previousDayLoad
        let previousDayTypicalLoad = nightReadiness.previousDayTypicalLoad
        let sleepNeed = nightReadiness.sleepNeed
        if let calibratingNightsSoFar {
            readinessText = "\(calibratingNightsSoFar)/\(nightsForBaseline)"
            readinessBand = nil
            readinessFill = 0
        } else {
            let readiness = nightReadiness.score
            readinessText = scoreText(readiness)
            readinessBand = readiness.map(ReadinessBand.init)
            readinessFill = ringFill(readiness)
        }
        // Worked out each time, never stored, so it follows the Nights (spec 010).
        let sleepScore = night.flatMap {
            SleepScore(of: $0, among: nights, sleepNeed: sleepNeed.sleepNeed, timeZone: timeZone)
        }
        sleepScoreText = scoreText(sleepScore?.score)
        sleepScoreFill = ringFill(sleepScore?.score)

        let dayLoad = dayLoads.first { $0.day == day }
        loadOpensProfileMenu = dayLoad?.missingReason == .noMaxHR
        loadLabel = loadOpensProfileMenu ? "Add your age" : "Load"
        loadText = scoreText(dayLoad?.load)
        loadFill = ringFill(dayLoad?.load)
        loadPopup =
            loadOpensProfileMenu
            ? nil
            : LoadPopup(
                dayLoad,
                loadText: loadText,
                for: day,
                isToday: isToday,
                among: dayLoads,
                lastSyncEnded: lastSyncEnded,
                timeZone: timeZone
            )

        let syncPill = SyncPill(sync)
        self.syncPill = syncPill
        syncOffersRetry = syncPill?.canBeDismissed ?? false

        tilesHeading = isToday ? "Last night" : day.text
        timeAsleepTile = night.map { TimeAsleepTile(for: $0, timeZone: timeZone) }
        let tiles =
            night.map { night in
                NightlyMetric.tileOrder.map { MetricTile($0, for: night, among: nights) }
            } ?? []
        self.tiles = tiles
        // Resting HR belongs to the Day (spec 007): with a Night its tile always shows ("—" when
        // missing); without one, only when the Day has a Resting HR (spec 002, No Night).
        let restingHRTile =
            night != nil || dayLoad?.restingHR != nil
            ? RestingHRTile(restingHR: dayLoad?.restingHR, isToday: isToday) : nil
        self.restingHRTile = restingHRTile
        restingHRPopup = restingHRTile.map { _ in
            RestingHRPopup(
                restingHR: dayLoad?.restingHR,
                for: day,
                isToday: isToday,
                among: dayLoads
            )
        }
        gridTiles = tiles.flatMap { tile -> [TodayTile] in
            guard tile.metric == .sleepingHR, let restingHRTile else { return [.metric(tile)] }
            return [.metric(tile), .restingHR(restingHRTile)]
        }

        readinessAdvice = readinessBand.map { band in
            ReadinessAdvice.text(
                for: band,
                yesterdayLoad: previousDayLoad,
                hrv: tiles.first { $0.metric == .hrv },
                sleepingHR: tiles.first { $0.metric == .sleepingHR }
            )
        }
        story = TodayStory(
            night: night,
            noNightMessage: noNightMessage,
            tiles: tiles,
            readiness: StoryReadiness(
                text: readinessText,
                band: readinessBand,
                isCalibrating: calibratingNightsSoFar != nil,
                advice: readinessAdvice
            ),
            loadText: loadText,
            load: dayLoad?.load,
            typicalLoad: typicalLoad(for: day, among: dayLoads),
            isToday: isToday,
            timeZone: timeZone
        )

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

        // Readiness's inputs in spec 008's order: HRV, Sleeping HR, Time Asleep, Yesterday's Load.
        var inputRows: [Readiness.Input: ReadinessPopupRow] = [
            .timeAsleep: ReadinessPopupRow(
                timeAsleep: night?.plausibleTimeAsleep,
                sleepNeed: sleepNeed.sleepNeed
            ),
            .previousDayLoad: ReadinessPopupRow(
                previousDayLoad: previousDayLoad,
                typical: previousDayTypicalLoad
            ),
        ]
        inputRows[.hrv] = tiles.first { $0.metric == .hrv }.map(ReadinessPopupRow.init)
        inputRows[.sleepingHR] = tiles.first { $0.metric == .sleepingHR }.map(
            ReadinessPopupRow.init
        )
        let why = nightReadiness.breakdown.map {
            ReadinessWhyRow.list(
                $0,
                rows: inputRows,
                previousDayLoad: previousDayLoad,
                typicalLoad: previousDayTypicalLoad
            )
        }
        // Spec 002's Calibrating explanation: the popup's verdict while Calibrating (spec 012).
        let calibratingExplanation = calibratingNightsSoFar.map {
            "Readiness needs \(nightsForBaseline) Nights to form your Baseline. "
                + "You have \($0) so far."
        }
        // Readiness is missing when the Night has no HRV, an HRV of 0 counting as none (spec 008).
        let hasHRV = (night?.value(of: .hrv)).map { $0 > 0 } ?? false
        let missingHRVVerdict = hasHRV ? nil : "No HRV for this Night, so there's no Readiness."
        // The band scale's marker and "usual 70" tick: only with a Readiness, none while
        // Calibrating or missing (spec 012).
        let readinessScaleMarker = nightReadiness.score.map(ringFill)
        let readinessUsualTick =
            nightReadiness.score == nil ? nil : ringFill(Readiness.usualScore)
        // The band scale's segments, the same on every Night (spec 012).
        let readinessScale = ReadinessBand.lowestFirst.map { band in
            ReadinessScaleSegment(band: band, from: band.stretch.from, to: band.stretch.to)
        }
        // Your week: each Day's Readiness against its own Baselines, as if it were shown (spec
        // 012). The Day shown reuses its own; worked out each time, never stored.
        let readinessWeek = (-(Self.readinessWeekDays - 1)...0).map { offset in
            let weekDay = day.adding(days: offset)
            let score =
                offset == 0
                ? nightReadiness.score
                : NightReadiness(
                    for: weekDay,
                    among: nights,
                    dayLoads: dayLoads,
                    birthYear: birthYear
                ).score
            return ReadinessWeekBar(
                weekdayText: weekDay.weekdayName,
                readinessText: scoreText(score),
                band: score.map(ReadinessBand.init),
                fill: ringFill(score),
                isDayShown: offset == 0
            )
        }
        readinessPopup =
            if readinessBaselines != nil {
                if calibratingExplanation != nil {
                    ReadinessPopup(
                        readinessText: readinessText,
                        band: nil,
                        // Spec 012: Sleep Score shows while Calibrating too.
                        sleepScoreText: sleepScoreText,
                        verdictText: calibratingExplanation,
                        whyRows: [],
                        week: readinessWeek,
                        scaleSegments: readinessScale,
                        scaleMarker: readinessScaleMarker,
                        usualTick: readinessUsualTick
                    )
                } else {
                    ReadinessPopup(
                        readinessText: readinessText,
                        band: readinessBand,
                        sleepScoreText: sleepScoreText,
                        verdictText: why?.verdict ?? missingHRVVerdict,
                        whyRows: why?.rows ?? [],
                        week: readinessWeek,
                        scaleSegments: readinessScale,
                        scaleMarker: readinessScaleMarker,
                        usualTick: readinessUsualTick
                    )
                }
            } else {
                nil
            }
        sleepPopup =
            if let night {
                SleepPopup(
                    night,
                    sleepNeed: sleepNeed,
                    sleepScore: sleepScore,
                    timeZone: timeZone
                )
            } else {
                nil
            }
        metricPopups =
            night.map { night in
                tiles.map { MetricPopup($0, for: night, among: nights) }
            } ?? []
    }

    /// Days in the Readiness popup's Your week, the Day shown included (spec 012).
    private static let readinessWeekDays = 7

    /// A Nightly Metric's popup; nil on a Day without a Night.
    public func metricPopup(_ metric: NightlyMetric) -> MetricPopup? {
        metricPopups.first { $0.metric == metric }
    }

    /// A Nightly Metric's tile; nil on a Day without a Night.
    public func tile(_ metric: NightlyMetric) -> MetricTile? {
        tiles.first { $0.metric == metric }
    }

    /// What a Day without a Night says (spec 002), on the Today and Sleep tabs alike.
    static func noNightMessage(isToday: Bool) -> String {
        isToday ? "No Night yet" : "No Night recorded"
    }
}

/// How a missing value reads (spec 002, Missing values).
let missingText = "—"

/// A 0–100 score as a whole number, or "—" when it's missing.
func scoreText(_ score: Int?) -> String {
    score.map(String.init) ?? missingText
}

/// A 0–100 score as a ring's fill, 0 to 1; an empty ring when it's missing.
func ringFill(_ score: Int?) -> Double {
    score.map { Double($0) / 100 } ?? 0
}
