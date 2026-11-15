import SerenixCore
import Testing

// The Calorie Target's limits (spec 016, "Calorie Target"): 800 to 6,000 kcal a Day.

@Test func aCalorieTargetOf799KcalIsRefusedAsTooLow() {
    let refusal = CalorieTarget.refusal(799)

    #expect(refusal == .tooLow)
    #expect(refusal?.message == "A Calorie Target can't be under 800 kcal.")
}

@Test func aCalorieTargetOf6001KcalIsRefusedAsTooHigh() {
    let refusal = CalorieTarget.refusal(6001)

    #expect(refusal == .tooHigh)
    #expect(refusal?.message == "A Calorie Target can't be over 6,000 kcal.")
}

@Test func calorieTargetsOf800And6000KcalAreAccepted() {
    #expect(CalorieTarget.refusal(800) == nil)
    #expect(CalorieTarget.refusal(6000) == nil)
}
