import Foundation

/// One thing the user logs as eaten (GLOSSARY, Food Entry; spec 016): its calories, and
/// optionally its protein, fat and carbs in grams, and a short name. Time in UTC.
public struct FoodEntry: Hashable, Codable, Sendable {
    public let time: Date
    public let kilocalories: Double
    public let protein: Double?
    public let fat: Double?
    public let carbs: Double?
    public let name: String?

    public init(
        time: Date,
        kilocalories: Double,
        protein: Double? = nil,
        fat: Double? = nil,
        carbs: Double? = nil,
        name: String? = nil
    ) {
        self.time = time
        self.kilocalories = kilocalories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.name = name
    }
}

/// A Day's Food Entries added up (GLOSSARY, Intake): kcal and grams; a blank macro counts as 0.
public struct Intake: Equatable, Sendable {
    public let kilocalories: Double
    public let protein: Double
    public let fat: Double
    public let carbs: Double

    public init(kilocalories: Double, protein: Double, fat: Double, carbs: Double) {
        self.kilocalories = kilocalories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
    }

    /// `entries` added up.
    init(_ entries: [FoodEntry]) {
        self.init(
            kilocalories: entries.reduce(0) { $0 + $1.kilocalories },
            protein: entries.reduce(0) { $0 + ($1.protein ?? 0) },
            fat: entries.reduce(0) { $0 + ($1.fat ?? 0) },
            carbs: entries.reduce(0) { $0 + ($1.carbs ?? 0) }
        )
    }
}

/// Why a Food Entry can't be saved (spec 016, Food Entries → Limits).
public enum FoodEntryRefusal: Equatable, Sendable {
    /// Calories or a macro below 0.
    case negative
    /// Over 5,000 kcal.
    case tooManyCalories
    /// Protein, fat or carbs over 500 g.
    case macroTooLarge
    /// A name over 40 characters.
    case nameTooLong
    /// A time after now.
    case inTheFuture

    /// Built from the limits, so a changed limit changes its message too.
    public var message: String {
        switch self {
        case .negative: "Calories and macros can't be below 0."
        case .tooManyCalories:
            "A Food Entry can't be over \(limitText(FoodEntry.maxKilocalories)) kcal."
        case .macroTooLarge:
            "Protein, fat and carbs can't be over \(limitText(FoodEntry.maxMacroGrams)) g each."
        case .nameTooLong: "A name can't be over \(FoodEntry.maxNameLength) characters."
        case .inTheFuture: "A Food Entry can't be in the future."
        }
    }

}

extension FoodEntry {
    /// The most calories one Food Entry may have, kcal (spec 016): more than a day's food for
    /// almost anyone, so a bigger number is a typo (an extra 0). Issue #54.
    static let maxKilocalories = 5_000.0
    /// The most of one macro a Food Entry may have, grams (spec 016, issue #54), on the same
    /// reasoning.
    static let maxMacroGrams = 500.0
    /// The longest name, in characters (spec 016, issue #54).
    static let maxNameLength = 40

    /// Why this Food Entry can't be saved at `now`; nil when it can.
    public func refusal(now: Date) -> FoodEntryRefusal? {
        let macros = [protein, fat, carbs].compactMap { $0 }
        if kilocalories < 0 || macros.contains(where: { $0 < 0 }) { return .negative }
        if kilocalories > Self.maxKilocalories { return .tooManyCalories }
        if macros.contains(where: { $0 > Self.maxMacroGrams }) { return .macroTooLarge }
        if let name, name.count > Self.maxNameLength { return .nameTooLong }
        if time > now { return .inTheFuture }
        return nil
    }
}
