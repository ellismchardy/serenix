import Foundation

/// Everything the Body tab's Food view shows for one Day (spec 016), worked out from the stored
/// Food Entries each time, never stored (ADR 0008). The shell draws it.
public struct FoodView: Equatable, Sendable {
    /// The Day shown.
    public let day: Day
    /// The shown Day's Food Entries, newest first.
    public let entries: [FoodEntry]
    /// The shown Day's Food Entries added up.
    public let intake: Intake
    /// The shown Day is marked complete and has at least one Food Entry.
    public let isComplete: Bool
    /// The shown Day has a Food Entry, so it may be marked complete (spec 016).
    public let canBeMarkedComplete: Bool
    /// The Calorie Target, kcal a Day; nil when not set.
    public let calorieTarget: Double?
    /// Intake against the Calorie Target; nil with no Calorie Target.
    public let calorieBalance: CalorieBalance?
    /// The Macro Targets, suggested or overridden; nil with no Calorie Target or no Trend Weight.
    public let macroTargets: MacroTargets?
    /// A warning about the carbs the Macro Targets leave, if any.
    public let macroWarning: MacroWarning?
    /// A Calorie Target is set but there's no Trend Weight yet, so a Weigh-in is needed.
    public let needsWeighIn: Bool

    /// Each Food Entry counts on the local Day of its time in `timeZone`, as Weigh-ins do.
    /// `completeDays` are the Days the user marked complete. Macro Targets use today's Trend
    /// Weight, worked out by the Body view from `weighIns`, so the two never disagree.
    public init(
        foodEntries: [FoodEntry],
        completeDays: Set<Day> = [],
        calorieTarget: Double? = nil,
        proteinOverride: Double? = nil,
        fatOverride: Double? = nil,
        weighIns: [WeighIn] = [],
        weightGoal: WeightGoal? = nil,
        heightCentimetres: Double? = nil,
        day: Day,
        now: Date,
        timeZone: TimeZone
    ) {
        self.day = day
        entries =
            foodEntries
            .filter { Day(containing: $0.time, in: timeZone) == day }
            .sorted { $0.time > $1.time }
        intake = Intake(entries)
        canBeMarkedComplete = !entries.isEmpty
        isComplete = canBeMarkedComplete && completeDays.contains(day)
        self.calorieTarget = calorieTarget
        calorieBalance = calorieTarget.map { [intake] in
            CalorieBalance(intake: intake.kilocalories, target: $0)
        }
        // The Body view's own Trend Weight rule, so the two never disagree.
        let trendWeight = BodyView.trend(of: weighIns, in: timeZone).last?.trendWeight
        if let calorieTarget, let trendWeight {
            let suggested = MacroTargets.suggested(
                calorieTarget: calorieTarget,
                trendWeight: trendWeight,
                direction: weightGoal?.direction,
                heightCentimetres: heightCentimetres,
                proteinOverride: proteinOverride,
                fatOverride: fatOverride
            )
            macroTargets = suggested.targets
            macroWarning = suggested.warning
        } else {
            macroTargets = nil
            macroWarning = nil
        }
        needsWeighIn = calorieTarget != nil && trendWeight == nil
    }

    /// The suggested Macro Targets (no overrides) at `calorieTarget`, from today's Trend Weight:
    /// what the targets sheet shows and checks against while the user types; nil with no Trend
    /// Weight.
    public static func suggestedMacroTargets(
        calorieTarget: Double,
        weighIns: [WeighIn],
        weightGoal: WeightGoal?,
        heightCentimetres: Double?,
        timeZone: TimeZone
    ) -> MacroTargets? {
        BodyView.trend(of: weighIns, in: timeZone).last.map {
            MacroTargets.suggested(
                calorieTarget: calorieTarget,
                trendWeight: $0.trendWeight,
                direction: weightGoal?.direction,
                heightCentimetres: heightCentimetres
            ).targets
        }
    }

    /// The marked Days that still have a Food Entry: what the store keeps after an entry is
    /// deleted or edited, so a Day whose last entry goes is no longer complete, even if an entry
    /// is added later (spec 016).
    public static func completeDays(
        _ marked: Set<Day>,
        keepingThoseWith foodEntries: [FoodEntry],
        in timeZone: TimeZone
    ) -> Set<Day> {
        marked.intersection(foodEntries.map { Day(containing: $0.time, in: timeZone) })
    }
}
