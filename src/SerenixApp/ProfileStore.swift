import Foundation
import SerenixCore

/// The Profile (GLOSSARY): the user's name, kept in UserDefaults on this phone. It is never sent
/// anywhere, and never written to the Sync Log or any shared log or report (spec 002).
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

    private let defaults = UserDefaults.standard

    init() {
        // Through the wrappers, so `self` isn't used before every property is set.
        _name = Published(initialValue: UserDefaults.standard.string(forKey: nameKey))
        _hasBeenAskedForName = Published(
            initialValue: UserDefaults.standard.bool(forKey: askedKey)
        )
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
