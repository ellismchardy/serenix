import Foundation

/// Whether a Weight Goal loses, gains or holds weight (spec 014, Weight Goal).
public enum GoalDirection: String, Codable, Sendable {
    case lose
    case gain
    case hold
}

/// How a Weight Goal's Pace was chosen: a rate in kg a week, or a Day to reach Goal Weight by.
public enum GoalPace: Equatable, Codable, Sendable {
    case rate(kilogramsPerWeek: Double)
    case date(Day)
}

/// How sensible a Pace is, by its share of Trend Weight a week (spec 014, Pace bands).
public enum PaceBand: String, Codable, Sendable {
    case sustainable
    case aggressive
    case tooFast

    /// The most a sustainable Pace changes Trend Weight a week, in % (issue #51, Helms et al.
    /// 2014; `docs/research/safe-rate-of-weight-change.md`).
    static let sustainablePercent = 0.5
    /// The most an aggressive Pace changes Trend Weight a week, in % (issue #51, Garthe et al.
    /// 2011); above it is too fast. For gaining, this cap is our own call: no source sets one.
    static let aggressivePercent = 1.0

    /// The band for a change of `percentOfTrendWeight` % a week, losing or gaining.
    init(percentOfTrendWeight percent: Double) {
        self =
            percent <= Self.sustainablePercent
            ? .sustainable : percent <= Self.aggressivePercent ? .aggressive : .tooFast
    }
}

/// One Pace the Weight Goal sheet offers, with its share of Trend Weight and its band.
public struct RateOption: Equatable, Sendable {
    public let kilogramsPerWeek: Double
    public let percentOfTrendWeight: Double
    public let band: PaceBand

    init(kilogramsPerWeek: Double, trendWeight: Double) {
        self.kilogramsPerWeek = kilogramsPerWeek
        percentOfTrendWeight = kilogramsPerWeek / trendWeight * 100
        band = PaceBand(percentOfTrendWeight: percentOfTrendWeight)
    }

    /// The rates offered (spec 014, Weight Goal): in kg, or in lb for lb and st units, stored in
    /// kg either way.
    static func rates(for direction: GoalDirection, units: WeightUnits) -> [Double] {
        let inKilograms = units == .kilograms
        let rates: [Double] =
            switch direction {
            case .lose: inKilograms ? [0.25, 0.5, 0.75, 1.0] : [0.5, 1, 1.5, 2]
            case .gain: inKilograms ? [0.1, 0.25, 0.5] : [0.25, 0.5, 1]
            case .hold: []
            }
        return inKilograms ? rates : rates.map { $0 * WeightUnits.kilogramsPerPound }
    }
}

/// The weight the user is working toward (GLOSSARY, Weight Goal), in kg.
public struct WeightGoal: Equatable, Codable, Sendable {
    public let startWeight: Double
    public let startDay: Day
    public let goalWeight: Double
    /// Nil for a goal that holds weight.
    public let pace: GoalPace?

    public init(startWeight: Double, startDay: Day, goalWeight: Double, pace: GoalPace?) {
        self.startWeight = startWeight
        self.startDay = startDay
        self.goalWeight = goalWeight
        self.pace = pace
    }

    /// Lose when Goal Weight is below Start Weight, otherwise gain.
    public var direction: GoalDirection {
        goalWeight < startWeight ? .lose : .gain
    }
}

/// Where a new Weight Goal starts by default: today's Trend Weight, today.
public struct GoalStart: Equatable, Sendable {
    public let weight: Double
    public let day: Day

    public init(weight: Double, day: Day) {
        self.weight = weight
        self.day = day
    }
}

/// What the Rate and Goal cards show for the current Weight Goal (spec 014, Screen).
public struct GoalCard: Equatable, Sendable {
    public let goal: WeightGoal
    public let direction: GoalDirection
    /// The Pace in kg a week, for a rate or a date; nil with no Pace left to cover.
    public let paceKilogramsPerWeek: Double?
    /// The Pace as a share of current Trend Weight a week, in %.
    public let pacePercentOfTrendWeight: Double?
    public let paceBand: PaceBand?
    /// Settling in, or the pace badge; nil without a Pace.
    public let status: PaceStatus?
    /// An easier goal to offer, only after 7 Days in a row Off pace or Too fast (spec 014).
    public let ease: GoalEase?

    /// `weighInSpan` is the Days from the first counted Weigh-in to the latest.
    init(
        goal: WeightGoal,
        trendWeight: Double,
        weeklyRate: Double?,
        weighInSpan: Int,
        today: Day,
        ease: GoalEase? = nil
    ) {
        self.ease = ease
        self.goal = goal
        direction = goal.direction
        if let kilogramsPerWeek = goal.paceKilogramsPerWeek(trendWeight: trendWeight, today: today)
        {
            let option = RateOption(kilogramsPerWeek: kilogramsPerWeek, trendWeight: trendWeight)
            paceKilogramsPerWeek = kilogramsPerWeek
            pacePercentOfTrendWeight = option.percentOfTrendWeight
            paceBand = option.band
            let settled = min(goal.startDay.days(until: today), weighInSpan)
            status =
                settled < PaceStatus.settlingDays
                // A start date in the future counts as day 0.
                ? .settlingIn(day: max(0, settled))
                : .badge(
                    PaceBadge(
                        weeklyRate: weeklyRate,
                        paceKilogramsPerWeek: kilogramsPerWeek,
                        direction: goal.direction,
                        trendWeight: trendWeight
                    )
                )
        } else {
            paceKilogramsPerWeek = nil
            pacePercentOfTrendWeight = nil
            paceBand = nil
            status = nil
        }
    }
}

/// Why a Weight Goal can't be saved (spec 014, Weight Goal).
public enum GoalRefusal: Equatable, Sendable {
    case sameAsStart
    case weightOutOfRange
    case rateNotOffered
    case dateTooEarly

    public var message: String {
        switch self {
        case .sameAsStart: "Goal Weight must differ from Start Weight."
        case .weightOutOfRange: "Weights must be 20–350 kg."
        case .rateNotOffered: "Pick one of the Paces offered."
        case .dateTooEarly: "Pick a date no earlier than a 1%-a-week Pace allows."
        }
    }
}

/// Why a Weight Goal ended; kept with it (ADR 0008).
public enum GoalEnd: String, Codable, Sendable {
    case reached
    case changed
    case removed
}

extension WeightGoal {
    /// How close a rate must be to an offered one to count as it, in kg a week: it only absorbs
    /// rounding in the lb conversion.
    static let rateTolerance = 1e-9

    /// Lose when Goal Weight is below Start Weight, gain when above; nil when they're equal.
    public static func direction(startWeight: Double, goalWeight: Double) -> GoalDirection? {
        goalWeight < startWeight ? .lose : goalWeight > startWeight ? .gain : nil
    }

    /// Why this goal can't be saved with `units`' rate options; nil when it can.
    public func refusal(units: WeightUnits) -> GoalRefusal? {
        let allowed = WeighIn.allowedKilograms
        guard allowed.contains(startWeight), allowed.contains(goalWeight) else {
            return .weightOutOfRange
        }
        guard let direction = Self.direction(startWeight: startWeight, goalWeight: goalWeight)
        else { return .sameAsStart }
        if case .rate(let kilogramsPerWeek) = pace,
            !RateOption.rates(for: direction, units: units).contains(where: {
                abs($0 - kilogramsPerWeek) < Self.rateTolerance
            })
        {
            return .rateNotOffered
        }
        return nil
    }

    /// Whether saving this goal edits `current` in place: true in the same direction, false
    /// when the direction changes, which ends `current` and starts this one (spec 014).
    public func edits(_ current: WeightGoal) -> Bool {
        direction == current.direction
    }
}

/// The dates a Pace by date can pick from (spec 014, Weight Goal → By date).
public struct GoalDates: Equatable, Sendable {
    /// The earliest Day allowed: a Pace of 1% of Trend Weight a week reaches Goal Weight by it.
    public let earliest: Day
    /// The quick pick at 0.5% a week.
    public let halfPercent: Day
    /// The quick pick at 0.75% a week.
    public let threeQuarterPercent: Day

    /// The quick picks' Paces, in % of Trend Weight a week (issue #51).
    static let halfPercentPace = 0.5
    static let threeQuarterPercentPace = 0.75
    /// Days of rounding noise ignored when rounding up to a whole Day.
    static let dayTolerance = 1e-9

    init?(trendWeight: Double, goalWeight: Double, today: Day) {
        let change = abs(trendWeight - goalWeight)
        guard change > 0 else { return nil }
        func day(atPercent percent: Double) -> Day {
            let weeks = change / (trendWeight * percent / 100)
            // Less a hair, so float noise (35.0000000001 Days) never adds a whole Day.
            return today.adding(days: Int((weeks * 7 - Self.dayTolerance).rounded(.up)))
        }
        earliest = day(atPercent: PaceBand.aggressivePercent)
        halfPercent = day(atPercent: Self.halfPercentPace)
        threeQuarterPercent = day(atPercent: Self.threeQuarterPercentPace)
    }
}

extension WeightGoal {
    /// The Pace in kg a week: a rate's own, or for a date what reaches Goal Weight from
    /// `trendWeight` by that Day, worked out each time (spec 014); nil when there's no Pace or
    /// the date isn't after today.
    func paceKilogramsPerWeek(trendWeight: Double, today: Day) -> Double? {
        switch pace {
        case .rate(let kilogramsPerWeek):
            return kilogramsPerWeek
        case .date(let day):
            let days = today.days(until: day)
            let left = direction == .lose ? trendWeight - goalWeight : goalWeight - trendWeight
            guard days > 0, left > 0 else { return nil }
            return left / (Double(days) / 7)
        case nil:
            return nil
        }
    }
}

/// Settling in while a goal or its Weigh-ins are too new to judge, then the pace badge (spec 014).
public enum PaceStatus: Equatable, Sendable {
    case settlingIn(day: Int)
    case badge(PaceBadge)

    /// Days a new goal settles before it gets a badge: the first weeks' water and glycogen
    /// change would read as too fast, then behind (issue #61).
    public static let settlingDays = 14
}

/// How Weekly Rate compares with the Pace (spec 014, Pace badge).
public enum PaceBadge: String, Sendable {
    case onPace
    case behind
    case offPace
    case tooFast

    /// Shares of Pace (issue #61): on pace from 90%, a bit behind from 60%, too fast over 125%
    /// when also over the sustainable 0.5% of Trend Weight a week.
    static let onPaceShare = 0.9
    static let behindShare = 0.6
    static let tooFastShare = 1.25
    /// Tolerance on every comparison (shares and %), so 0.45 of a 0.5 Pace is on pace despite
    /// float rounding.
    static let comparisonTolerance = 1e-9

    public init(
        weeklyRate: Double?,
        paceKilogramsPerWeek: Double,
        direction: GoalDirection,
        trendWeight: Double
    ) {
        guard let weeklyRate, paceKilogramsPerWeek > 0 else {
            self = .offPace
            return
        }
        let toward = direction == .lose ? -weeklyRate : weeklyRate
        let share = toward / paceKilogramsPerWeek
        let percent = toward / trendWeight * 100
        if share > Self.tooFastShare + Self.comparisonTolerance,
            percent > PaceBand.sustainablePercent + Self.comparisonTolerance
        {
            self = .tooFast
        } else if share >= Self.onPaceShare - Self.comparisonTolerance {
            self = .onPace
        } else if share >= Self.behindShare - Self.comparisonTolerance {
            self = .behind
        } else {
            self = .offPace
        }
    }
}

/// An easier goal offered after a week off pace (spec 014, Ease the goal).
public enum GoalEase: Equatable, Sendable {
    case rate(kilogramsPerWeek: Double)
    case date(Day)

    /// Days in a row the badge must be Off pace or Too fast before easing is offered (issue #61).
    public static let offPaceDays = 7

    /// What to offer for `badge`: for a rate Pace, the next slower option when Off pace (nil at
    /// the slowest) or the option nearest Weekly Rate when Too fast; for a date Pace, the Day
    /// Trend Weight reaches Goal Weight at Weekly Rate, when it's moving toward it. Nil otherwise.
    public static func offer(
        goal: WeightGoal,
        badge: PaceBadge,
        weeklyRate: Double?,
        trendWeight: Double,
        today: Day,
        units: WeightUnits
    ) -> GoalEase? {
        guard badge == .offPace || badge == .tooFast else { return nil }
        switch goal.pace {
        case .rate(let current):
            let options = RateOption.rates(for: goal.direction, units: units)
            if badge == .tooFast {
                guard let weeklyRate,
                    let nearest = options.min(by: {
                        abs($0 - abs(weeklyRate)) < abs($1 - abs(weeklyRate))
                    }),
                    abs(nearest - current) > WeightGoal.rateTolerance
                else { return nil }  // the goal's own Pace would change nothing
                return .rate(kilogramsPerWeek: nearest)
            }
            return options.last { $0 < current - WeightGoal.rateTolerance }
                .map { .rate(kilogramsPerWeek: $0) }
        case .date:
            guard let weeklyRate else { return nil }
            let toward = goal.direction == .lose ? -weeklyRate : weeklyRate
            let left = abs(trendWeight - goal.goalWeight)
            guard toward > 0, left > 0 else { return nil }
            let days = Int((left / toward * 7 - GoalDates.dayTolerance).rounded(.up))
            let projected = today.adding(days: days)
            // Never earlier than a 1%-a-week Pace allows, as the goal sheet requires.
            let earliest = GoalDates(
                trendWeight: trendWeight,
                goalWeight: goal.goalWeight,
                today: today
            )?.earliest
            return .date(max(projected, earliest ?? projected))
        case nil:
            return nil
        }
    }
}

extension WeightGoal {
    /// This goal with the offered easier Pace; its start and Goal Weight stay.
    public func eased(by ease: GoalEase) -> WeightGoal {
        let pace: GoalPace =
            switch ease {
            case .rate(let kilogramsPerWeek): .rate(kilogramsPerWeek: kilogramsPerWeek)
            case .date(let day): .date(day)
            }
        return WeightGoal(
            startWeight: startWeight,
            startDay: startDay,
            goalWeight: goalWeight,
            pace: pace
        )
    }
}
