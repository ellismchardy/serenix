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

@Test func aFreshConversationGreetsAndAsksForTheName() {
    let onboarding = Onboarding()
    #expect(onboarding.bubbles == greeting)
    #expect(
        onboarding.controls
            == Onboarding.Controls(field: .name, placeholder: "Your name", chips: [.skip])
    )
    #expect(onboarding.isFinished == false)
}

@Test func submittingANameTrimsItAndGreetsTheUserByName() {
    var onboarding = Onboarding()
    let change = onboarding.handle(.submitted("  Ellis "))
    #expect(change == .name("Ellis"))
    #expect(
        onboarding.bubbles
            == greeting + [
                .init(.user, "Ellis"),
                .init(.serenix, "Nice to meet you, Ellis."),
                pairPrompt,
            ]
    )
}

@Test func skippingTheNameClearsItAndGreetsWithoutAName() {
    var onboarding = Onboarding()
    let change = onboarding.handle(.chipTapped(.skip))
    #expect(change == .name(nil))
    #expect(onboarding.isFinished == false)
    #expect(
        onboarding.bubbles
            == greeting + [
                .init(.user, "Skip"),
                .init(.serenix, "Nice to meet you."),
                pairPrompt,
            ]
    )
}

@Test func submittingABlankNameIsTreatedAsSkip() {
    var onboarding = Onboarding()
    let change = onboarding.handle(.submitted("   "))
    #expect(change == .name(nil))
    #expect(
        onboarding.bubbles
            == greeting + [
                .init(.user, "Skip"),
                .init(.serenix, "Nice to meet you."),
                pairPrompt,
            ]
    )
}

@Test func thePairStepOffersSetUpLaterAndNoTextField() {
    var onboarding = Onboarding()
    _ = onboarding.handle(.submitted("Ellis"))
    #expect(onboarding.controls.field == nil)
    #expect(onboarding.controls.placeholder == nil)
    #expect(onboarding.controls.chips.contains(.setUpLater))
    #expect(Onboarding.Chip.setUpLater.label == "Set up later")
    #expect(onboarding.isFinished == false)
}

@Test func tappingSetUpLaterFinishesOnboarding() {
    var onboarding = Onboarding()
    _ = onboarding.handle(.submitted("Ellis"))
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
