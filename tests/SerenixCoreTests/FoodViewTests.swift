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
    day: Day
) -> FoodView {
    FoodView(
        foodEntries: foodEntries,
        completeDays: completeDays,
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
