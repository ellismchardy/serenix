import Foundation

/// The Profile (GLOSSARY): the user's name, kept in UserDefaults on this phone. It is never sent
/// anywhere, and never written to the Sync Log or any shared log or report (spec 002).
@MainActor
final class ProfileStore: ObservableObject {
    /// The name as the user typed it; the Today view trims it and treats a blank one as none.
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
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.name = trimmed.isEmpty ? nil : trimmed
        hasBeenAskedForName = true
    }
}

private let nameKey = "profileName"
private let askedKey = "profileNameAsked"
