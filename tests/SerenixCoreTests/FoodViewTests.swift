import Foundation
import SerenixCore
import Testing

// A Day's Food Entries and Intake (spec 016, "Food Entries" and "Intake"). Expected values are
// spec 016's success criteria, worked by hand.

/// 1–5 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC then. In
/// October before the 25th London is on BST, one hour ahead of UTC.
private let london = TimeZone(identifier: "Europe/London")!

private let oct20 = Day(year: 2026, month: 10, day: 20)

private let oct21 = Day(year: 2026, month: 10, day: 21)

private let nov2 = Day(year: 2026, month: 11, day: 2)

/// `hour`:`minute` UTC on `month`/`day` 2026 (November by default, when it is also London
/// local time).
private func at(month: Int = 11, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(
        from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
    )!
}

/// 5 Nov 2026 09:00 in London, after every Food Entry here.
private let now = at(5, 9)

private func foodView(
    foodEntries: [FoodEntry],
    completeDays: Set<Day> = [],
    calorieTarget: Double? = nil,
    proteinOverride: Double? = nil,
    fatOverride: Double? = nil,
    weighIns: [WeighIn] = [],
    weightGoal: WeightGoal? = nil,
    heightCentimetres: Double? = nil,
    day: Day
) -> FoodView {
    FoodView(
        foodEntries: foodEntries,
        completeDays: completeDays,
        calorieTarget: calorieTarget,
        proteinOverride: proteinOverride,
        fatOverride: fatOverride,
        weighIns: weighIns,
        weightGoal: weightGoal,
        heightCentimetres: heightCentimetres,
        day: day,
        now: now,
        timeZone: london
    )
}

@Test func intakeAddsUpADaysFoodEntriesCountingABlankMacroAsZero() {
    let view = foodView(
        foodEntries: [
            FoodEntry(time: at(2, 8), kilocalories: 500, protein: 30),
            FoodEntry(time: at(2, 13), kilocalories: 700),
        ],
        day: nov2
    )

    #expect(view.day == nov2)
    #expect(view.intake == Intake(kilocalories: 1200, protein: 30, fat: 0, carbs: 0))
}

@Test func aDayWithNoFoodEntriesHasZeroIntake() {
    let view = foodView(foodEntries: [], day: nov2)

    #expect(view.entries.isEmpty)
    #expect(view.intake == Intake(kilocalories: 0, protein: 0, fat: 0, carbs: 0))
}

@Test func foodEntriesOnOtherDaysAreLeftOutOfTheShownDay() {
    let shown = FoodEntry(time: at(2, 12), kilocalories: 600, protein: 40, fat: 20, carbs: 50)
    let view = foodView(
        foodEntries: [
            FoodEntry(time: at(1, 19), kilocalories: 900, protein: 50, fat: 30, carbs: 80),
            shown,
            FoodEntry(time: at(3, 8), kilocalories: 400, protein: 10, fat: 5, carbs: 60),
        ],
        day: nov2
    )

    #expect(view.entries == [shown])
    #expect(view.intake == Intake(kilocalories: 600, protein: 40, fat: 20, carbs: 50))
}

@Test func aFoodEntryAtHalfPastElevenCountsOnThatDayAndOneAtHalfPastMidnightOnTheNext() {
    // 20 Oct 2026 is in BST (UTC+1): 23:30 local on the 20th is 22:30 UTC, and 00:30 local on
    // the 21st is 23:30 UTC on the 20th, so only local time puts it on the 21st.
    let lateEvening = FoodEntry(time: at(month: 10, 20, 22, 30), kilocalories: 300)
    let afterMidnight = FoodEntry(time: at(month: 10, 20, 23, 30), kilocalories: 200)
    let entries = [lateEvening, afterMidnight]

    let twentieth = foodView(foodEntries: entries, day: oct20)
    let twentyFirst = foodView(foodEntries: entries, day: oct21)

    #expect(twentieth.entries == [lateEvening])
    #expect(twentieth.intake.kilocalories == 300)
    #expect(twentyFirst.entries == [afterMidnight])
    #expect(twentyFirst.intake.kilocalories == 200)
}

@Test func aDaysFoodEntriesAreListedNewestFirst() {
    // Given out of time order, so neither input order nor its reverse is newest first.
    let breakfast = FoodEntry(time: at(2, 8), kilocalories: 400, name: "Porridge")
    let lunch = FoodEntry(time: at(2, 13), kilocalories: 650, name: "Sandwich")
    let dinner = FoodEntry(time: at(2, 19), kilocalories: 800, name: "Pasta")
    let view = foodView(foodEntries: [lunch, dinner, breakfast], day: nov2)

    #expect(view.entries == [dinner, lunch, breakfast])
}

// Food Entry limits (spec 016, "Food Entries" → "Limits").

/// 4 Nov 2026 12:00, before `now`.
private let lunchtime = at(4, 12)

@Test func aFoodEntryOf5000KcalIsAcceptedAndOneOf5001IsRefused() {
    #expect(FoodEntry(time: lunchtime, kilocalories: 5000).refusal(now: now) == nil)

    let refusal = FoodEntry(time: lunchtime, kilocalories: 5001).refusal(now: now)

    #expect(refusal == .tooManyCalories)
    #expect(refusal?.message == "A Food Entry can't be over 5,000 kcal.")
}

@Test func aFoodEntryOfZeroKcalIsAccepted() {
    #expect(FoodEntry(time: lunchtime, kilocalories: 0).refusal(now: now) == nil)
}

/// Which macro a limit test sets.
enum LimitedMacro: CaseIterable, Sendable {
    case protein, fat, carbs

    func entry(grams: Double) -> FoodEntry {
        switch self {
        case .protein: FoodEntry(time: lunchtime, kilocalories: 500, protein: grams)
        case .fat: FoodEntry(time: lunchtime, kilocalories: 500, fat: grams)
        case .carbs: FoodEntry(time: lunchtime, kilocalories: 500, carbs: grams)
        }
    }
}

@Test(arguments: LimitedMacro.allCases)
func aMacroOf500GIsAcceptedAndOneOf501GIsRefused(macro: LimitedMacro) {
    #expect(macro.entry(grams: 500).refusal(now: now) == nil)

    let refusal = macro.entry(grams: 501).refusal(now: now)

    #expect(refusal == .macroTooLarge)
    #expect(refusal?.message == "Protein, fat and carbs can't be over 500 g each.")
}

@Test func aFoodEntryBelowZeroKcalIsRefused() {
    let refusal = FoodEntry(time: lunchtime, kilocalories: -1).refusal(now: now)

    #expect(refusal == .negative)
    #expect(refusal?.message == "Calories and macros can't be below 0.")
}

@Test(arguments: LimitedMacro.allCases)
func aMacroBelowZeroGramsIsRefused(macro: LimitedMacro) {
    let refusal = macro.entry(grams: -1).refusal(now: now)

    #expect(refusal == .negative)
    #expect(refusal?.message == "Calories and macros can't be below 0.")
}

@Test func aNameOf40CharactersIsAcceptedAndOneOf41IsRefused() {
    let forty = String(repeating: "a", count: 40)
    let fortyOne = String(repeating: "a", count: 41)

    #expect(FoodEntry(time: lunchtime, kilocalories: 300, name: forty).refusal(now: now) == nil)

    let refusal = FoodEntry(time: lunchtime, kilocalories: 300, name: fortyOne).refusal(now: now)

    #expect(refusal == .nameTooLong)
    #expect(refusal?.message == "A name can't be over 40 characters.")
}

@Test func aFoodEntryAtNowIsAcceptedAndOneASecondLaterIsRefused() {
    #expect(FoodEntry(time: now, kilocalories: 300).refusal(now: now) == nil)

    let refusal = FoodEntry(time: now.addingTimeInterval(1), kilocalories: 300).refusal(now: now)

    #expect(refusal == .inTheFuture)
    #expect(refusal?.message == "A Food Entry can't be in the future.")
}

// Complete Days (spec 016, "Intake and Complete Days").

private let nov3 = Day(year: 2026, month: 11, day: 3)

@Test func aDayWithNoFoodEntriesCantBeMarkedCompleteAndIsNotCompleteEvenIfMarked() {
    let view = foodView(foodEntries: [], completeDays: [nov2], day: nov2)

    #expect(view.canBeMarkedComplete == false)
    #expect(view.isComplete == false)
}

@Test func aDayWithAFoodEntryCanBeMarkedCompleteAndIsCompleteOnlyOnceMarked() {
    let entries = [FoodEntry(time: at(2, 13), kilocalories: 650)]

    let marked = foodView(foodEntries: entries, completeDays: [nov2], day: nov2)
    let unmarked = foodView(foodEntries: entries, day: nov2)

    #expect(marked.canBeMarkedComplete == true)
    #expect(marked.isComplete == true)
    #expect(unmarked.canBeMarkedComplete == true)
    #expect(unmarked.isComplete == false)
}

@Test func deletingACompleteDaysLastFoodEntryLeavesItNotComplete() {
    // 3 Nov's last entry has been deleted: only 2 Nov still has one.
    let remaining = [FoodEntry(time: at(2, 13), kilocalories: 650)]

    let kept = FoodView.completeDays([nov2, nov3], keepingThoseWith: remaining, in: london)

    #expect(kept == [nov2])

    // A new entry on 3 Nov afterwards doesn't bring its old mark back.
    let laterEntry = FoodEntry(time: at(3, 19), kilocalories: 400)
    let view = foodView(foodEntries: remaining + [laterEntry], completeDays: kept, day: nov3)
    #expect(!view.isComplete)
}

@Test func editingACompleteDaysFoodEntryKeepsItComplete() {
    // The 2 Nov 13:00 entry of 650 kcal, edited to 18:00 and 720 kcal: still on 2 Nov.
    let edited = [FoodEntry(time: at(2, 18), kilocalories: 720, protein: 35)]

    let kept = FoodView.completeDays([nov2], keepingThoseWith: edited, in: london)
    let view = foodView(foodEntries: edited, completeDays: kept, day: nov2)

    #expect(kept == [nov2])
    #expect(view.isComplete == true)
}

@Test func aFoodEntryAtHalfPastMidnightLocalKeepsTheNextDayCompleteNotTheOneBefore() {
    // 20 Oct 2026 is in BST (UTC+1): 23:30 UTC on the 20th is 00:30 local on the 21st, so only
    // local time puts the entry on the 21st.
    let afterMidnight = [FoodEntry(time: at(month: 10, 20, 23, 30), kilocalories: 200)]

    let kept = FoodView.completeDays([oct20, oct21], keepingThoseWith: afterMidnight, in: london)

    #expect(kept == [oct21])
}

// Intake against the Calorie Target (spec 016, the Screen's "550 left" / "120 over").

@Test func intakeOf1450KcalAgainstACalorieTargetOf2000Shows550Left() {
    let view = foodView(
        foodEntries: [
            FoodEntry(time: at(2, 8), kilocalories: 450),
            FoodEntry(time: at(2, 13), kilocalories: 1000),
        ],
        calorieTarget: 2000,
        day: nov2
    )

    #expect(view.calorieTarget == 2000)
    #expect(view.calorieBalance == .left(550))
}

@Test func intakeOf2120KcalAgainstACalorieTargetOf2000Shows120Over() {
    let view = foodView(
        foodEntries: [
            FoodEntry(time: at(2, 8), kilocalories: 620),
            FoodEntry(time: at(2, 19), kilocalories: 1500),
        ],
        calorieTarget: 2000,
        day: nov2
    )

    #expect(view.calorieBalance == .over(120))
}

@Test func intakeEqualToTheCalorieTargetShowsNoneLeft() {
    let view = foodView(
        foodEntries: [FoodEntry(time: at(2, 13), kilocalories: 2000)],
        calorieTarget: 2000,
        day: nov2
    )

    #expect(view.calorieBalance == .left(0))
}

@Test func withNoCalorieTargetThereIsNoTargetAndNothingLeftOrOver() {
    let view = foodView(
        foodEntries: [FoodEntry(time: at(2, 13), kilocalories: 1450)],
        day: nov2
    )

    #expect(view.calorieTarget == nil)
    #expect(view.calorieBalance == nil)
}

// Macro Targets (spec 016, "Macro Targets"). Protein 2.2 g/kg losing, else 1.6 g/kg; fat 25% of
// the Calorie Target at 9 kcal/g; carbs what's left at 4 kcal/g. Worked by hand.

/// Whether `actual` is within 1e-9 of `expected`.
private func isClose(_ actual: Double?, _ expected: Double) -> Bool {
    guard let actual else { return false }
    return abs(actual - expected) < 1e-9
}

/// One Weigh-in this morning, so today's Trend Weight is exactly `kilograms`.
private func weighInToday(_ kilograms: Double) -> [WeighIn] {
    [WeighIn(time: at(5, 7), kilograms: kilograms)]
}

private let losing = WeightGoal(startWeight: 90.0, startDay: oct20, goalWeight: 75.0, pace: nil)

private let gaining = WeightGoal(startWeight: 70.0, startDay: oct20, goalWeight: 85.0, pace: nil)

private let holding = WeightGoal.hold(at: 80.0, on: oct20)

/// The Food view for 2 Nov with `weighIns`, `weightGoal`, height and Calorie Target.
private func macroView(
    calorieTarget: Double? = 2000,
    proteinOverride: Double? = nil,
    fatOverride: Double? = nil,
    weighIns: [WeighIn],
    weightGoal: WeightGoal?,
    heightCentimetres: Double? = nil
) -> FoodView {
    foodView(
        foodEntries: [],
        calorieTarget: calorieTarget,
        proteinOverride: proteinOverride,
        fatOverride: fatOverride,
        weighIns: weighIns,
        weightGoal: weightGoal,
        heightCentimetres: heightCentimetres,
        day: nov2
    )
}

@Test func losingAt80KgWithACalorieTargetOf2000Suggests176GProtein55Point6GFatAnd199GCarbs() {
    let targets = macroView(weighIns: weighInToday(80.0), weightGoal: losing).macroTargets

    // Protein 2.2 × 80 = 176 g (704 kcal); fat 25% × 2000 = 500 kcal / 9 = 55.555… g;
    // carbs (2000 − 704 − 500) / 4 = 199 g.
    #expect(isClose(targets?.protein, 176))
    #expect(isClose(targets?.fat, 55.555_555_555_555_556))
    #expect(isClose(targets?.carbs, 199))
}

@Test func losingAt80KgWithACalorieTargetOf2000HasNoMacroWarning() {
    let view = macroView(weighIns: weighInToday(80.0), weightGoal: losing)

    #expect(view.macroWarning == nil)
    #expect(view.needsWeighIn == false)
}

@Test func gainingAt80KgWithACalorieTargetOf2000Suggests128GProtein55Point6GFatAnd247GCarbs() {
    let targets = macroView(weighIns: weighInToday(80.0), weightGoal: gaining).macroTargets

    // Protein 1.6 × 80 = 128 g (512 kcal); fat 500 kcal / 9 = 55.555… g;
    // carbs (2000 − 512 − 500) / 4 = 247 g.
    #expect(isClose(targets?.protein, 128))
    #expect(isClose(targets?.fat, 55.555_555_555_555_556))
    #expect(isClose(targets?.carbs, 247))
}

@Test func holdingOrNoWeightGoalAt80KgSuggests128GProteinAnd247GCarbs() {
    // Protein 1.6 × 80 = 128 g; carbs (2000 − 512 − 500) / 4 = 247 g, as for gaining.
    for goal in [holding, nil] {
        let targets = macroView(weighIns: weighInToday(80.0), weightGoal: goal).macroTargets

        #expect(isClose(targets?.protein, 128))
        #expect(isClose(targets?.carbs, 247))
    }
}

@Test func losingAt100KgAnd175CmTakesProteinFromTheWeightAtBMI25() {
    // BMI 100 / 1.75² = 32.65, over 30, so the kg is 25 × 1.75² = 76.5625:
    // protein 2.2 × 76.5625 = 168.4375 g.
    let targets = macroView(
        weighIns: weighInToday(100.0),
        weightGoal: losing,
        heightCentimetres: 175
    ).macroTargets

    #expect(isClose(targets?.protein, 168.4375))
}

@Test func losingAt100KgWithNoHeightTakesProteinFromTrendWeight() {
    // Protein 2.2 × 100 = 220 g.
    let targets = macroView(weighIns: weighInToday(100.0), weightGoal: losing).macroTargets

    #expect(isClose(targets?.protein, 220))
}

@Test func losingAt80KgWithACalorieTargetOf1500GivesCarbsUnder130GAndWarns() {
    let view = macroView(calorieTarget: 1500, weighIns: weighInToday(80.0), weightGoal: losing)

    // Protein 176 g = 704 kcal; fat 25% × 1500 = 375 kcal; carbs (1500 − 704 − 375) / 4 = 105.25 g.
    #expect(isClose(view.macroTargets?.carbs, 105.25))
    #expect(view.macroWarning == .lowCarbs)
}

@Test func whenProteinAndFatUseUpTheCalorieTargetCarbsAreZeroAndTheFoodViewSaysSo() {
    let view = macroView(calorieTarget: 1000, weighIns: weighInToday(100.0), weightGoal: losing)

    // Protein 2.2 × 100 = 220 g = 880 kcal; fat 250 kcal; (1000 − 880 − 250) / 4 = −32.5 → 0 g.
    #expect(isClose(view.macroTargets?.carbs, 0))
    #expect(view.macroWarning == .noCarbsLeft)
}

@Test func withNoWeighInsThereAreNoMacroTargetsAndTheFoodViewSaysAWeighInIsNeeded() {
    let view = macroView(weighIns: [], weightGoal: losing)

    #expect(view.macroTargets == nil)
    #expect(view.needsWeighIn == true)
}

@Test func withNoCalorieTargetThereAreNoMacroTargetsAndNoWeighInIsAskedFor() {
    let view = macroView(calorieTarget: nil, weighIns: weighInToday(80.0), weightGoal: losing)

    #expect(view.macroTargets == nil)
    #expect(view.needsWeighIn == false)
}

// Overrides (spec 016, "Macro Targets" → Overrides). 80 kg Trend Weight, losing, Calorie Target
// 2,000: suggested protein 176 g, fat 500 / 9 g, carbs 199 g. Worked by hand.

@Test func overridingProteinTo150GAndFatTo70GAtACalorieTargetOf2000GivesCarbs192Point5G() {
    let targets = macroView(
        proteinOverride: 150,
        fatOverride: 70,
        weighIns: weighInToday(80.0),
        weightGoal: losing
    ).macroTargets

    // 150 × 4 = 600 kcal; 70 × 9 = 630 kcal; (2000 − 600 − 630) / 4 = 770 / 4 = 192.5 g.
    #expect(isClose(targets?.protein, 150))
    #expect(isClose(targets?.fat, 70))
    #expect(isClose(targets?.carbs, 192.5))
}

@Test func overridingOnlyProteinKeepsTheSuggestedFat() {
    let targets = macroView(
        proteinOverride: 150,
        weighIns: weighInToday(80.0),
        weightGoal: losing
    ).macroTargets

    // Fat stays 500 / 9 g (500 kcal); carbs (2000 − 600 − 500) / 4 = 900 / 4 = 225 g.
    #expect(isClose(targets?.protein, 150))
    #expect(isClose(targets?.fat, 55.555_555_555_555_556))
    #expect(isClose(targets?.carbs, 225))
}

@Test func overridingOnlyFatKeepsTheSuggestedProtein() {
    let targets = macroView(
        fatOverride: 70,
        weighIns: weighInToday(80.0),
        weightGoal: losing
    ).macroTargets

    // Protein stays 2.2 × 80 = 176 g (704 kcal); carbs (2000 − 704 − 630) / 4 = 666 / 4 = 166.5 g.
    #expect(isClose(targets?.protein, 176))
    #expect(isClose(targets?.fat, 70))
    #expect(isClose(targets?.carbs, 166.5))
}

@Test func withNoOverridesTheMacroTargetsAreTheSuggestions() {
    let overridden = macroView(
        proteinOverride: 150,
        fatOverride: 70,
        weighIns: weighInToday(80.0),
        weightGoal: losing
    )
    let suggested = macroView(
        proteinOverride: nil,
        fatOverride: nil,
        weighIns: weighInToday(80.0),
        weightGoal: losing
    )

    #expect(isClose(overridden.macroTargets?.protein, 150))
    // Back to 176 g protein, 500 / 9 = 55.555… g fat, 199 g carbs.
    #expect(isClose(suggested.macroTargets?.protein, 176))
    #expect(isClose(suggested.macroTargets?.fat, 55.555_555_555_555_556))
    #expect(isClose(suggested.macroTargets?.carbs, 199))
}

@Test func anOverrideLeavingCarbsBelowZeroIsRefused() {
    // 300 × 4 + 100 × 9 = 1200 + 900 = 2100 kcal, over 2000.
    let refusal = MacroTargets.overrideRefusal(protein: 300, fat: 100, calorieTarget: 2000)

    #expect(refusal == .noCarbsLeft)
    #expect(refusal?.message == "That leaves no room for carbs at this Calorie Target.")
}

@Test func overridesOf150GProteinAnd70GFatAtACalorieTargetOf2000AreAccepted() {
    // 600 + 630 = 1230 kcal, under 2000.
    #expect(MacroTargets.overrideRefusal(protein: 150, fat: 70, calorieTarget: 2000) == nil)
}

@Test func overridesThatUseUpTheCalorieTargetExactlyAreAccepted() {
    // 275 × 4 + 100 × 9 = 1100 + 900 = 2000 kcal: carbs 0 g, not below 0.
    #expect(MacroTargets.overrideRefusal(protein: 275, fat: 100, calorieTarget: 2000) == nil)
}

@Test func anOverrideBelowZeroGramsIsRefused() {
    let refusal = MacroTargets.overrideRefusal(protein: -1, fat: 70, calorieTarget: 2000)

    #expect(refusal == .negative)
    #expect(refusal?.message == "Protein and fat can't be below 0.")
}

@Test(arguments: [(501.0, 70.0), (150.0, 501.0)])
func anOverrideOver500GIsRefused(protein: Double, fat: Double) {
    let refusal = MacroTargets.overrideRefusal(protein: protein, fat: fat, calorieTarget: 2000)

    #expect(refusal == .tooLarge)
    #expect(refusal?.message == "Protein and fat can't be over 500 g each.")
}

// Override checks while the user types in the targets sheet (spec 016, "Macro Targets" →
// Overrides). An unset override (nil) means the suggestion. Worked by hand.

/// The suggestion at 80 kg, losing, Calorie Target 2,000: protein 176 g, fat 500 / 9 g, carbs 199 g.
private let suggestedAt80KgLosing = MacroTargets(protein: 176, fat: 500.0 / 9.0, carbs: 199)

@Test func theTargetsSheetSuggestsMacroTargetsFromTodaysTrendWeight() {
    let targets = FoodView.suggestedMacroTargets(
        calorieTarget: 2000,
        weighIns: weighInToday(80.0),
        weightGoal: losing,
        heightCentimetres: nil,
        timeZone: london
    )

    // Protein 2.2 × 80 = 176 g; fat 500 / 9 g; carbs (2000 − 704 − 500) / 4 = 199 g.
    #expect(isClose(targets?.protein, 176))
    #expect(isClose(targets?.fat, 55.555_555_555_555_556))
    #expect(isClose(targets?.carbs, 199))
}

@Test func withNoWeighInsTheTargetsSheetHasNoSuggestedMacroTargets() {
    let targets = FoodView.suggestedMacroTargets(
        calorieTarget: 2000,
        weighIns: [],
        weightGoal: losing,
        heightCentimetres: nil,
        timeZone: london
    )

    #expect(targets == nil)
}

@Test func withNoCalorieTargetAnOverrideBelowZeroIsStillRefused() {
    let refusal = MacroTargets.overrideRefusal(
        proteinOverride: -5,
        fatOverride: nil,
        calorieTarget: nil,
        suggested: nil
    )

    #expect(refusal == .negative)
}

@Test(arguments: [(9_999.0, nil), (nil, 501.0)] as [(Double?, Double?)])
func withNoCalorieTargetAnOverrideOver500GIsStillRefused(protein: Double?, fat: Double?) {
    let refusal = MacroTargets.overrideRefusal(
        proteinOverride: protein,
        fatOverride: fat,
        calorieTarget: nil,
        suggested: nil
    )

    #expect(refusal == .tooLarge)
}

@Test func withNoCalorieTargetAnOverrideWithinTheLimitsIsAccepted() {
    let refusal = MacroTargets.overrideRefusal(
        proteinOverride: 150,
        fatOverride: nil,
        calorieTarget: nil,
        suggested: nil
    )

    #expect(refusal == nil)
}

@Test func withNoSuggestionOneOverrideHasNothingToCheckCarbsAgainstAndIsAccepted() {
    let refusal = MacroTargets.overrideRefusal(
        proteinOverride: 150,
        fatOverride: nil,
        calorieTarget: 2000,
        suggested: nil
    )

    #expect(refusal == nil)
}

@Test func withNoSuggestionBothOverridesLeavingCarbsBelowZeroAreRefused() {
    // 300 × 4 + 100 × 9 = 1200 + 900 = 2100 kcal, over 2000.
    let refusal = MacroTargets.overrideRefusal(
        proteinOverride: 300,
        fatOverride: 100,
        calorieTarget: 2000,
        suggested: nil
    )

    #expect(refusal == .noCarbsLeft)
}

@Test func aProteinOverrideIsCheckedWithTheSuggestedFatAndAcceptedWhenCarbsAreLeft() {
    // Fat filled from the suggestion, 500 / 9 g = 500 kcal: 300 × 4 + 500 = 1700 kcal, under 2000.
    let refusal = MacroTargets.overrideRefusal(
        proteinOverride: 300,
        fatOverride: nil,
        calorieTarget: 2000,
        suggested: suggestedAt80KgLosing
    )

    #expect(refusal == nil)
}

@Test func aProteinOverrideIsCheckedWithTheSuggestedFatAndRefusedWhenCarbsGoBelowZero() {
    // Fat filled from the suggestion, 500 kcal: 400 × 4 + 500 = 1600 + 500 = 2100 kcal, over 2000.
    let refusal = MacroTargets.overrideRefusal(
        proteinOverride: 400,
        fatOverride: nil,
        calorieTarget: 2000,
        suggested: suggestedAt80KgLosing
    )

    #expect(refusal == .noCarbsLeft)
}

@Test func withNoOverridesThereIsNothingToRefuse() {
    let refusal = MacroTargets.overrideRefusal(
        proteinOverride: nil,
        fatOverride: nil,
        calorieTarget: 2000,
        suggested: suggestedAt80KgLosing
    )

    #expect(refusal == nil)
}
