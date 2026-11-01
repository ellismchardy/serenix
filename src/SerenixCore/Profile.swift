import Foundation

/// The Profile's sex, used only for heart-rate calculations (spec 005, Profile).
public enum Sex: String, CaseIterable, Sendable {
    case female
    case male
    case preferNotToSay
}

/// The Profile (GLOSSARY): the user's name, used to address them (spec 002, Profile), and
/// optionally their birth year, sex and Max HR, used to work out Load (spec 005, Profile). Kept
/// on the phone only.
public struct Profile: Equatable, Sendable {
    /// Trimmed of spaces; nil when there's no name or only spaces.
    public let name: String?
    /// Nil when not set. Kept as given: the allowed range depends on the year, so only the picker
    /// limits it, and any set birth year counts.
    public let birthYear: Int?
    /// Prefer not to say when not set.
    public let sex: Sex
    /// The Max HR the user entered, in bpm; nil when not set or outside `allowedMaxHR` (the
    /// shell's field only offers that range).
    public let maxHR: Int?

    public init(
        name: String?,
        birthYear: Int? = nil,
        sex: Sex = .preferNotToSay,
        maxHR: Int? = nil
    ) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.name = trimmed.isEmpty ? nil : trimmed
        self.birthYear = birthYear
        self.sex = sex
        self.maxHR = maxHR.flatMap { Self.allowedMaxHR.contains($0) ? $0 : nil }
    }

    /// Whole bpm a user can enter as Max HR (spec 005, Profile).
    public static let allowedMaxHR = 100...230

    /// Birth years a user can pick in `year`: 100 to 13 years before it (spec 005, Profile).
    public static func allowedBirthYears(in year: Int) -> ClosedRange<Int> {
        (year - oldestAge)...(year - youngestAge)
    }

    /// Max HR estimated from age with Tanaka's 208 − 0.7 × age, in bpm and unrounded, age being
    /// `year` − birth year (spec 005, Max HR; docs/research/cardio-load-methods.md); nil with no
    /// birth year. Any set birth year counts, even one outside `allowedBirthYears(in: year)`, so a
    /// Day from late last year still gets a Max HR from a birth year picked this January.
    public func estimatedMaxHR(in year: Int) -> Double? {
        birthYear.map { Self.tanakaIntercept - Self.tanakaSlope * Double(year - $0) }
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

    /// Ages in years the birth year picker spans (spec 005, Profile).
    private static let oldestAge = 100
    private static let youngestAge = 13
    /// Tanaka, Monahan & Seals 2001: bpm, and bpm per year of age.
    private static let tanakaIntercept = 208.0
    private static let tanakaSlope = 0.7

    /// Local hours the parts of the day start at (spec 002, Greeting); evening runs to 04:59.
    private static let morningFrom = 5
    private static let afternoonFrom = 12
    private static let eveningFrom = 18
}
