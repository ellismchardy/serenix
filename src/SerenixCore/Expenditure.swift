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

    /// The figure for the window ending on `day`: the mean Intake of its Complete Days, plus the
    /// energy of Trend Weight's fall from its first Weigh-in Day to its last, per Day between
    /// them. Nil when the window lacks enough data. `completeIntake` holds each Complete Day's
    /// kcal; `trend` is the Body view's Trend Weight points, oldest first.
    static func windowFigure(
        ending day: Day,
        completeIntake: [Day: Double],
        trend: [TrendPoint]
    ) -> Double? {
        let first = day.adding(days: 1 - windowDays)
        let intakes = completeIntake.filter { $0.key >= first && $0.key <= day }.map(\.value)
        guard intakes.count >= minimumCompleteDays else { return nil }
        var points = trend.filter { $0.day >= first && $0.day <= day }
        // After a restart inside the window only its own line counts (spec 017, Open
        // questions): the Trend Weight before a long gap isn't comparable with the one after.
        if let restart = points.lastIndex(where: \.startsNewLine) {
            points = Array(points[restart...])
        }
        guard points.count >= minimumWeighInDays,
            let firstPoint = points.first, let lastPoint = points.last
        else { return nil }
        let span = firstPoint.day.days(until: lastPoint.day)
        guard span >= minimumWeighInSpanDays else { return nil }
        let meanIntake = intakes.reduce(0, +) / Double(intakes.count)
        return meanIntake
            + (firstPoint.trendWeight - lastPoint.trendWeight)
            * kilocaloriesPerKilogramOfTrendWeight / Double(span)
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
