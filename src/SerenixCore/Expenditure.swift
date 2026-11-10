import Foundation

/// How active the user says their Days usually are (GLOSSARY, Activity Level), used only for the
/// starting estimate of Expenditure (spec 017).
public enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case mostlySitting
    case light
    case moderate
    case veryActive

    /// The resting rate's multiplier, × 1.2, 1.375, 1.55, 1.725: the conventional activity
    /// factors paired with a resting-rate equation for a starting estimate ("Mifflin-St Jeor RMR
    /// × activity factor", `docs/research/adaptive-calorie-expenditure.md`, Answer; issue #52).
    /// The research doesn't pin the four values; they replace nothing measured and give way to
    /// the user's own data (spec 017).
    public var factor: Double {
        switch self {
        case .mostlySitting: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .veryActive: 1.725
        }
    }
}

/// Where the Food view's Expenditure comes from (spec 017).
public enum ExpenditureSource: Equatable, Sendable {
    /// The starting estimate: the resting rate times the Activity Level.
    case profile
    /// The user's own logged Intake and Trend Weight.
    case loggedData
}

/// What the starting estimate needs and doesn't have (spec 017, Starting estimate).
public enum ExpenditureInput: Equatable, Sendable {
    case height
    case birthYear
    case weighIn
}

/// Expenditure's arithmetic (spec 017; issue #52, `docs/research/adaptive-calorie-expenditure.md`).
enum Expenditure {
    /// Mifflin-St Jeor's coefficients, kcal a Day (Mifflin et al. 1990, simplified form;
    /// `docs/research/calories-burned-from-heart-rate.md`): per kg, per cm, per year of age.
    static let kilocaloriesPerKilogram = 10.0
    static let kilocaloriesPerCentimetre = 6.25
    static let kilocaloriesPerYear = 5.0
    /// Mifflin-St Jeor's sex constants, kcal a Day; "prefer not to say" takes their midpoint.
    static let maleConstant = 5.0
    static let femaleConstant = -161.0
    static let unstatedConstant = -78.0

    /// The Days in a window, the one it ends on included (spec 017; issue #52's 14–21 Days, at
    /// the long end so one odd week weighs less).
    static let windowDays = 21
    /// The fewest Complete Days a window needs (issue #52: about 10 fully logged Days).
    static let minimumCompleteDays = 10
    /// The fewest Days with a Weigh-in a window needs (issue #52: about 8 Weigh-ins).
    static let minimumWeighInDays = 8
    /// The fewest Days between a window's first and last Weigh-in Days (issue #52: at least
    /// 14 Days of span).
    static let minimumWeighInSpanDays = 14
    /// kcal in one kg of Trend Weight (issue #52: 7,700 kcal/kg, the usual converter for
    /// moderate change; `docs/research/adaptive-calorie-expenditure.md`).
    static let kilocaloriesPerKilogramOfTrendWeight = 7_700.0

    /// How far Expenditure moves toward each Day's window figure (issue #52: damp the estimate
    /// about 10% a Day, so one odd week can't swing it).
    static let easingStep = 0.1

    /// The lowest Calorie Target Serenix suggests, kcal a Day (spec 017: a common safe minimum
    /// for an unsupervised diet; the resting rate raises it when higher).
    static let minimumSuggestedCalorieTarget = 1_200.0
    /// Days in a week: a Pace in kg a week spreads its energy over these (spec 017).
    static let daysPerWeek = 7.0
    /// Suggestions are whole multiples of this many kcal (spec 017).
    static let suggestionStep = 10.0

    /// The Calorie Target for `expenditure` and a Pace of `kilogramsPerWeek` (negative to lose),
    /// at 7,700 kcal per kg spread over 7 Days, and whether a losing Pace needs less than the floor (spec
    /// 017, Suggested Calorie Target). The floor is the higher of 1,200 kcal and `restingRate`;
    /// a floored suggestion rounds up so it never ends below it. Kept within the Calorie
    /// Target's allowed range.
    static func suggestedCalorieTarget(
        expenditure: Double,
        kilogramsPerWeek: Double,
        restingRate: Double?
    ) -> (kilocalories: Double, paceUnreachable: Bool) {
        let wanted =
            expenditure + kilogramsPerWeek * kilocaloriesPerKilogramOfTrendWeight / daysPerWeek
        let floor = max(minimumSuggestedCalorieTarget, restingRate ?? 0)
        // The floor, rounded up, so no suggestion (floored or rounded) ever ends below it.
        let lowest = (floor / suggestionStep).rounded(.up) * suggestionStep
        let rounded = max((wanted / suggestionStep).rounded() * suggestionStep, lowest)
        // Only a Pace that loses can need less than the floor; with no Pace (holding, no goal)
        // or a gaining one, a low Expenditure isn't the Pace's doing.
        let paceUnreachable = kilogramsPerWeek < 0 && wanted < floor
        let allowed = CalorieTarget.allowed
        return (min(max(rounded, allowed.lowerBound), allowed.upperBound), paceUnreachable)
    }

    /// The resting rate, kcal a Day, at `trendWeight` kg, `heightCentimetres` and `age` years.
    static func restingRate(
        trendWeight: Double,
        heightCentimetres: Double,
        age: Int,
        sex: Sex?
    ) -> Double {
        let constant =
            switch sex {
            case .male: maleConstant
            case .female: femaleConstant
            case .preferNotToSay, nil: unstatedConstant
            }
        return kilocaloriesPerKilogram * trendWeight + kilocaloriesPerCentimetre * heightCentimetres
            - kilocaloriesPerYear * Double(age) + constant
    }
}

/// The user's logged data for Expenditure, sorted once so each Day's window is found by binary
/// search rather than by filtering everything again (spec 017).
struct LoggedData {
    /// The Complete Days, oldest first, and their Intake in kcal.
    private let intakeDays: [Day]
    private let intakes: [Double]
    /// The Body view's Trend Weight points, oldest first, and their Days.
    private let trend: [TrendPoint]
    private let trendDays: [Day]

    /// `completeIntake` holds each Complete Day's kcal; `trend` is the Body view's Trend Weight
    /// points, oldest first.
    init(completeIntake: [Day: Double], trend: [TrendPoint]) {
        let sorted = completeIntake.sorted { $0.key < $1.key }
        intakeDays = sorted.map(\.key)
        intakes = sorted.map(\.value)
        self.trend = trend
        trendDays = trend.map(\.day)
    }

    /// The figure for the window ending on `day`: the mean Intake of its Complete Days, plus the
    /// energy of Trend Weight's fall from its first Weigh-in Day to its last, per Day between
    /// them. Nil when the window lacks enough data.
    func figure(ending day: Day) -> Double? {
        let first = day.adding(days: 1 - Expenditure.windowDays)
        let intakeRange = Self.range(of: intakeDays, from: first, through: day)
        guard intakeRange.count >= Expenditure.minimumCompleteDays else { return nil }
        var points = trend[Self.range(of: trendDays, from: first, through: day)]
        // After a restart inside the window only its own line counts (spec 017, Open
        // questions): the Trend Weight before a long gap isn't comparable with the one after.
        if let restart = points.lastIndex(where: \.startsNewLine) {
            points = points[restart...]
        }
        guard points.count >= Expenditure.minimumWeighInDays,
            let firstPoint = points.first, let lastPoint = points.last
        else { return nil }
        let span = firstPoint.day.days(until: lastPoint.day)
        guard span >= Expenditure.minimumWeighInSpanDays else { return nil }
        let meanIntake = intakes[intakeRange].reduce(0, +) / Double(intakeRange.count)
        return meanIntake
            + (firstPoint.trendWeight - lastPoint.trendWeight)
            * Expenditure.kilocaloriesPerKilogramOfTrendWeight / Double(span)
    }

    /// Expenditure from logged data as of `day`, eased Day by Day (spec 017): on the first Day
    /// whose window has enough data it moves `easingStep` of the way from that Day's starting
    /// estimate to the window's figure, and on each later Day from the previous Day's
    /// Expenditure; a Day without enough data leaves it where it was. Nil until a window has
    /// enough data. `startingEstimate` gives the starting estimate on a Day at a Trend Weight;
    /// with none (no height or birth year), the first figure seeds it instead.
    func eased(through day: Day, startingEstimate: (Day, Double) -> Double?) -> Double? {
        // No window ends with enough data before its Weigh-ins can span the minimum.
        guard let firstWeighInDay = trendDays.first else { return nil }
        var current = firstWeighInDay.adding(days: Expenditure.minimumWeighInSpanDays)
        var expenditure: Double?
        while current <= day {
            if let figure = figure(ending: current) {
                let previous =
                    expenditure
                    ?? trend[Self.range(of: trendDays, from: firstWeighInDay, through: current)]
                    .last.flatMap { startingEstimate(current, $0.trendWeight) }
                    ?? figure
                expenditure = previous + Expenditure.easingStep * (figure - previous)
            }
            current = current.adding(days: 1)
        }
        return expenditure
    }

    /// The indices of `days` (sorted) from `first` through `last`, both included.
    private static func range(of days: [Day], from first: Day, through last: Day) -> Range<Int> {
        let lower = firstIndex(in: days) { $0 >= first }
        let upper = firstIndex(in: days) { $0 > last }
        return lower..<max(lower, upper)
    }

    /// The first index of sorted `days` meeting `isPast`, which turns true once and stays so;
    /// `days.count` when none does.
    private static func firstIndex(in days: [Day], where isPast: (Day) -> Bool) -> Int {
        var low = 0
        var high = days.count
        while low < high {
            let middle = (low + high) / 2
            if isPast(days[middle]) { high = middle } else { low = middle + 1 }
        }
        return low
    }
}
