import Foundation
import SerenixCore

/// The Profile (GLOSSARY): the user's name, and optionally their birth year, sex and Max HR, kept
/// in UserDefaults on this phone. It is never sent anywhere, and never written to the Sync Log or
/// any shared log or report (specs 002 and 005).
@MainActor
final class ProfileStore: ObservableObject {
    /// Stored trimmed, nil when blank, by `rename(to:)`; the Today view trims again on read.
    @Published var name: String? {
        didSet { defaults.set(name, forKey: nameKey) }
    }
    /// Whether Onboarding is finished (spec 014). It never shows again after that. Existing
    /// installs, which answered spec 002's old name prompt or have completed a History Sync,
    /// count as finished from launch.
    @Published private(set) var hasFinishedOnboarding: Bool {
        didSet { defaults.set(hasFinishedOnboarding, forKey: onboardingFinishedKey) }
    }
    /// Nil when not set (spec 005, Profile).
    @Published var birthYear: Int? {
        didSet {
            defaults.set(birthYear, forKey: birthYearKey)
            if birthYear != oldValue { onLoadInputsChange?() }
        }
    }
    /// Prefer not to say when not set.
    @Published var sex: Sex {
        didSet {
            defaults.set(sex.rawValue, forKey: sexKey)
            if sex != oldValue { onLoadInputsChange?() }
        }
    }
    /// The Max HR the user entered, in bpm; nil when not set.
    @Published var maxHR: Int? {
        didSet {
            defaults.set(maxHR, forKey: maxHRKey)
            if maxHR != oldValue { onLoadInputsChange?() }
        }
    }
    /// The user's height in cm; nil when not set (spec 015, Units and Profile).
    @Published var heightCentimetres: Double? {
        didSet { defaults.set(heightCentimetres, forKey: heightKey) }
    }
    /// How weights are shown; kg when not set. Everything is stored in kg (spec 015).
    @Published var units: WeightUnits {
        didSet { defaults.set(units.rawValue, forKey: unitsKey) }
    }
    /// Called after birth year, sex or Max HR changes, whoever changed it, so every Day still on
    /// the phone gets its Load worked out again (spec 005, Profile changes).
    var onLoadInputsChange: (@MainActor () -> Void)?

    private let defaults = UserDefaults.standard

    init() {
        // Through the wrappers, so `self` isn't used before every property is set.
        let stored = ProfileStore.storedProfile
        _name = Published(initialValue: stored.name)
        let defaults = UserDefaults.standard
        _hasFinishedOnboarding = Published(
            initialValue: Onboarding.isFinished(
                finishedFlag: defaults.bool(forKey: onboardingFinishedKey),
                namePromptAnswered: defaults.bool(forKey: namePromptAnsweredKey),
                historySyncCompleted: StrapConnection.hasCompletedAHistorySync
            )
        )
        _birthYear = Published(initialValue: stored.birthYear)
        _sex = Published(initialValue: stored.sex)
        _maxHR = Published(initialValue: stored.maxHR)
        _heightCentimetres = Published(initialValue: stored.heightCentimetres)
        _units = Published(initialValue: stored.units)
    }

    /// Marks Onboarding finished, after Show me Today or Set up later (spec 014).
    func finishOnboarding() {
        hasFinishedOnboarding = true
    }

    /// Saves an Onboarding answer as soon as it's given (spec 014, Saving as it goes).
    func apply(_ change: Onboarding.ProfileChange) {
        switch change {
        case .name(let name): rename(to: name)
        case .birthYear(let year): birthYear = year
        case .sex(let sex): self.sex = sex
        case .maxHR(let bpm): maxHR = bpm
        }
        var answered = defaults.stringArray(forKey: onboardingAnsweredKey) ?? []
        let question = OnboardingQuestion(of: change).rawValue
        if !answered.contains(question) {
            answered.append(question)
            defaults.set(answered, forKey: onboardingAnsweredKey)
        }
    }

    /// The Onboarding answers given so far, in order, so a relaunch resumes where the user left
    /// off (spec 014, Saving as it goes). Only which questions were answered is kept; each answer
    /// is rebuilt from the Profile's current value, which is what was saved. A skipped question
    /// counts as answered.
    var onboardingAnswers: [Onboarding.ProfileChange] {
        (defaults.stringArray(forKey: onboardingAnsweredKey) ?? []).compactMap {
            switch OnboardingQuestion(rawValue: $0) {
            case .name: .name(name)
            case .birthYear: .birthYear(birthYear)
            case .sex: .sex(sex)
            case .maxHR: .maxHR(maxHR)
            case nil: nil
            }
        }
    }

    /// Sets the name, trimmed of spaces; a blank one counts as none.
    func rename(to name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.name = trimmed.isEmpty ? nil : trimmed
    }
}

extension ProfileStore {
    /// The Profile as kept on the phone, readable off the main thread (UserDefaults is
    /// thread-safe) for working out Load (spec 005).
    nonisolated static var storedProfile: Profile {
        let defaults = UserDefaults.standard
        return Profile(
            name: defaults.string(forKey: nameKey),
            birthYear: defaults.object(forKey: birthYearKey) as? Int,
            sex: defaults.string(forKey: sexKey).flatMap(Sex.init(rawValue:)) ?? .preferNotToSay,
            maxHR: defaults.object(forKey: maxHRKey) as? Int,
            heightCentimetres: defaults.object(forKey: heightKey) as? Double,
            units: defaults.string(forKey: unitsKey).flatMap(WeightUnits.init(rawValue:))
                ?? .kilograms
        )
    }
}

private let nameKey = "profileName"
private let birthYearKey = "profileBirthYear"
private let sexKey = "profileSex"
private let maxHRKey = "profileMaxHR"
private let heightKey = "profileHeightCentimetres"
private let unitsKey = "profileUnits"
/// Set by spec 002's old name prompt, now removed: kept only so existing installs skip Onboarding.
private let namePromptAnsweredKey = "profileNameAsked"
private let onboardingFinishedKey = "onboardingFinished"
/// Which Onboarding questions have been answered, in order, as `OnboardingQuestion` raw values.
private let onboardingAnsweredKey = "onboardingAnswered"

/// An Onboarding question that saves to the Profile, as kept in the answered list.
private enum OnboardingQuestion: String {
    case name, birthYear, sex, maxHR

    init(of change: Onboarding.ProfileChange) {
        switch change {
        case .name: self = .name
        case .birthYear: self = .birthYear
        case .sex: self = .sex
        case .maxHR: self = .maxHR
        }
    }
}
