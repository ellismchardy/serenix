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
