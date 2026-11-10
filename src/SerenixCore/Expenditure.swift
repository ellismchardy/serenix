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
