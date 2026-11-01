import Foundation

/// The Profile (GLOSSARY): the user's name, used to address them (spec 002, Profile).
struct Profile: Equatable, Sendable {
    /// Trimmed of spaces; nil when there's no name or only spaces.
    let name: String?

    init(name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.name = trimmed.isEmpty ? nil : trimmed
    }

    /// The avatar's letter: the name's first letter, upper-cased.
    var avatarLetter: String? {
        name.flatMap { $0.first.map { String($0).uppercased() } }
    }

    /// The profile menu header's name.
    var menuName: String { name ?? "Add your name" }

    /// "Good morning!", "Good afternoon!" or "Good evening!" by the local time of day; the name
    /// shows under it, not in it (spec 002, Greeting).
    func greeting(at time: Date, in timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: time)
        let partOfDay =
            switch hour {
            case Self.morningFrom..<Self.afternoonFrom: "morning"
            case Self.afternoonFrom..<Self.eveningFrom: "afternoon"
            default: "evening"
            }
        return "Good \(partOfDay)!"
    }

    /// Local hours the parts of the day start at (spec 002, Greeting); evening runs to 04:59.
    private static let morningFrom = 5
    private static let afternoonFrom = 12
    private static let eveningFrom = 18
}
