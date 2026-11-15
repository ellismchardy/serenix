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
    #expect(onboarding.controls.chips == [.findMyStrap, .setUpLater])
    #expect(Onboarding.Chip.setUpLater.label == "Set up later")
    #expect(onboarding.isLookingForStrap == false)
    #expect(onboarding.isFinished == false)
}

private let lookingBubble = Onboarding.Bubble(.serenix, "Looking for your Strap…")

private let notFoundBubble = Onboarding.Bubble(
    .serenix,
    "I couldn't find your Strap. Make sure it's charged and close by, and that the WHOOP app isn't connected to it — close it, or turn off its Bluetooth access."
)

private let pairingRefusedBubble = Onboarding.Bubble(
    .serenix,
    "Pairing didn't finish. Put your Strap in pairing mode and try again — it stays in pairing mode for a minute or two."
)

private let failureControls = Onboarding.Controls(
    field: nil,
    placeholder: nil,
    chips: [.tryAgain, .setUpLater]
)

private let lookingControls = Onboarding.Controls(field: nil, placeholder: nil, chips: [])

private func walkToLookingForTheStrap(_ onboarding: inout Onboarding) {
    walkToThePairStep(&onboarding)
    _ = onboarding.handle(.chipTapped(.findMyStrap))
}

@Test func tappingFindMyStrapStartsLookingForTheStrap() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToThePairStep(&onboarding)
    let before = onboarding.bubbles
    let change = onboarding.handle(.chipTapped(.findMyStrap))
    #expect(Onboarding.Chip.findMyStrap.label == "Find my Strap")
    #expect(change == nil)
    #expect(onboarding.bubbles == before + [.init(.user, "Find my Strap"), lookingBubble])
    #expect(onboarding.controls == lookingControls)
    #expect(onboarding.isLookingForStrap == true)
    #expect(onboarding.isFinished == false)
}

@Test func aStrapNotFoundOffersTryAgainOrSetUpLater() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToLookingForTheStrap(&onboarding)
    let before = onboarding.bubbles
    _ = onboarding.handle(.strapNotFound)
    #expect(onboarding.bubbles == before + [notFoundBubble])
    #expect(onboarding.controls == failureControls)
    #expect(Onboarding.Chip.tryAgain.label == "Try again")
    #expect(onboarding.isLookingForStrap == false)
    #expect(onboarding.isFinished == false)
}

@Test func refusedPairingOffersTryAgainOrSetUpLater() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToLookingForTheStrap(&onboarding)
    let before = onboarding.bubbles
    _ = onboarding.handle(.pairingRefused)
    #expect(onboarding.bubbles == before + [pairingRefusedBubble])
    #expect(onboarding.controls == failureControls)
    #expect(onboarding.isLookingForStrap == false)
    #expect(onboarding.isFinished == false)
}

@Test(arguments: [Onboarding.Event.strapNotFound, .pairingRefused])
func tryAgainAfterAFailureLooksForTheStrapAgain(failure: Onboarding.Event) {
    var onboarding = Onboarding(currentYear: 2026)
    walkToLookingForTheStrap(&onboarding)
    _ = onboarding.handle(failure)
    let before = onboarding.bubbles
    let change = onboarding.handle(.chipTapped(.tryAgain))
    #expect(change == nil)
    #expect(onboarding.bubbles == before + [.init(.user, "Try again"), lookingBubble])
    #expect(onboarding.controls == lookingControls)
    #expect(onboarding.isLookingForStrap == true)
}

@Test(arguments: [Onboarding.Event.strapNotFound, .pairingRefused])
func setUpLaterAfterAFailureFinishesOnboarding(failure: Onboarding.Event) {
    var onboarding = Onboarding(currentYear: 2026)
    walkToLookingForTheStrap(&onboarding)
    _ = onboarding.handle(failure)
    _ = onboarding.handle(.chipTapped(.setUpLater))
    #expect(onboarding.isFinished == true)
}

@Test func aConnectedStrapShowsFoundItWithTheModel() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToLookingForTheStrap(&onboarding)
    let before = onboarding.bubbles
    _ = onboarding.handle(.strapConnected(model: "Whoop 5.0"))
    let foundIt = Onboarding.Bubble(.serenix, "Found it — Whoop 5.0.")
    #expect(onboarding.bubbles == before + [foundIt, calibratingBubble])
    #expect(onboarding.isLookingForStrap == false)
    #expect(onboarding.isFinished == false)
}

private let calibratingBubble = Onboarding.Bubble(
    .serenix,
    "Pulling in your history now. Readiness needs 4 Nights to calibrate, so it'll say Calibrating for the first few days."
)

private let syncingControls = Onboarding.Controls(
    field: nil,
    placeholder: nil,
    chips: [.showMeToday]
)

private func walkToSyncing(_ onboarding: inout Onboarding) {
    walkToLookingForTheStrap(&onboarding)
    _ = onboarding.handle(.strapConnected(model: "Whoop 5.0"))
}

@Test func aConnectedStrapStartsSyncingAndOffersShowMeTodayAtOnce() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToSyncing(&onboarding)
    #expect(Onboarding.Chip.showMeToday.label == "Show me Today")
    #expect(onboarding.syncLine == "Syncing…")
    #expect(onboarding.controls == syncingControls)
    #expect(onboarding.isFinished == false)
}

@Test(arguments: [(0.4, "Syncing… 40%"), (0.999, "Syncing… 99%"), (0.0, "Syncing… 0%")])
func syncProgressShowsAWholePercentRoundedDown(progress: Double, line: String) {
    var onboarding = Onboarding(currentYear: 2026)
    walkToSyncing(&onboarding)
    _ = onboarding.handle(.syncProgress(progress))
    #expect(onboarding.syncLine == line)
    #expect(onboarding.controls == syncingControls)
}

@Test func aCompletedSyncShowsSynced() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToSyncing(&onboarding)
    _ = onboarding.handle(.syncProgress(0.5))
    _ = onboarding.handle(.syncCompleted)
    #expect(onboarding.syncLine == "✓ Synced")
    #expect(onboarding.controls == syncingControls)
    _ = onboarding.handle(.syncProgress(0.7))
    #expect(onboarding.syncLine == "✓ Synced")
}

@Test func aFailedSyncSaysTodayWillShowWhatHappened() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToSyncing(&onboarding)
    _ = onboarding.handle(.syncFailed)
    #expect(onboarding.syncLine == "The sync didn't finish. Today will show what happened.")
    #expect(onboarding.controls == syncingControls)
    _ = onboarding.handle(.syncProgress(0.7))
    #expect(onboarding.syncLine == "The sync didn't finish. Today will show what happened.")
}

@Test(arguments: [nil, Onboarding.Event.syncCompleted, .syncFailed])
func tappingShowMeTodayFinishesOnboarding(syncOutcome: Onboarding.Event?) {
    var onboarding = Onboarding(currentYear: 2026)
    walkToSyncing(&onboarding)
    if let syncOutcome { _ = onboarding.handle(syncOutcome) }
    let before = onboarding.bubbles
    let change = onboarding.handle(.chipTapped(.showMeToday))
    #expect(change == nil)
    #expect(onboarding.bubbles == before + [.init(.user, "Show me Today")])
    #expect(onboarding.isFinished == true)
}

@Test func thereIsNoSyncLineBeforeTheStrapConnects() {
    var onboarding = Onboarding(currentYear: 2026)
    #expect(onboarding.syncLine == nil)
    walkToThePairStep(&onboarding)
    #expect(onboarding.syncLine == nil)
    let before = onboarding.bubbles
    _ = onboarding.handle(.syncProgress(0.4))
    _ = onboarding.handle(.syncCompleted)
    _ = onboarding.handle(.syncFailed)
    #expect(onboarding.syncLine == nil)
    #expect(onboarding.bubbles == before)
    #expect(onboarding.isFinished == false)
}

@Test func pairingEventsAreIgnoredWhenNotLookingForTheStrap() {
    var atPairStep = Onboarding(currentYear: 2026)
    walkToThePairStep(&atPairStep)
    let before = atPairStep.bubbles
    _ = atPairStep.handle(.strapConnected(model: "Whoop 5.0"))
    #expect(atPairStep.bubbles == before)
    #expect(atPairStep.isLookingForStrap == false)

    var afterFailure = Onboarding(currentYear: 2026)
    walkToLookingForTheStrap(&afterFailure)
    _ = afterFailure.handle(.strapNotFound)
    let beforeSecond = afterFailure.bubbles
    _ = afterFailure.handle(.strapNotFound)
    #expect(afterFailure.bubbles == beforeSecond)
    #expect(afterFailure.controls == failureControls)
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

@Test func fullProgressReads99PercentUntilTheSyncCompletes() {
    var onboarding = Onboarding(currentYear: 2026)
    walkToSyncing(&onboarding)
    _ = onboarding.handle(.syncProgress(1))
    #expect(onboarding.syncLine == "Syncing… 99%")
}

@Test func aResumedConversationReplaysTheSavedAnswersAndOpensAtTheNextQuestion() {
    let onboarding = Onboarding(currentYear: 2026, answered: [.name("Ellis"), .birthYear(1992)])
    #expect(
        onboarding.bubbles
            == greeting + [
                .init(.user, "Ellis"),
                .init(.serenix, "Nice to meet you, Ellis."),
                birthYearQuestion,
                .init(.user, "1992"),
                sexQuestion,
            ]
    )
    #expect(onboarding.controls == sexControls)
    #expect(!onboarding.isFinished)
}

@Test func aResumedSkippedNameShowsSkipAndOpensAtTheBirthYear() {
    let onboarding = Onboarding(currentYear: 2026, answered: [.name(nil)])
    #expect(
        onboarding.bubbles
            == greeting + [
                .init(.user, "Skip"),
                .init(.serenix, "Nice to meet you."),
                birthYearQuestion,
            ]
    )
    #expect(onboarding.controls == birthYearControls)
}

@Test func aResumedConversationWithEveryQuestionAnsweredOpensAtFindingTheStrap() {
    let skipped = Onboarding(
        currentYear: 2026,
        answered: [.name("Ellis"), .birthYear(nil), .sex(.female), .maxHR(nil)]
    )
    #expect(
        Array(skipped.bubbles.suffix(6)) == [
            .init(.user, "Rather not"),
            sexQuestion,
            .init(.user, "Female"),
            maxHRQuestion,
            .init(.user, "Don't know"),
            pairPrompt,
        ]
    )
    #expect(
        skipped.controls
            == Onboarding.Controls(
                field: nil,
                placeholder: nil,
                chips: [.findMyStrap, .setUpLater]
            )
    )

    let given = Onboarding(
        currentYear: 2026,
        answered: [.name("Ellis"), .birthYear(1992), .sex(.male), .maxHR(185)]
    )
    #expect(Array(given.bubbles.suffix(2)) == [.init(.user, "185"), pairPrompt])
}

@Test func aResumedConversationEqualsOneDrivenThroughTheSameAnswers() {
    var fresh = Onboarding(currentYear: 2026)
    _ = fresh.handle(.submitted("Ellis"))
    _ = fresh.handle(.submitted("1992"))
    #expect(
        Onboarding(currentYear: 2026, answered: [.name("Ellis"), .birthYear(1992)]) == fresh
    )
}

@Test func aConversationWithNoSavedAnswersIsAFreshOne() {
    #expect(Onboarding(currentYear: 2026, answered: []) == Onboarding(currentYear: 2026))
}

@Test func aSavedBirthYearThatIsNowOutOfRangeIsNotAskedAgain() {
    // 1926 was allowed in 2026 (100 years before); in 2027 it no longer is.
    let onboarding = Onboarding(
        currentYear: 2027,
        answered: [.name("Ellis"), .birthYear(1926), .sex(.male)]
    )
    #expect(
        onboarding.bubbles.suffix(4) == [
            .init(.user, "1926"), sexQuestion, .init(.user, "Male"), maxHRQuestion,
        ]
    )
    #expect(onboarding.controls == maxHRControls)
}

@Test(
    arguments: [
        (StrapPhase.connected, Onboarding.Event.strapConnected(model: "Whoop 5.0")),
        (.syncing, .strapConnected(model: "Whoop 5.0")),
        (.synced, .strapConnected(model: "Whoop 5.0")),
        (.failed("Couldn't subscribe.", .strapNotPaired), .pairingRefused),
        (.failed("Timed out.", .strapUnreachable), .strapNotFound),
        (.failed("This doesn't look like a Whoop 5.0 Strap.", .other), .strapNotFound),
        (.failed("Cancelled.", .cancelled), .strapNotFound),
        (.bluetoothUnavailable("Bluetooth is off."), .strapNotFound),
    ] as [(StrapPhase, Onboarding.Event)]
)
func onlyAnUnpairedStrapGetsThePairingAdvice(phase: StrapPhase, event: Onboarding.Event) {
    #expect(Onboarding.pairingEvent(for: phase, model: "Whoop 5.0") == event)
}

@Test(arguments: [StrapPhase.idle, .searching, .connecting])
func aStrapStillBeingLookedForGivesNoPairingEvent(phase: StrapPhase) {
    #expect(Onboarding.pairingEvent(for: phase, model: "Whoop 5.0") == nil)
}
