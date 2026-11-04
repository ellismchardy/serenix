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

    private enum Step: Equatable, Sendable { case name, birthYear, sex, maxHR, pair, finished }

    public private(set) var bubbles: [Bubble]
    private var step = Step.name
    /// For checking a birth year against spec 005's range; passed in so the logic stays testable.
    private let currentYear: Int

    /// After Set up later or Show me Today.
    public var isFinished: Bool { step == .finished }

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
        case .pair: Controls(field: nil, placeholder: nil, chips: [.setUpLater])
        case .finished: Controls(field: nil, placeholder: nil, chips: [])
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

        case (.pair, .chipTapped(.setUpLater)):
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
            case .pair, .finished:
                "Last thing: let's find your Strap. Put it on and keep your phone close."
            }
        return Bubble(.serenix, text)
    }

    private static let birthYearRetry = "I didn't get that — a year like 1992?"
    private static let maxHRRetry = "I didn't get that — a number of beats per minute, like 185?"
}
