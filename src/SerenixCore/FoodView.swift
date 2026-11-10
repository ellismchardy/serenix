import Foundation

/// Everything the Body tab's Food view shows for one Day (spec 016), worked out from the stored
/// Food Entries each time, never stored (ADR 0008). The shell draws it.
public struct FoodView: Equatable, Sendable {
    /// The Day shown.
    public let day: Day
    /// The shown Day's Food Entries, newest first.
    public let entries: [FoodEntry]
    /// The positions in the `foodEntries` input of the shown Day's entries, newest first, in
    /// step with `entries`. Identical entries keep their own positions, so the shell finds each
    /// one's stored row by position.
    public let entryIndices: [Int]
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
    /// The user's Expenditure, kcal a Day; nil when there's no starting estimate (spec 017).
    public let expenditure: Double?
    /// Where Expenditure comes from; nil with no Expenditure.
    public let expenditureSource: ExpenditureSource?
    /// The Mifflin-St Jeor resting rate, kcal a Day; nil without height, birth year or Trend
    /// Weight.
    public let restingRate: Double?
    /// What the starting estimate lacks, in the order height, birth year, Weigh-in; empty when
    /// there is one.
    public let missingForExpenditure: [ExpenditureInput]

    /// Each Food Entry counts on the local Day of its time in `timeZone`, as Weigh-ins do.
    /// `completeDays` are the Days the user marked complete. Macro Targets use today's Trend
    /// Weight, worked out by the Body view from `weighIns`, so the two never disagree.
    public init(
        foodEntries: [FoodEntry],
        completeDays: Set<Day> = [],
        foodTargets: FoodTargets = FoodTargets(),
        weighIns: [WeighIn] = [],
        weightGoal: WeightGoal? = nil,
        heightCentimetres: Double? = nil,
        birthYear: Int? = nil,
        sex: Sex? = nil,
        day: Day,
        now: Date,
        timeZone: TimeZone
    ) {
        self.day = day
        let shown = foodEntries.indices
            .filter { Day(containing: foodEntries[$0].time, in: timeZone) == day }
            // Newest first; equal times keep their input order, so the result is fixed.
            .sorted {
                let (first, second) = (foodEntries[$0].time, foodEntries[$1].time)
                return first != second ? first > second : $0 < $1
            }
        entryIndices = shown
        entries = shown.map { foodEntries[$0] }
        intake = Intake(entries)
        canBeMarkedComplete = !entries.isEmpty
        isComplete = canBeMarkedComplete && completeDays.contains(day)
        let calorieTarget = foodTargets.calorieTarget
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
                proteinOverride: foodTargets.proteinOverride,
                fatOverride: foodTargets.fatOverride
            )
            macroTargets = suggested.targets
            macroWarning = suggested.warning
        } else {
            macroTargets = nil
            macroWarning = nil
        }
        needsWeighIn = calorieTarget != nil && trendWeight == nil
        // The starting estimate (spec 017): the resting rate times the Activity Level.
        var missing: [ExpenditureInput] = []
        if heightCentimetres == nil { missing.append(.height) }
        if birthYear == nil { missing.append(.birthYear) }
        if trendWeight == nil { missing.append(.weighIn) }
        missingForExpenditure = missing
        if let heightCentimetres, let birthYear, let trendWeight {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let resting = Expenditure.restingRate(
                trendWeight: trendWeight,
                heightCentimetres: heightCentimetres,
                age: calendar.component(.year, from: now) - birthYear,
                sex: sex
            )
            restingRate = resting
            expenditure = resting * (foodTargets.activityLevel ?? .light).factor
            expenditureSource = .profile
        } else {
            restingRate = nil
            expenditure = nil
            expenditureSource = nil
        }
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
