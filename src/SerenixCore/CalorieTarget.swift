import Foundation

/// Why a number can't be the Calorie Target (spec 016, Calorie Target).
public enum CalorieTargetRefusal: Equatable, Sendable {
    /// Under 800 kcal.
    case tooLow
    /// Over 6,000 kcal.
    case tooHigh

    /// Built from the limits, so a changed limit changes its message too.
    public var message: String {
        switch self {
        case .tooLow:
            "A Calorie Target can't be under \(limitText(CalorieTarget.allowed.lowerBound)) kcal."
        case .tooHigh:
            "A Calorie Target can't be over \(limitText(CalorieTarget.allowed.upperBound)) kcal."
        }
    }
}

/// The Intake the user aims for each Day (GLOSSARY, Calorie Target), set by hand (spec 016).
public enum CalorieTarget {
    /// The lowest and highest Calorie Target Serenix accepts, kcal a Day (spec 016, issue #54):
    /// below 800 is a very-low-calorie diet that needs medical supervision; above 6,000 is past
    /// any ordinary need, so a typo.
    static let allowed = 800.0...6_000.0

    /// Why `kilocalories` can't be the Calorie Target; nil when it can.
    public static func refusal(_ kilocalories: Double) -> CalorieTargetRefusal? {
        if kilocalories < allowed.lowerBound { return .tooLow }
        if kilocalories > allowed.upperBound { return .tooHigh }
        return nil
    }
}

/// A Day's Intake against the Calorie Target (spec 016, Screen): what's left to eat, or how far
/// past it, in kcal.
public enum CalorieBalance: Equatable, Sendable {
    case left(Double)
    case over(Double)

    init(intake: Double, target: Double) {
        self = intake > target ? .over(intake - target) : .left(target - intake)
    }
}
