import SerenixCore
import Testing

private let greeting: [Onboarding.Bubble] = [
    .init(
        .serenix,
        "Hi! I'm Serenix. I read your Whoop Strap over Bluetooth and work out your sleep, Readiness and Load — all on this phone."
    ),
    .init(.serenix, "Serenix isn't affiliated with WHOOP, Inc."),
    .init(.serenix, "What should I call you?"),
]

private let pairPrompt = Onboarding.Bubble(
    .serenix,
    "Last thing: let's find your Strap. Put it on and keep your phone close."
)

private let birthYearQuestion = Onboarding.Bubble(
    .serenix,
    "What year were you born? It sets how much sleep you need and estimates your Max HR."
)

private let birthYearControls = Onboarding.Controls(
    field: .number,
    placeholder: "e.g. 1992",
    chips: [.ratherNot]
)

private let sexQuestion = Onboarding.Bubble(
    .serenix,
    "Which sex should I use for heart-rate calculations?"
)

private let sexControls = Onboarding.Controls(
    field: nil,
    placeholder: nil,
    chips: [.female, .male, .preferNotToSay]
)

private let maxHRQuestion = Onboarding.Bubble(.serenix, "Do you know your Max HR from a test?")

private let maxHRControls = Onboarding.Controls(
    field: .number,
    placeholder: "e.g. 185",
    chips: [.dontKnow]
)

private let birthYearRetry = Onboarding.Bubble(.serenix, "I didn't get that — a year like 1992?")

private let maxHRRetry = Onboarding.Bubble(
    .serenix,
    "I didn't get that — a number of beats per minute, like 185?"
)

private func walkToTheBirthYearQuestion(_ onboarding: inout Onboarding) {
    _ = onboarding.handle(.submitted("Ellis"))
}

private func walkToTheSexQuestion(_ onboarding: inout Onboarding) {
    walkToTheBirthYearQuestion(&onboarding)
    _ = onboarding.handle(.chipTapped(.ratherNot))
}

private func walkToTheMaxHRQuestion(_ onboarding: inout Onboarding) {
    walkToTheSexQuestion(&onboarding)
    _ = onboarding.handle(.chipTapped(.preferNotToSay))
}

private func walkToThePairStep(_ onboarding: inout Onboarding) {
    walkToTheMaxHRQuestion(&onboarding)
    _ = onboarding.handle(.chipTapped(.dontKnow))
}

@Test func aFreshConversationGreetsAndAsksForTheName() {
    let onboarding = Onboarding(currentYear: 2026)
    #expect(onboarding.bubbles == greeting)
    #expect(
        onboarding.controls
            == Onboarding.Controls(field: .name, placeholder: "Your name", chips: [.skip])
    )
    #expect(onboarding.isFinished == false)
}

@Test func submittingANameTrimsItAndGreetsTheUserByName() {
    var onboarding = Onboarding(currentYear: 2026)
    let change = onboarding.handle(.submitted("  Ellis "))
    #expect(change == .name("Ellis"))
    #expect(
        onboarding.bubbles
            == greeting + [
                .init(.user, "Ellis"),
                .init(.serenix, "Nice to meet you, Ellis."),
                birthYearQuestion,
            ]
    )
}

@Test func skippingTheNameClearsItAndGreetsWithoutAName() {
    var onboarding = Onboarding(currentYear: 2026)
    let change = onboarding.handle(.chipTapped(.skip))
    #expect(change == .name(nil))
    #expect(onboarding.isFinished == false)
    #expect(
        onboarding.bubbles
            == greeting + [
                .init(.user, "Skip"),
                .init(.serenix, "Nice to meet you."),
                birthYearQuestion,
            ]
    )
}

@Test func submittingABlankNameIsTreatedAsSkip() {
    var onboarding = Onboarding(currentYear: 2026)
    let change = onboarding.handle(.submitted("   "))
    #expect(change == .name(nil))
    #expect(
        onboarding.bubbles
            == greeting + [
                .init(.user, "Skip"),
                .init(.serenix, "Nice to meet you."),
                birthYearQuestion,
            ]
    )
}

@Test func thePairStepOffersSetUpLaterAndNoTextField() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToThePairStep(&onboarding)
    #expect(onboarding.controls.field == nil)
    #expect(onboarding.controls.placeholder == nil)
    #expect(onboarding.controls.chips.contains(.setUpLater))
    #expect(Onboarding.Chip.setUpLater.label == "Set up later")
    #expect(onboarding.isFinished == false)
}

@Test func tappingSetUpLaterFinishesOnboarding() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToThePairStep(&onboarding)
    let change = onboarding.handle(.chipTapped(.setUpLater))
    #expect(change == nil)
    #expect(onboarding.isFinished == true)
}

@Test func aNewUserHasNotFinishedOnboarding() {
    #expect(
        Onboarding.isFinished(
            finishedFlag: false,
            namePromptAnswered: false,
            historySyncCompleted: false
        ) == false
    )
}

@Test func onboardingIsFinishedOnceTheFlagIsSet() {
    #expect(
        Onboarding.isFinished(
            finishedFlag: true,
            namePromptAnswered: false,
            historySyncCompleted: false
        ) == true
    )
}

@Test func anExistingUserWhoAnsweredTheNamePromptSkipsOnboarding() {
    #expect(
        Onboarding.isFinished(
            finishedFlag: false,
            namePromptAnswered: true,
            historySyncCompleted: false
        ) == true
    )
}

@Test func anExistingUserWhoHasSyncedSkipsOnboarding() {
    #expect(
        Onboarding.isFinished(
            finishedFlag: false,
            namePromptAnswered: false,
            historySyncCompleted: true
        ) == true
    )
}

@Test func afterTheNameSerenixAsksForTheBirthYear() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToTheBirthYearQuestion(&onboarding)
    #expect(onboarding.bubbles.last == birthYearQuestion)
    #expect(onboarding.controls == birthYearControls)
    #expect(Onboarding.Chip.ratherNot.label == "Rather not")
    #expect(onboarding.isFinished == false)
}

@Test(arguments: [("1992", 1992), ("1926", 1926), ("2013", 2013), (" 1992 ", 1992)])
func aBirthYearAged13To100IsSavedAndSerenixAsksForSex(typed: String, year: Int) {
    var onboarding = Onboarding(currentYear: 2026)
    walkToTheBirthYearQuestion(&onboarding)
    let before = onboarding.bubbles
    let change = onboarding.handle(.submitted(typed))
    #expect(change == .birthYear(year))
    #expect(onboarding.bubbles == before + [.init(.user, String(year)), sexQuestion])
    #expect(onboarding.controls == sexControls)
    #expect(onboarding.isFinished == false)
}

@Test(arguments: [("1925", "1925"), ("2014", "2014"), ("abc", "abc"), (" 1925 ", "1925")])
func anUnusableBirthYearIsAskedAgain(typed: String, shown: String) {
    var onboarding = Onboarding(currentYear: 2026)
    walkToTheBirthYearQuestion(&onboarding)
    let before = onboarding.bubbles
    let change = onboarding.handle(.submitted(typed))
    #expect(change == nil)
    #expect(onboarding.bubbles == before + [.init(.user, shown), birthYearRetry])
    #expect(onboarding.controls == birthYearControls)
    #expect(onboarding.isFinished == false)
}

@Test func ratherNotClearsTheBirthYearAndSerenixAsksForSex() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToTheBirthYearQuestion(&onboarding)
    let before = onboarding.bubbles
    let change = onboarding.handle(.chipTapped(.ratherNot))
    #expect(change == .birthYear(nil))
    #expect(onboarding.bubbles == before + [.init(.user, "Rather not"), sexQuestion])
    #expect(onboarding.controls == sexControls)
}

@Test(arguments: [
    (Onboarding.Chip.female, Sex.female, "Female"),
    (Onboarding.Chip.male, Sex.male, "Male"),
    (Onboarding.Chip.preferNotToSay, Sex.preferNotToSay, "Prefer not to say"),
])
func eachSexChipSavesThatSexAndSerenixAsksForMaxHR(
    chip: Onboarding.Chip,
    sex: Sex,
    label: String
) {
    var onboarding = Onboarding(currentYear: 2026)
    walkToTheSexQuestion(&onboarding)
    let before = onboarding.bubbles
    let change = onboarding.handle(.chipTapped(chip))
    #expect(chip.label == label)
    #expect(change == .sex(sex))
    #expect(onboarding.bubbles == before + [.init(.user, label), maxHRQuestion])
    #expect(onboarding.controls == maxHRControls)
    #expect(onboarding.isFinished == false)
}

@Test(arguments: [("185", 185), ("100", 100), ("230", 230)])
func aMaxHRFrom100To230IsSavedAndSerenixMovesToThePairStep(typed: String, bpm: Int) {
    var onboarding = Onboarding(currentYear: 2026)
    walkToTheMaxHRQuestion(&onboarding)
    let before = onboarding.bubbles
    let change = onboarding.handle(.submitted(typed))
    #expect(change == .maxHR(bpm))
    #expect(onboarding.bubbles == before + [.init(.user, String(bpm)), pairPrompt])
    #expect(onboarding.controls.chips.contains(.setUpLater))
    #expect(onboarding.isFinished == false)
}

@Test(arguments: ["99", "231", "abc"])
func anUnusableMaxHRIsAskedAgain(typed: String) {
    var onboarding = Onboarding(currentYear: 2026)
    walkToTheMaxHRQuestion(&onboarding)
    let before = onboarding.bubbles
    let change = onboarding.handle(.submitted(typed))
    #expect(change == nil)
    #expect(onboarding.bubbles == before + [.init(.user, typed), maxHRRetry])
    #expect(onboarding.controls == maxHRControls)
    #expect(onboarding.isFinished == false)
}

@Test func dontKnowClearsMaxHRAndSerenixMovesToThePairStep() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToTheMaxHRQuestion(&onboarding)
    let before = onboarding.bubbles
    let change = onboarding.handle(.chipTapped(.dontKnow))
    #expect(Onboarding.Chip.dontKnow.label == "Don't know")
    #expect(change == .maxHR(nil))
    #expect(onboarding.bubbles == before + [.init(.user, "Don't know"), pairPrompt])
    #expect(onboarding.isFinished == false)
}

@Test func aBlankNumberIsIgnoredAndTheQuestionStaysOpen() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToTheBirthYearQuestion(&onboarding)
    let before = onboarding.bubbles
    #expect(onboarding.handle(.submitted("   ")) == nil)
    #expect(onboarding.bubbles == before)
    #expect(onboarding.controls == birthYearControls)

    var atMaxHR = Onboarding(currentYear: 2026)
    walkToTheMaxHRQuestion(&atMaxHR)
    let beforeMaxHR = atMaxHR.bubbles
    #expect(atMaxHR.handle(.submitted("")) == nil)
    #expect(atMaxHR.bubbles == beforeMaxHR)
    #expect(atMaxHR.controls == maxHRControls)
}
