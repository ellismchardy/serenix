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
    /// Whether the first-launch prompt has been answered, by Continue or Skip. It never shows
    /// again after that.
    @Published private(set) var hasBeenAskedForName: Bool {
        didSet { defaults.set(hasBeenAskedForName, forKey: askedKey) }
    }
    /// Nil when not set (spec 005, Profile).
    @Published var birthYear: Int? {
        didSet {
            defaults.set(birthYear, forKey: birthYearKey)
            onLoadInputsChange?()
        }
    }
    /// Prefer not to say when not set.
    @Published var sex: Sex {
        didSet {
            defaults.set(sex.rawValue, forKey: sexKey)
            onLoadInputsChange?()
        }
    }
    /// The Max HR the user entered, in bpm; nil when not set.
    @Published var maxHR: Int? {
        didSet {
            defaults.set(maxHR, forKey: maxHRKey)
            onLoadInputsChange?()
        }
    }
    /// Called after birth year, sex or Max HR changes, whoever changed it, so every Day still on
    /// the phone gets its Load worked out again (spec 005, Profile changes).
    var onLoadInputsChange: (@MainActor () -> Void)?

    private let defaults = UserDefaults.standard

    init() {
        // Through the wrappers, so `self` isn't used before every property is set.
        let stored = ProfileStore.storedProfile
        _name = Published(initialValue: stored.name)
        _hasBeenAskedForName = Published(
            initialValue: UserDefaults.standard.bool(forKey: askedKey)
        )
        _birthYear = Published(initialValue: stored.birthYear)
        _sex = Published(initialValue: stored.sex)
        _maxHR = Published(initialValue: stored.maxHR)
    }

    /// Records the first-launch prompt's answer: the name after Continue (none if left blank),
    /// nil after Skip.
    func answerNamePrompt(with name: String?) {
        rename(to: name)
        hasBeenAskedForName = true
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
            maxHR: defaults.object(forKey: maxHRKey) as? Int
        )
    }
}

private let nameKey = "profileName"
private let birthYearKey = "profileBirthYear"
private let sexKey = "profileSex"
private let maxHRKey = "profileMaxHR"
private let askedKey = "profileNameAsked"
