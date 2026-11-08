import Foundation

/// The user's food targets (spec 016): the Calorie Target, and protein and fat set in place of
/// the suggested Macro Targets. Nil means not set (or, for an override, use the suggestion).
public struct FoodTargets: Equatable, Codable, Sendable {
    public let calorieTarget: Double?
    public let proteinOverride: Double?
    public let fatOverride: Double?

    public init(
        calorieTarget: Double? = nil,
        proteinOverride: Double? = nil,
        fatOverride: Double? = nil
    ) {
        self.calorieTarget = calorieTarget
        self.proteinOverride = proteinOverride
        self.fatOverride = fatOverride
    }

    /// Nothing set.
    public var isEmpty: Bool {
        calorieTarget == nil && proteinOverride == nil && fatOverride == nil
    }

    /// Serenix would refuse these targets if typed in. With no suggestion to fill an unset
    /// override, only what's set is checked.
    var isRefused: Bool {
        if let calorieTarget, CalorieTarget.refusal(calorieTarget) != nil { return true }
        return MacroTargets.overrideRefusal(
            proteinOverride: proteinOverride,
            fatOverride: fatOverride,
            calorieTarget: calorieTarget,
            suggested: nil
        ) != nil
    }
}
