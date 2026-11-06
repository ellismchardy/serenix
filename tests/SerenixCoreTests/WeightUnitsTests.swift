import Foundation
import SerenixCore
import Testing

// Spec 015, "Units and Profile" and "Weigh-ins": weights show to one decimal in the user's Units
// and are stored in kg; Height shows in cm or ft and in. Every expected value below is worked by
// hand from 1 lb = 0.45359237 kg (1959 international pound), 1 st = 14 lb and
// 1 in = 2.54 cm (1959 international inch).

// MARK: - Text in the user's locale

@Test func aWeightUsesTheLocalesDecimalSeparator() {
    let german = Locale(identifier: "de_DE")

    #expect(WeightUnits.kilograms.text(82.4, locale: german) == "82,4 kg")
    // 82.4 / 0.45359237 = 181.6609… lb → 181.7 lb = 12 st 13.7 lb.
    #expect(WeightUnits.pounds.text(82.4, locale: german) == "181,7 lb")
    #expect(WeightUnits.stonesAndPounds.text(82.4, locale: german) == "12 st 13,7 lb")
}

@Test func aWeightNeverShowsAGroupingSeparator() {
    let british = Locale(identifier: "en_GB")

    // 350 / 0.45359237 = 771.6179… lb → 771.6 lb.
    #expect(WeightUnits.pounds.text(350, locale: british) == "771.6 lb")
    // 1000 kg would read "1,000.0 kg" with grouping.
    #expect(WeightUnits.kilograms.text(1000, locale: british) == "1000.0 kg")
}

@Test func theLocalelessTextStillUsesAPoint() {
    #expect(WeightUnits.kilograms.text(82.4) == "82.4 kg")
}

// MARK: - Chart values

@Test func theChartPlotsKilogramsInKilogramUnits() {
    #expect(WeightUnits.kilograms.chartValue(82.4) == 82.4)
}

@Test(arguments: [WeightUnits.pounds, .stonesAndPounds])
func theChartPlotsTotalPoundsInPoundAndStoneUnits(units: WeightUnits) {
    // 82.4 / 0.45359237 = 181.660904040339… lb, unrounded.
    #expect(abs(units.chartValue(82.4) - 181.660904040339) < 1e-9)
}

// MARK: - Weigh-in sheet fields

@Test func aWeighInSheetFillsInKilogramsToOneDecimal() {
    #expect(WeightUnits.kilograms.fields(82.4) == WeightFields(stones: nil, rest: 82.4))
}

@Test func aWeighInSheetFillsInPoundsToOneDecimal() {
    // 82.4 / 0.45359237 = 181.6609… lb → 181.7.
    #expect(WeightUnits.pounds.fields(82.4) == WeightFields(stones: nil, rest: 181.7))
}

@Test func aWeighInSheetFillsInStonesAndThePoundsLeftOver() {
    // 181.7 lb = 12 × 14 (168) + 13.7 lb.
    #expect(WeightUnits.stonesAndPounds.fields(82.4) == WeightFields(stones: 12, rest: 13.7))
}

@Test func aWeighInSheetNeverFillsInFourteenPoundsOverWholeStones() {
    // 88.89 / 0.45359237 = 195.9689… lb → 196.0 lb = 14 st 0.0 lb, never 13 st 14.0 lb.
    #expect(WeightUnits.stonesAndPounds.fields(88.89) == WeightFields(stones: 14, rest: 0.0))
}

@Test func stonesAndPoundsEnteredOnAWeighInSheetAreStoredInKilograms() {
    // (12 × 14 + 13.7) lb = 181.7 lb; 181.7 × 0.45359237 = 82.417733629 kg.
    let kilograms = WeightUnits.stonesAndPounds.kilograms(WeightFields(stones: 12, rest: 13.7))

    #expect(abs(kilograms - 82.417733629) < 1e-9)
}

@Test func poundsEnteredOnAWeighInSheetAreStoredInKilograms() {
    // 181.7 × 0.45359237 = 82.417733629 kg.
    let kilograms = WeightUnits.pounds.kilograms(WeightFields(stones: nil, rest: 181.7))

    #expect(abs(kilograms - 82.417733629) < 1e-9)
}

@Test func kilogramsEnteredOnAWeighInSheetAreStoredAsEntered() {
    #expect(WeightUnits.kilograms.kilograms(WeightFields(stones: nil, rest: 82.4)) == 82.4)
}

// MARK: - Refusal messages

@Test func aTooLightWeighInIsRefusedInTheUsersUnits() {
    #expect(WeighInRefusal.tooLight.message(in: .kilograms) == "A Weigh-in can't be under 20.0 kg.")
    // 20 / 0.45359237 = 44.0924… lb → 44.1 lb.
    #expect(WeighInRefusal.tooLight.message(in: .pounds) == "A Weigh-in can't be under 44.1 lb.")
    // 44.1 lb = 3 × 14 (42) + 2.1 lb.
    #expect(
        WeighInRefusal.tooLight.message(in: .stonesAndPounds)
            == "A Weigh-in can't be under 3 st 2.1 lb."
    )
}

@Test func aTooHeavyWeighInIsRefusedInTheUsersUnits() {
    #expect(WeighInRefusal.tooHeavy.message(in: .kilograms) == "A Weigh-in can't be over 350.0 kg.")
    // 350 / 0.45359237 = 771.6179… lb → 771.6 lb.
    #expect(WeighInRefusal.tooHeavy.message(in: .pounds) == "A Weigh-in can't be over 771.6 lb.")
    // 771.6 lb = 55 × 14 (770) + 1.6 lb.
    #expect(
        WeighInRefusal.tooHeavy.message(in: .stonesAndPounds)
            == "A Weigh-in can't be over 55 st 1.6 lb."
    )
}

@Test(arguments: WeightUnits.allCases)
func aFutureWeighInIsRefusedTheSameWayInAnyUnits(units: WeightUnits) {
    #expect(WeighInRefusal.inTheFuture.message(in: units) == "A Weigh-in can't be in the future.")
}

// MARK: - Height

@Test func heightShowsInWholeCentimetresInKilogramUnits() {
    #expect(Height.text(centimetres: 180, units: .kilograms) == "180 cm")
}

@Test(arguments: [WeightUnits.pounds, .stonesAndPounds])
func heightShowsInFeetAndInchesInPoundAndStoneUnits(units: WeightUnits) {
    // 182.88 cm / 2.54 = 72 in = 6 ft 0 in.
    #expect(Height.text(centimetres: 182.88, units: units) == "6 ft 0 in")
}

@Test func heightCanBePickedFrom120To230CentimetresByOne() {
    let options = Height.options(units: .kilograms)

    #expect(options.first == 120)
    #expect(options.last == 230)
    #expect(options.count == 111)
}

@Test func heightCanBePickedInWholeInchesFrom4To7Point5Feet() {
    let options = Height.options(units: .pounds)

    // 48 in × 2.54 = 121.92 cm; 90 in × 2.54 = 228.6 cm; 48...90 is 43 whole inches.
    #expect(abs((options.first ?? 0) - 121.92) < 1e-9)
    #expect(abs((options.last ?? 0) - 228.6) < 1e-9)
    #expect(options.count == 43)
}

@Test func noTwoHeightOptionsInFeetAndInchesReadTheSame() {
    let texts = Height.options(units: .pounds).map { Height.text(centimetres: $0, units: .pounds) }

    #expect(Set(texts).count == texts.count)
}

@Test func aWeeklyRateShowsItsSignAndUnitsAWeek() {
    let posix = Locale(identifier: "en_US_POSIX")
    #expect(WeightUnits.kilograms.rateText(-0.5217031, locale: posix) == "−0.5 kg a week")
    #expect(WeightUnits.kilograms.rateText(0.24, locale: posix) == "+0.2 kg a week")
    // −0.5217031 kg / 0.45359237 = −1.150159… lb; stones show the rate in lb, not "0 st 1.2 lb".
    #expect(WeightUnits.stonesAndPounds.rateText(-0.5217031, locale: posix) == "−1.2 lb a week")
    #expect(WeightUnits.pounds.rateText(-0.5217031, locale: posix) == "−1.2 lb a week")
}

@Test func aWeeklyRateThatRoundsToZeroShowsNoSign() {
    let posix = Locale(identifier: "en_US_POSIX")
    #expect(WeightUnits.kilograms.rateText(-0.04, locale: posix) == "0.0 kg a week")
}
