import Foundation

/// Onboarding (GLOSSARY, spec 014): the one-time conversation on first launch. Serenix's lines and
/// the user's answers as bubbles, the answer controls on offer for the open question, and, for
/// each answer, the Profile change the shell saves.
public struct Onboarding: Equatable, Sendable {
    public enum Speaker: Equatable, Sendable { case serenix, user }

    public struct Bubble: Equatable, Sendable {
        public let speaker: Speaker
        public let text: String

        public init(_ speaker: Speaker, _ text: String) {
            self.speaker = speaker
            self.text = text
        }
    }

    /// The kind of text field offered.
    public enum Field: Equatable, Sendable { case name, number }

    /// What the user can answer the open question with.
    public struct Controls: Equatable, Sendable {
        public let field: Field?
        public let placeholder: String?
        /// In the order shown.
        public let chips: [Chip]

        public init(field: Field?, placeholder: String?, chips: [Chip]) {
            self.field = field
            self.placeholder = placeholder
            self.chips = chips
        }
    }

    /// A ready-made answer the user can tap.
    public enum Chip: Equatable, Sendable {
        case skip
        case ratherNot
        case female
        case male
        case preferNotToSay
        case dontKnow
        case findMyStrap
        case tryAgain
        case showMeToday
        case setUpLater

        /// The chip's text, which is also the user's bubble when tapped.
        public var label: String {
            switch self {
            case .skip: "Skip"
            case .ratherNot: "Rather not"
            case .female: "Female"
            case .male: "Male"
            case .preferNotToSay: "Prefer not to say"
            case .dontKnow: "Don't know"
            case .findMyStrap: "Find my Strap"
            case .tryAgain: "Try again"
            case .showMeToday: "Show me Today"
            case .setUpLater: "Set up later"
            }
        }

        /// The sex a sex chip stands for; nil for any other chip.
        public var sex: Sex? {
            switch self {
            case .female: .female
            case .male: .male
            case .preferNotToSay: .preferNotToSay
            default: nil
            }
        }
    }

    public enum Event: Equatable, Sendable {
        /// Text sent from the field.
        case submitted(String)
        case chipTapped(Chip)
        /// Pairing outcomes the shell reports while Serenix is looking for the Strap.
        case strapNotFound
        case pairingRefused
        case strapConnected(model: String)
        /// The first History Sync, once the Strap is connected. Progress runs 0 to 1 (spec 001).
        case syncProgress(Double)
        case syncCompleted
        case syncFailed
    }

    /// Where the first History Sync has got to.
    private enum SyncState: Equatable, Sendable {
        case running(progress: Double?)
        case completed
        case failed
    }

    /// An answer for the shell to save to the Profile as soon as it's given. A skipped question
    /// leaves its field unset.
    public enum ProfileChange: Equatable, Sendable {
        /// Trimmed; nil when skipped or blank.
        case name(String?)
        case birthYear(Int?)
        case sex(Sex)
        /// In bpm.
        case maxHR(Int?)
    }

    private enum Step: Equatable, Sendable {
        case name, birthYear, sex, maxHR, pair, looking, pairFailed, connected, finished
    }

    public private(set) var bubbles: [Bubble]
    private var step = Step.name
    /// For checking a birth year against spec 005's range; passed in so the logic stays testable.
    private let currentYear: Int

    /// After Set up later or Show me Today.
    public var isFinished: Bool { step == .finished }

    /// While true, the shell connects to the Strap and reports how it went.
    public var isLookingForStrap: Bool { step == .looking }

    private var sync: SyncState?

    /// The live sync bubble, shown after the other bubbles; nil until the Strap connects.
    public var syncLine: String? {
        switch sync {
        case nil: nil
        case .running(nil): "Syncing…"
        // Rounded down and at most 99, so it never reads 100% before the sync has completed.
        case .running(let progress?): "Syncing… \(min(Int((progress * 100).rounded(.down)), 99))%"
        case .completed: "✓ Synced"
        case .failed: "The sync didn't finish. Today will show what happened."
        }
    }

    /// A conversation resumed after a relaunch: Hello, then each saved answer replayed in order as
    /// it was first given, opening at the first unanswered question (spec 014, Saving as it goes).
    public init(currentYear: Int, answered: [ProfileChange]) {
        self.init(currentYear: currentYear)
        for answer in answered { replay(answer) }
    }

    /// Gives a saved answer again. Saved numbers were checked when given, so they aren't checked
    /// again: a birth year can drop out of range when the year rolls over.
    private mutating func replay(_ answer: ProfileChange) {
        switch (step, answer) {
        case (.birthYear, .birthYear(let year?)): _ = self.answer(String(year), then: .sex, answer)
        case (.maxHR, .maxHR(let bpm?)): _ = self.answer(String(bpm), then: .pair, answer)
        default: _ = handle(Self.event(replaying: answer))
        }
    }

    /// The event that gives `answer` again.
    private static func event(replaying answer: ProfileChange) -> Event {
        switch answer {
        case .name(let name): name.map { .submitted($0) } ?? .chipTapped(.skip)
        case .birthYear(let year): year.map { .submitted(String($0)) } ?? .chipTapped(.ratherNot)
        case .sex(.female): .chipTapped(.female)
        case .sex(.male): .chipTapped(.male)
        case .sex(.preferNotToSay): .chipTapped(.preferNotToSay)
        case .maxHR(let bpm): bpm.map { .submitted(String($0)) } ?? .chipTapped(.dontKnow)
        }
    }

    /// A fresh conversation: Hello, then the name question.
    public init(currentYear: Int) {
        self.currentYear = currentYear
        bubbles = [
            Bubble(
                .serenix,
                "Hi! I'm Serenix. I read your Whoop Strap over Bluetooth and work out your sleep, "
                    + "Readiness and Load — all on this phone."
            ),
            Bubble(.serenix, "Serenix isn't affiliated with WHOOP, Inc."),
            Bubble(.serenix, "What should I call you?"),
        ]
    }

    public var controls: Controls {
        switch step {
        case .name: Controls(field: .name, placeholder: "Your name", chips: [.skip])
        case .birthYear: Controls(field: .number, placeholder: "e.g. 1992", chips: [.ratherNot])
        case .sex: Controls(field: nil, placeholder: nil, chips: [.female, .male, .preferNotToSay])
        case .maxHR: Controls(field: .number, placeholder: "e.g. 185", chips: [.dontKnow])
        case .pair: Controls(field: nil, placeholder: nil, chips: [.findMyStrap, .setUpLater])
        case .pairFailed: Controls(field: nil, placeholder: nil, chips: [.tryAgain, .setUpLater])
        case .connected: Controls(field: nil, placeholder: nil, chips: [.showMeToday])
        case .looking, .finished: Controls(field: nil, placeholder: nil, chips: [])
        }
    }

    /// Moves the conversation on, and returns the Profile change to save, if any.
    public mutating func handle(_ event: Event) -> ProfileChange? {
        switch (step, event) {
        case (.name, .submitted(let text)):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return answerName(trimmed.isEmpty ? nil : trimmed)
        case (.name, .chipTapped(.skip)):
            return answerName(nil)

        case (.birthYear, .submitted(let text)):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let year = Int(trimmed), Profile.allowedBirthYears(in: currentYear).contains(year)
            else { return askAgain(after: trimmed, Self.birthYearRetry) }
            return answer(String(year), then: .sex, .birthYear(year))
        case (.birthYear, .chipTapped(.ratherNot)):
            return answer(Chip.ratherNot.label, then: .sex, .birthYear(nil))

        case (.sex, .chipTapped(let chip)):
            guard let sex = chip.sex else { return nil }
            return answer(chip.label, then: .maxHR, .sex(sex))

        case (.maxHR, .submitted(let text)):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let bpm = Int(trimmed), Profile.allowedMaxHR.contains(bpm)
            else { return askAgain(after: trimmed, Self.maxHRRetry) }
            return answer(String(bpm), then: .pair, .maxHR(bpm))
        case (.maxHR, .chipTapped(.dontKnow)):
            return answer(Chip.dontKnow.label, then: .pair, .maxHR(nil))

        case (.pair, .chipTapped(.findMyStrap)):
            return startLooking(after: .findMyStrap)
        case (.pairFailed, .chipTapped(.tryAgain)):
            return startLooking(after: .tryAgain)
        case (.looking, .strapNotFound):
            bubbles.append(Bubble(.serenix, Self.notFoundAdvice))
            step = .pairFailed
            return nil
        case (.looking, .pairingRefused):
            bubbles.append(Bubble(.serenix, Self.pairingRefusedAdvice))
            step = .pairFailed
            return nil
        case (.looking, .strapConnected(let model)):
            bubbles.append(Bubble(.serenix, "Found it — \(model)."))
            bubbles.append(
                Bubble(
                    .serenix,
                    "Pulling in your history now. Readiness needs 4 Nights to calibrate, so it'll "
                        + "say Calibrating for the first few days."
                )
            )
            step = .connected
            sync = .running(progress: nil)
            return nil
        case (.connected, .syncProgress(let progress)):
            if case .running = sync { sync = .running(progress: min(max(progress, 0), 1)) }
            return nil
        case (.connected, .syncCompleted):
            if case .running = sync { sync = .completed }
            return nil
        case (.connected, .syncFailed):
            if case .running = sync { sync = .failed }
            return nil
        case (.connected, .chipTapped(.showMeToday)):
            bubbles.append(Bubble(.user, Chip.showMeToday.label))
            step = .finished
            return nil

        case (.pair, .chipTapped(.setUpLater)), (.pairFailed, .chipTapped(.setUpLater)):
            bubbles.append(Bubble(.user, Chip.setUpLater.label))
            step = .finished
            return nil

        default:
            // An answer the open question doesn't offer is ignored.
            return nil
        }
    }

    /// Whether Onboarding counts as finished: once finished explicitly, and from launch for
    /// existing installs that answered spec 002's old name prompt or have completed a History
    /// Sync.
    public static func isFinished(
        finishedFlag: Bool,
        namePromptAnswered: Bool,
        historySyncCompleted: Bool
    ) -> Bool {
        finishedFlag || namePromptAnswered || historySyncCompleted
    }

    private mutating func answerName(_ name: String?) -> ProfileChange {
        bubbles.append(Bubble(.user, name ?? Chip.skip.label))
        bubbles.append(
            Bubble(.serenix, name.map { "Nice to meet you, \($0)." } ?? "Nice to meet you.")
        )
        step = .birthYear
        bubbles.append(question(for: step))
        return .name(name)
    }

    /// Shows the user's answer, moves to `next` and asks its question.
    private mutating func answer(_ shown: String, then next: Step, _ change: ProfileChange)
        -> ProfileChange
    {
        bubbles.append(Bubble(.user, shown))
        step = next
        bubbles.append(question(for: next))
        return change
    }

    private mutating func startLooking(after chip: Chip) -> ProfileChange? {
        bubbles.append(Bubble(.user, chip.label))
        bubbles.append(Bubble(.serenix, "Looking for your Strap…"))
        step = .looking
        return nil
    }

    /// Shows what was typed and the retry line; the same question stays open. Nothing typed is
    /// ignored.
    private mutating func askAgain(after typed: String, _ retry: String) -> ProfileChange? {
        guard !typed.isEmpty else { return nil }
        bubbles.append(Bubble(.user, typed))
        bubbles.append(Bubble(.serenix, retry))
        return nil
    }

    private func question(for step: Step) -> Bubble {
        let text =
            switch step {
            case .name: "What should I call you?"
            case .birthYear:
                "What year were you born? It sets how much sleep you need and estimates your Max HR."
            case .sex: "Which sex should I use for heart-rate calculations?"
            case .maxHR: "Do you know your Max HR from a test?"
            // Only questions are asked; the pairing steps never come here.
            case .pair, .looking, .pairFailed, .connected, .finished:
                "Last thing: let's find your Strap. Put it on and keep your phone close."
            }
        return Bubble(.serenix, text)
    }

    private static let notFoundAdvice =
        "I couldn't find your Strap. Make sure it's charged and close by, and that the WHOOP app "
        + "isn't connected to it — close it, or turn off its Bluetooth access."
    private static let pairingRefusedAdvice =
        "Pairing didn't finish. Put your Strap in pairing mode and try again — it stays in "
        + "pairing mode for a minute or two."
    private static let birthYearRetry = "I didn't get that — a year like 1992?"
    private static let maxHRRetry = "I didn't get that — a number of beats per minute, like 185?"
}
