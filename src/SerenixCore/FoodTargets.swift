import Foundation

/// The user's food targets (spec 016): the Calorie Target, and protein and fat set in place of
/// the suggested Macro Targets; and, from spec 017, the Activity Level and the Adapt switch. Nil
/// means not set (or, for an override, use the suggestion).
public struct FoodTargets: Equatable, Codable, Sendable {
    public let calorieTarget: Double?
    public let proteinOverride: Double?
    public let fatOverride: Double?
    /// How active the user's Days usually are (spec 017); nil reads as Light. Optional, so
    /// targets saved before it existed still decode.
    public let activityLevel: ActivityLevel?
    /// The Adapt switch (spec 017): when on, the suggested Calorie Target applies while there is
    /// one, and `calorieTarget` is kept for when it's off. Nil reads as off; optional, so
    /// targets saved before it existed still decode.
    public let adaptsCalorieTarget: Bool?

    public init(
        calorieTarget: Double? = nil,
        proteinOverride: Double? = nil,
        fatOverride: Double? = nil,
        activityLevel: ActivityLevel? = nil,
        adaptsCalorieTarget: Bool? = nil
    ) {
        self.calorieTarget = calorieTarget
        self.proteinOverride = proteinOverride
        self.fatOverride = fatOverride
        self.activityLevel = activityLevel
        self.adaptsCalorieTarget = adaptsCalorieTarget
    }

    /// The Calorie Target that applies (spec 017, Adapt): `suggested` while Adapt is on and there
    /// is one, else the typed `calorieTarget`, which is kept either way.
    public func appliedCalorieTarget(suggested: Double?) -> Double? {
        adaptsCalorieTarget == true ? suggested ?? calorieTarget : calorieTarget
    }

    /// Nothing set: every field reads as it does when unset. An Activity Level of Light and
    /// Adapt off count as unset, since nil reads as Light and off (spec 017, Backup).
    public var isEmpty: Bool {
        calorieTarget == nil && proteinOverride == nil && fatOverride == nil
            && (activityLevel ?? .light) == .light && adaptsCalorieTarget != true
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
