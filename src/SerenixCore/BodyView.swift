import Foundation

/// Everything the Body tab's weight screen shows (spec 014), worked out from the stored
/// Weigh-ins each time, never stored (ADR 0008). The shell draws it.
public struct BodyView: Equatable, Sendable {
    /// One point per Day with a Weigh-in, oldest first.
    public let trend: [TrendPoint]
    /// The latest Trend Weight in kg; nil with no Weigh-ins.
    public let trendWeight: Double?
    /// How fast Trend Weight is changing, in kg a week (negative when falling); nil without a
    /// counted Weigh-in 7 or more Days before the latest, or across a restart (spec 014).
    public let weeklyRate: Double?
    /// The most recent Weigh-in by time.
    public let lastWeighIn: WeighIn?
    /// Every Weigh-in, newest first, for the Weigh-in list.
    public let weighIns: [WeighIn]
    /// Today, where every chart range ends.
    private let today: Day
    /// How weights are shown (the Profile's units).
    public let units: WeightUnits
    /// The current Weight Goal's cards; nil with no goal or no Trend Weight.
    public let goalCard: GoalCard?
    /// Where a new Weight Goal starts by default; nil with no Weigh-ins.
    public let newGoalStart: GoalStart?

    public init(
        weighIns: [WeighIn],
        units: WeightUnits = .kilograms,
        goal: WeightGoal? = nil,
        now: Date,
        timeZone: TimeZone
    ) {
        today = Day(containing: now, in: timeZone)
        self.units = units
        let newestFirst = weighIns.sorted { $0.time > $1.time }
        self.weighIns = newestFirst
        lastWeighIn = newestFirst.first
        trend = Self.trend(of: weighIns, in: timeZone)
        trendWeight = trend.last?.trendWeight
        weeklyRate = Self.weeklyRate(of: trend)
        let day = Day(containing: now, in: timeZone)
        newGoalStart = trendWeight.map { GoalStart(weight: $0, day: day) }
        if let goal {
            goalCard = Self.goalCard(
                for: goal,
                trend: trend,
                today: day,
                units: units,
                withEase: true
            )
        } else {
            goalCard = nil
        }
    }

    /// The goal's cards as of `today`, from the Trend Weight points up to it. With `withEase`,
    /// easing is offered when the badge was Off pace or Too fast on each of the last
    /// `GoalEase.offPaceDays` Days, each worked out the same way as of that Day (spec 014).
    static func goalCard(
        for goal: WeightGoal,
        trend allPoints: [TrendPoint],
        today: Day,
        units: WeightUnits,
        withEase: Bool
    ) -> GoalCard? {
        let points = Array(allPoints.prefix { $0.day <= today })  // the trend is sorted
        guard let latest = points.last?.trendWeight else { return nil }
        let weeklyRate = weeklyRate(of: points)
        // Counted from the latest restart: after a long gap, Trend Weight starts again and so
        // does Settling in, since the early water change applies again (issue #61).
        let lineStart = points.last(where: \.startsNewLine)?.day
        let weighInSpan = lineStart.map { $0.days(until: points.last?.day ?? $0) } ?? 0
        var ease: GoalEase?
        if withEase {
            // Each of the last 7 Days' status, today first, each from the Weigh-ins up to it.
            // Days before the goal was last changed don't count: each edit gets a full week.
            let statuses = (0..<GoalEase.offPaceDays).map { back -> PaceStatus? in
                let day = today.adding(days: -back)
                if let changed = goal.changedDay, day < changed { return nil }
                return goalCard(
                    for: goal,
                    trend: points,
                    today: day,
                    units: units,
                    withEase: false
                )?.status
            }
            let offPaceEveryDay = statuses.allSatisfy {
                $0 == .badge(.offPace) || $0 == .badge(.tooFast)
            }
            if offPaceEveryDay, case .badge(let badge)?? = statuses.first {
                ease = GoalEase.offer(
                    goal: goal,
                    badge: badge,
                    weeklyRate: weeklyRate,
                    trendWeight: latest,
                    today: today,
                    units: units
                )
            }
        }
        return GoalCard(
            goal: goal,
            trendWeight: latest,
            weeklyRate: weeklyRate,
            weighInSpan: weighInSpan,
            today: today,
            ease: ease
        )
    }

    /// The earliest Day and quick picks for a Pace by date to `goalWeight`; nil with no Trend
    /// Weight or when `goalWeight` is Trend Weight.
    public func goalDates(goalWeight: Double) -> GoalDates? {
        trendWeight.flatMap { GoalDates(trendWeight: $0, goalWeight: goalWeight, today: today) }
    }

    /// Why `goal` can't be saved now; nil when it can. Adds to `WeightGoal.refusal(units:)` the
    /// date rule, which needs Trend Weight: a date Pace can't be earlier than the 1%-a-week Day.
    public func goalRefusal(_ goal: WeightGoal) -> GoalRefusal? {
        if let refusal = goal.refusal(units: units) { return refusal }
        guard case .date(let day) = goal.pace else { return nil }
        guard let dates = goalDates(goalWeight: goal.goalWeight), day >= dates.earliest else {
            return .dateTooEarly
        }
        return nil
    }

    /// The rates a new Weight Goal's sheet offers in `direction`; empty with no Trend Weight.
    public func rateOptions(for direction: GoalDirection) -> [RateOption] {
        guard let trendWeight else { return [] }
        return RateOption.rates(for: direction, units: units).map {
            RateOption(kilogramsPerWeek: $0, trendWeight: trendWeight)
        }
    }

    /// The fewest Days Weekly Rate looks back over (issue #61: a week, since Trend Weight is
    /// already smoothed; 28 Days reacted about a month late).
    static let weeklyRateDays = 7

    /// The latest Trend Weight minus the Trend Weight at the last counted Weigh-in on or before
    /// `weeklyRateDays` earlier, per week (spec 014, Weekly Rate).
    static func weeklyRate(of trend: [TrendPoint]) -> Double? {
        guard let latest = trend.last else { return nil }
        let cutoff = latest.day.adding(days: -weeklyRateDays)
        guard let earlierIndex = trend.lastIndex(where: { $0.day <= cutoff }) else { return nil }
        let since = trend[(earlierIndex + 1)...]
        guard !since.contains(where: \.startsNewLine) else { return nil }
        let earlier = trend[earlierIndex]
        let days = Double(earlier.day.days(until: latest.day))
        return (latest.trendWeight - earlier.trendWeight) * 7 / days
    }

    /// The share of the gap between Trend Weight and a new Weigh-in that Trend Weight keeps over
    /// one Day, so one Day closes 0.1 of it: the Hacker's Diet step (issue #50,
    /// `docs/research/trend-weight-smoothing.md`). Over `Δd` Days the share closed is
    /// `1 − trendKeep^Δd`, so a gap counts as that many daily steps.
    static let trendKeep = 0.9

    /// The most Days between counted Weigh-ins that Trend Weight carries across; after a longer
    /// gap it restarts at the new Weigh-in (issue #50: after 14 Days only 0.9^14 ≈ 23% of the
    /// old trend would remain, so it says little).
    static let longestGap = 14

    /// Trend Weight over the counted Weigh-ins: the lowest on each Day (spec 014, Weigh-ins).
    static func trend(of weighIns: [WeighIn], in timeZone: TimeZone) -> [TrendPoint] {
        var lowest: [Day: Double] = [:]
        for weighIn in weighIns {
            let day = Day(containing: weighIn.time, in: timeZone)
            lowest[day] = min(lowest[day] ?? .infinity, weighIn.kilograms)
        }
        var points: [TrendPoint] = []
        for (day, weight) in lowest.sorted(by: { $0.key < $1.key }) {
            guard let previous = points.last,
                previous.day.days(until: day) <= longestGap
            else {
                points.append(
                    TrendPoint(day: day, weighIn: weight, trendWeight: weight, startsNewLine: true)
                )
                continue
            }
            let step = 1 - pow(trendKeep, Double(previous.day.days(until: day)))
            let trend = previous.trendWeight + step * (weight - previous.trendWeight)
            points.append(TrendPoint(day: day, weighIn: weight, trendWeight: trend))
        }
        return points
    }

    /// `kilograms` in the view's units, to one decimal (spec 014, Units and Profile).
    public func text(_ kilograms: Double) -> String {
        units.text(kilograms)
    }

    /// The chart over `range`, ending today (spec 014, Screen); nil with no Weigh-ins, when the
    /// screen shows "Log your first Weigh-in" instead.
    public func chart(_ range: ChartRange) -> WeightChart? {
        guard let first = trend.first else { return nil }
        let firstDay = range.days.map { today.adding(days: 1 - $0) } ?? first.day
        let points = trend.filter { $0.day >= firstDay && $0.day <= today }
        return WeightChart(firstDay: firstDay, lastDay: today, points: points)
    }
}

/// How far back the Body tab's chart reaches (spec 014, Screen).
public enum ChartRange: CaseIterable, Sendable {
    case week, month, threeMonths, sixMonths, all

    public var label: String {
        switch self {
        case .week: "1W"
        case .month: "1M"
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        case .all: "All"
        }
    }

    /// How many Days the range shows, today included: a week, about a month (30), 13 weeks (91)
    /// and 26 weeks (182); nil for All, which starts at the first counted Weigh-in.
    var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .threeMonths: 91
        case .sixMonths: 182
        case .all: nil
        }
    }
}

/// The Body tab's chart over one range: Trend Weight points from `firstDay` to `lastDay` (today).
public struct WeightChart: Equatable, Sendable {
    public let firstDay: Day
    public let lastDay: Day
    /// Oldest first.
    public let points: [TrendPoint]

    /// One point is a dot with no line; two or more draw Trend Weight's line.
    public var showsLine: Bool { points.count >= 2 }
}
