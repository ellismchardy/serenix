import Foundation
import SerenixCore
import Testing

// A Food Entry's limits (spec 016, "Food Entries" → "Limits"). Expected values are spec
// 016's success criteria.

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
