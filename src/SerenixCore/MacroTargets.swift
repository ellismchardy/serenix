import Foundation

/// The grams of protein, fat and carbs the user aims for each Day (GLOSSARY, Macro Targets),
/// drawn from the Calorie Target, Trend Weight and the Weight Goal (spec 016; issue #54,
/// `docs/research/macro-targets-by-goal.md`).
public struct MacroTargets: Equatable, Sendable {
    public let protein: Double
    public let fat: Double
    public let carbs: Double

    /// Protein when the Weight Goal loses, g per kg a Day (issue #54: 2.2 g/kg, just below the
    /// ISSN's 2.3–3.1 g/kg for keeping lean mass in a deficit).
    static let losingProteinPerKilogram = 2.2
    /// Protein otherwise, g per kg a Day (issue #54: Morton et al. 2018, no further gain above
    /// about 1.6 g/kg).
    static let otherProteinPerKilogram = 1.6
    /// Above this BMI, protein is per kg of the weight at `referenceBMI` instead (issue #54).
    static let obeseBMI = 30.0
    /// The BMI whose weight protein is per kg of, above `obeseBMI` (issue #54).
    static let referenceBMI = 25.0
    /// Fat's share of the Calorie Target (issue #54: the middle of 20–30%).
    static let fatShare = 0.25
    /// kcal per gram of protein and of carbs (Atwater factors; spec 016, issue #54).
    static let kilocaloriesPerGramProteinOrCarbs = 4.0
    /// kcal per gram of fat (Atwater factor; spec 016, issue #54).
    static let kilocaloriesPerGramFat = 9.0
    /// Carbs under this many grams a Day get a warning (issue #54: the IOM's 130 g/day RDA).
    public static let lowCarbsGrams = 130.0
    /// kcal of rounding noise ignored when protein and fat use up the Calorie Target exactly.
    static let kilocalorieTolerance = 1e-9

    public init(protein: Double, fat: Double, carbs: Double) {
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
    }

    /// The targets, and any warning, for `calorieTarget` kcal at `trendWeight` kg: an override
    /// replaces that macro's suggestion, and carbs fill what's left.
    static func suggested(
        calorieTarget: Double,
        trendWeight: Double,
        direction: GoalDirection?,
        heightCentimetres: Double?,
        proteinOverride: Double? = nil,
        fatOverride: Double? = nil
    ) -> (targets: MacroTargets, warning: MacroWarning?) {
        let perKilogram =
            direction == .lose ? losingProteinPerKilogram : otherProteinPerKilogram
        let protein =
            proteinOverride ?? perKilogram * proteinWeight(trendWeight, heightCentimetres)
        let fat = fatOverride ?? calorieTarget * fatShare / kilocaloriesPerGramFat
        return withCarbs(protein: protein, fat: fat, calorieTarget: calorieTarget)
    }

    /// `protein` and `fat` with carbs filling what's left of `calorieTarget`, and any warning.
    static func withCarbs(
        protein: Double,
        fat: Double,
        calorieTarget: Double
    ) -> (targets: MacroTargets, warning: MacroWarning?) {
        let left =
            calorieTarget - protein * kilocaloriesPerGramProteinOrCarbs
            - fat * kilocaloriesPerGramFat
        let carbs = max(0, left / kilocaloriesPerGramProteinOrCarbs)
        let warning: MacroWarning?
        if left <= kilocalorieTolerance {
            warning = .noCarbsLeft  // used up exactly counts too: carbs are 0 either way
        } else if carbs < lowCarbsGrams {
            warning = .lowCarbs
        } else {
            warning = nil
        }
        return (MacroTargets(protein: protein, fat: fat, carbs: carbs), warning)
    }

    /// The kg protein is counted per: Trend Weight, or with a height and a BMI over 30, the
    /// weight at BMI 25 for that height.
    private static func proteinWeight(_ trendWeight: Double, _ heightCentimetres: Double?) -> Double
    {
        guard let heightCentimetres, heightCentimetres > 0 else { return trendWeight }
        let metresSquared = (heightCentimetres / 100) * (heightCentimetres / 100)
        return trendWeight / metresSquared > obeseBMI ? referenceBMI * metresSquared : trendWeight
    }
}

extension MacroTargets {
    /// The most protein or fat an override may set, g a Day (spec 016, issue #54), as a Food
    /// Entry's macros.
    static let maxOverrideGrams = FoodEntry.maxMacroGrams

    /// Why protein and fat overrides can't be saved at `calorieTarget`; nil when they can. With
    /// one override, pass the other macro's suggestion. Carbs at exactly 0 are allowed; only
    /// below 0 is refused (spec 016, Overrides).
    public static func overrideRefusal(
        protein: Double,
        fat: Double,
        calorieTarget: Double
    ) -> MacroOverrideRefusal? {
        if protein < 0 || fat < 0 { return .negative }
        if protein > maxOverrideGrams || fat > maxOverrideGrams { return .tooLarge }
        let used = protein * kilocaloriesPerGramProteinOrCarbs + fat * kilocaloriesPerGramFat
        if used > calorieTarget + kilocalorieTolerance { return .noCarbsLeft }
        return nil
    }
}

extension MacroTargets {
    /// Why protein and fat overrides (nil uses the suggestion) can't be saved; nil when they can.
    /// The 0–500 g limits always apply to a set override, even with no Calorie Target or no
    /// suggestion. The carbs check applies only with a Calorie Target, filling an unset override
    /// from `suggested`; with an unset override and no suggestion there's nothing to check it
    /// against.
    public static func overrideRefusal(
        proteinOverride: Double?,
        fatOverride: Double?,
        calorieTarget: Double?,
        suggested: MacroTargets?
    ) -> MacroOverrideRefusal? {
        let set = [proteinOverride, fatOverride].compactMap { $0 }
        if set.contains(where: { $0 < 0 }) { return .negative }
        if set.contains(where: { $0 > maxOverrideGrams }) { return .tooLarge }
        guard !set.isEmpty, let calorieTarget,
            let protein = proteinOverride ?? suggested?.protein,
            let fat = fatOverride ?? suggested?.fat
        else { return nil }
        return overrideRefusal(protein: protein, fat: fat, calorieTarget: calorieTarget)
    }
}

/// Why protein and fat overrides can't be saved (spec 016, Overrides).
public enum MacroOverrideRefusal: Equatable, Sendable {
    /// Protein or fat below 0.
    case negative
    /// Protein or fat over 500 g.
    case tooLarge
    /// Protein and fat need more than the Calorie Target, leaving carbs below 0.
    case noCarbsLeft

    /// Built from the limits, so a changed limit changes its message too.
    public var message: String {
        switch self {
        case .negative: "Protein and fat can't be below 0."
        case .tooLarge:
            "Protein and fat can't be over \(limitText(MacroTargets.maxOverrideGrams)) g each."
        case .noCarbsLeft: "That leaves no room for carbs at this Calorie Target."
        }
    }
}

/// A warning about the carbs left for the Macro Targets (spec 016).
public enum MacroWarning: Equatable, Sendable {
    /// Carbs under 130 g a Day.
    case lowCarbs
    /// Protein and fat use up the whole Calorie Target, so carbs are 0.
    case noCarbsLeft
}
