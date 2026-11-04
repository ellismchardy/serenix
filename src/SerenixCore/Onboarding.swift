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
        case setUpLater

        /// The chip's text, which is also the user's bubble when tapped.
        public var label: String {
            switch self {
            case .skip: "Skip"
            case .setUpLater: "Set up later"
            }
        }
    }

    public enum Event: Equatable, Sendable {
        /// Text sent from the field.
        case submitted(String)
        case chipTapped(Chip)
    }

    /// An answer for the shell to save to the Profile as soon as it's given.
    public enum ProfileChange: Equatable, Sendable {
        /// Trimmed; nil when skipped or blank.
        case name(String?)
    }

    private enum Step: Equatable, Sendable { case name, pair, finished }

    public private(set) var bubbles: [Bubble]
    private var step = Step.name

    /// After Set up later or Show me Today.
    public var isFinished: Bool { step == .finished }

    /// A fresh conversation: Hello, then the name question.
    public init() {
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
        bubbles.append(
            Bubble(
                .serenix,
                "Last thing: let's find your Strap. Put it on and keep your phone close."
            )
        )
        step = .pair
        return .name(name)
    }
}
