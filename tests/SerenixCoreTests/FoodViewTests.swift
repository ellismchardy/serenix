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

private func foodView(
    foodEntries: [FoodEntry],
    completeDays: Set<Day> = [],
    calorieTarget: Double? = nil,
    day: Day
) -> FoodView {
    FoodView(
        foodEntries: foodEntries,
        completeDays: completeDays,
        foodTargets: FoodTargets(calorieTarget: calorieTarget),
        day: day,
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

// Which input Food Entries the Food view shows, so the shell can find each one's stored row.

@Test func theFoodViewGivesTheInputPositionsOfTheShownDaysEntriesNewestFirst() {
    let lunch = FoodEntry(time: at(2, 13), kilocalories: 650, name: "Sandwich")
    let nextDay = FoodEntry(time: at(3, 12), kilocalories: 500, name: "Soup")
    let dinner = FoodEntry(time: at(2, 19), kilocalories: 800, name: "Pasta")
    let breakfast = FoodEntry(time: at(2, 8), kilocalories: 400, name: "Porridge")
    let input = [lunch, nextDay, dinner, breakfast]

    let view = foodView(foodEntries: input, day: nov2)

    // Dinner (2), lunch (0), breakfast (3); the 3 Nov entry (1) isn't shown.
    #expect(view.entryIndices == [2, 0, 3])
    #expect(view.entries == [dinner, lunch, breakfast])
    #expect(view.entryIndices.map { input[$0] } == view.entries)
}

@Test func identicalFoodEntriesEachKeepTheirOwnInputPosition() {
    let entry = FoodEntry(time: at(2, 13), kilocalories: 650, protein: 30, name: "Sandwich")

    let view = foodView(foodEntries: [entry, entry], day: nov2)

    #expect(view.entryIndices.count == 2)
    #expect(Set(view.entryIndices) == [0, 1])
    // Same time, so input order decides: a fixed order, not one that can swap between draws.
    #expect(view.entryIndices == [0, 1])
}

@Test func aDayWithNoFoodEntriesShowsNoInputPositions() {
    let view = foodView(
        foodEntries: [FoodEntry(time: at(3, 12), kilocalories: 500)],
        day: nov2
    )

    #expect(view.entryIndices.isEmpty)
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
