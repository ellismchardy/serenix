import Foundation

/// Whether a Weight Goal loses, gains or holds weight (spec 015, Weight Goal).
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

/// How sensible a Pace is, by its share of Trend Weight a week (spec 015, Pace bands).
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

    /// The rates offered (spec 015, Weight Goal): in kg, or in lb for lb and st units, stored in
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
    public private(set) var pace: GoalPace?
    /// The Day it was last edited (easing included); nil when never. Optional, so goals stored
    /// before it existed still decode (ADR 0008).
    public private(set) var changedDay: Day?
    /// How far apart its Milestones are; nil is the medium step. Optional, so older goals decode.
    public let milestoneStep: MilestoneStep?
    /// For a goal that holds weight: kg either side of Goal Weight; nil for lose and gain.
    /// Optional, so older goals decode.
    public let holdBand: Double?
    /// The Day it was reopened by Undo after Reached; nil when never. It is Reached again only
    /// once Trend Weight has been back on Start Weight's side on a later Day (spec 015). Optional,
    /// so older goals decode.
    public private(set) var reopenedDay: Day?

    public init(
        startWeight: Double,
        startDay: Day,
        goalWeight: Double,
        pace: GoalPace?,
        changedDay: Day? = nil,
        milestoneStep: MilestoneStep? = nil,
        holdBand: Double? = nil,
        reopenedDay: Day? = nil
    ) {
        self.startWeight = startWeight
        self.startDay = startDay
        self.goalWeight = goalWeight
        self.pace = pace
        self.changedDay = changedDay
        self.milestoneStep = milestoneStep
        self.holdBand = holdBand
        self.reopenedDay = reopenedDay
    }

    /// This goal reopened by Undo on `day`, everything else kept (spec 015, Reached).
    public func reopened(on day: Day) -> WeightGoal {
        var goal = self
        goal.reopenedDay = day
        return goal
    }

    /// Whether `trendWeight` has reached Goal Weight: at or below to lose, at or above to gain;
    /// never for a hold.
    func isReached(by trendWeight: Double) -> Bool {
        switch direction {
        case .lose: trendWeight <= goalWeight
        case .gain: trendWeight >= goalWeight
        case .hold: false
        }
    }

    /// This goal as saved over `current` on `day`: marked as changed that Day when it aims
    /// differently (start, Goal Weight or Pace), otherwise keeping `current`'s change Day, so a
    /// new Milestone step alone doesn't restart Ease the goal's count (spec 015).
    public func saved(over current: WeightGoal, on day: Day) -> WeightGoal {
        let aimsTheSame =
            startWeight == current.startWeight && startDay == current.startDay
            && goalWeight == current.goalWeight && pace == current.pace
            && holdBand == current.holdBand
        var goal = self
        goal.changedDay = aimsTheSame ? current.changedDay : day
        return goal
    }

    /// This goal marked as edited on `day`.
    public func changed(on day: Day) -> WeightGoal {
        var goal = self
        goal.changedDay = day
        return goal
    }

    /// Hold with a hold band; otherwise lose when Goal Weight is below Start Weight, else gain.
    public var direction: GoalDirection {
        holdBand != nil ? .hold : goalWeight < startWeight ? .lose : .gain
    }

    /// A goal that holds `weight`, within `band` kg either side, from `day` (spec 015, Hold).
    public static func hold(at weight: Double, band: Double = 1.0, on day: Day) -> WeightGoal {
        WeightGoal(
            startWeight: weight,
            startDay: day,
            goalWeight: weight,
            pace: nil,
            holdBand: band
        )
    }

    /// The hold bands offered, kg either side of Goal Weight (spec 015: 0.5 to 3 kg by 0.5).
    public static let holdBandOptions = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
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

/// What the Rate and Goal cards show for the current Weight Goal (spec 015, Screen).
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
    /// An easier goal to offer, only after 7 Days in a row Off pace or Too fast (spec 015).
    public let ease: GoalEase?
    /// The Milestones from Start Weight toward Goal Weight.
    public let milestones: [Milestone]
    /// How far along the goal is.
    public let progress: GoalProgress
    /// Trend Weight has reached Goal Weight (at or below to lose, at or above to gain); never
    /// for a hold goal. A Reached goal ends (spec 015, Reached).
    public let reached: Bool
    /// Where Trend Weight sits against a hold goal's band; nil for lose and gain.
    public let holdState: HoldState?
    /// The Day Trend Weight reaches Goal Weight at Weekly Rate; nil while Settling in, with
    /// Weekly Rate missing, zero or away from Goal Weight, for a hold, or once reached (spec 015).
    public let projectedDay: Day?
    /// The Day the goal plans to reach Goal Weight: a date Pace's date, or the Days left at a
    /// rate Pace; nil for a hold or once reached.
    public let plannedDay: Day?

    /// `weighInSpan` is the Days from the first counted Weigh-in to the latest. `reachable` is
    /// false for a reopened goal whose Trend Weight hasn't been back on Start Weight's side since.
    init(
        goal: WeightGoal,
        trendWeight: Double,
        weeklyRate: Double?,
        weighInSpan: Int,
        today: Day,
        ease: GoalEase? = nil,
        reachable: Bool = true,
        units: WeightUnits
    ) {
        self.ease = ease
        milestones = Milestone.all(for: goal, trendWeight: trendWeight, units: units)
        progress = GoalProgress(goal: goal, trendWeight: trendWeight)
        reached = reachable && goal.isReached(by: trendWeight)
        let left = goal.isReached(by: trendWeight) ? 0 : abs(trendWeight - goal.goalWeight)
        switch goal.pace {
        case .date(let day) where left > 0: plannedDay = day
        case .rate(let kilogramsPerWeek) where left > 0:
            plannedDay = GoalDates.arrival(
                from: today,
                covering: left,
                atKilogramsPerWeek: kilogramsPerWeek
            )
        default: plannedDay = nil
        }
        holdState = goal.holdBand.map { band in
            trendWeight > goal.goalWeight + band
                ? .aboveBand : trendWeight < goal.goalWeight - band ? .belowBand : .inBand
        }
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
        // Only after Settling in, with Trend Weight moving toward Goal Weight (spec 015).
        if case .badge = status, let weeklyRate, left > 0 {
            let toward = goal.direction == .lose ? -weeklyRate : weeklyRate
            projectedDay = GoalDates.arrival(
                from: today,
                covering: left,
                atKilogramsPerWeek: toward
            )
        } else {
            projectedDay = nil
        }
    }

}

/// Why a Weight Goal can't be saved (spec 015, Weight Goal).
public enum GoalRefusal: Equatable, Sendable {
    case sameAsStart
    case weightOutOfRange
    case rateNotOffered
    case dateTooEarly
    case bandNotOffered
    /// Trend Weight is already at or past Goal Weight, so the goal would end as Reached at once.
    case alreadyReached

    public var message: String {
        switch self {
        case .sameAsStart: "Goal Weight must differ from Start Weight."
        case .weightOutOfRange: "Weights must be 20–350 kg."
        case .rateNotOffered: "Pick one of the Paces offered."
        case .dateTooEarly: "Pick a date no earlier than a 1%-a-week Pace allows."
        case .bandNotOffered: "Pick one of the bands offered."
        case .alreadyReached: "Your Trend Weight is already past this Goal Weight."
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
        if let holdBand {
            let offered = Self.holdBandOptions.contains { abs($0 - holdBand) < Self.rateTolerance }
            return offered ? nil : .bandNotOffered
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
    /// when the direction changes, which ends `current` and starts this one (spec 015).
    public func edits(_ current: WeightGoal) -> Bool {
        direction == current.direction
    }
}

/// The dates a Pace by date can pick from (spec 015, Weight Goal → By date).
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
            // A positive rate always arrives.
            Self.arrival(
                from: today,
                covering: change,
                atKilogramsPerWeek: trendWeight * percent / 100
            ) ?? today
        }
        earliest = day(atPercent: PaceBand.aggressivePercent)
        halfPercent = day(atPercent: Self.halfPercentPace)
        threeQuarterPercent = day(atPercent: Self.threeQuarterPercentPace)
    }

    /// The Day `left` kg is covered from `today` at `kilogramsPerWeek`, rounded up to a whole
    /// Day; nil unless the rate is positive. Every projected, planned and picked date uses it.
    static func arrival(
        from today: Day,
        covering left: Double,
        atKilogramsPerWeek kilogramsPerWeek: Double
    ) -> Day? {
        guard kilogramsPerWeek > 0 else { return nil }
        // Less a hair, so float noise (35.0000000001 Days) never adds a whole Day.
        return today.adding(
            days: Int((left / kilogramsPerWeek * 7 - dayTolerance).rounded(.up))
        )
    }
}

extension WeightGoal {
    /// The Pace in kg a week: a rate's own, or for a date what reaches Goal Weight from
    /// `trendWeight` by that Day, worked out each time (spec 015); nil when there's no Pace or
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

/// Settling in while a goal or its Weigh-ins are too new to judge, then the pace badge (spec 015).
public enum PaceStatus: Equatable, Sendable {
    case settlingIn(day: Int)
    case badge(PaceBadge)

    /// Days a new goal settles before it gets a badge: the first weeks' water and glycogen
    /// change would read as too fast, then behind (issue #61).
    public static let settlingDays = 14
}

/// How Weekly Rate compares with the Pace (spec 015, Pace badge).
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

/// An easier goal offered after a week off pace (spec 015, Ease the goal).
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
            guard left > 0,
                let projected = GoalDates.arrival(
                    from: today,
                    covering: left,
                    atKilogramsPerWeek: toward
                )
            else { return nil }
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
    /// This goal with the offered easier Pace, marked as changed on `day`; its start and Goal
    /// Weight stay.
    public func eased(by ease: GoalEase, on day: Day) -> WeightGoal {
        var goal = changed(on: day)
        goal.pace =
            switch ease {
            case .rate(let kilogramsPerWeek): .rate(kilogramsPerWeek: kilogramsPerWeek)
            case .date(let day): .date(day)
            }
        return goal
    }
}

/// How far apart a goal's Milestones are (spec 015, Progress).
public enum MilestoneStep: String, Codable, CaseIterable, Sendable {
    case small
    case medium
    case large

    /// The step in kg: 1, 2 or 5 kg, or 2, 5 or 10 lb in lb and st units.
    public func size(in units: WeightUnits) -> Double {
        let kilograms = units == .kilograms
        let size: Double =
            switch self {
            case .small: kilograms ? 1 : 2
            case .medium: kilograms ? 2 : 5
            case .large: kilograms ? 5 : 10
            }
        return kilograms ? size : size * WeightUnits.kilogramsPerPound
    }
}

/// A mark on the way from Start Weight to Goal Weight (GLOSSARY, Milestone).
public struct Milestone: Equatable, Sendable {
    public let kilograms: Double
    /// Trend Weight has reached it.
    public let passed: Bool

    /// Ignored at the ends, so a Milestone never sits on Start or Goal Weight by float noise.
    static let edgeTolerance = 1e-9

    /// Whole multiples of the step, in the units shown, strictly between Start and Goal Weight,
    /// from Start toward Goal.
    static func all(for goal: WeightGoal, trendWeight: Double, units: WeightUnits) -> [Milestone] {
        let perUnit = units == .kilograms ? 1 : WeightUnits.kilogramsPerPound
        let step = (goal.milestoneStep ?? .medium).size(in: units) / perUnit
        let start = goal.startWeight / perUnit
        let end = goal.goalWeight / perUnit
        let losing = end < start
        let low = min(start, end)
        let high = max(start, end)
        var marks: [Double] = []
        var multiple = (low / step + edgeTolerance).rounded(.up)
        while multiple * step < high - edgeTolerance {
            if multiple * step > low + edgeTolerance { marks.append(multiple * step) }
            multiple += 1
        }
        if losing { marks.reverse() }
        return marks.map { mark in
            let kilograms = mark * perUnit
            return Milestone(
                kilograms: kilograms,
                passed: losing ? trendWeight <= kilograms : trendWeight >= kilograms
            )
        }
    }
}

/// How far along a Weight Goal is (spec 015, Progress).
public struct GoalProgress: Equatable, Sendable {
    /// The share of the way from Start Weight to Goal Weight, 0–100.
    public let percent: Double
    /// Trend Weight − Start Weight, in kg: negative when lost.
    public let changeSinceStart: Double
    /// How far Trend Weight still is from Goal Weight, in kg; 0 once there.
    public let toGo: Double

    init(goal: WeightGoal, trendWeight: Double) {
        let whole = goal.goalWeight - goal.startWeight
        let done = trendWeight - goal.startWeight
        percent = whole == 0 ? 100 : min(100, max(0, done / whole * 100))
        changeSinceStart = done
        let left =
            goal.direction == .lose ? trendWeight - goal.goalWeight : goal.goalWeight - trendWeight
        toGo = max(0, left)
    }
}

/// Where Trend Weight sits against a hold goal's band (spec 015, Hold).
public enum HoldState: String, Sendable {
    case inBand
    case aboveBand
    case belowBand
}
