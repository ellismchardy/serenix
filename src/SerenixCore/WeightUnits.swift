import Foundation

/// How the user's weights are shown and entered (spec 014, Units and Profile). Weights are
/// always stored in kg; the units only change what the user sees and types.
public enum WeightUnits: String, CaseIterable, Sendable {
    case kilograms
    case pounds
    case stonesAndPounds

    /// Kilograms in one pound, exactly, by the international yard and pound agreement (1959).
    public static let kilogramsPerPound = 0.45359237
    /// Pounds in one stone, by definition (Weights and Measures Act 1985).
    public static let poundsPerStone = 14

    /// `kilograms` to one decimal in these units with a "." point: "82.4 kg", "181.7 lb",
    /// "12 st 13.7 lb".
    public func text(_ kilograms: Double) -> String {
        text(kilograms, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// `kilograms` to one decimal in these units, with `locale`'s decimal separator and never a
    /// grouping separator. For stones the total pounds are rounded first, so the pounds part
    /// never reads 14.0.
    public func text(_ kilograms: Double, locale: Locale) -> String {
        let shown = fields(kilograms)
        let number = shown.rest.formatted(
            .number.precision(.fractionLength(1)).grouping(.never).locale(locale)
        )
        switch self {
        case .kilograms: return "\(number) kg"
        case .pounds: return "\(number) lb"
        case .stonesAndPounds: return "\(shown.stones ?? 0) st \(number) lb"
        }
    }

    /// A change in weight per week, to one decimal with its sign: "−0.5 kg a week",
    /// "+0.2 kg a week", "0.0 kg a week" when it rounds to nothing. In st and lb it shows in lb,
    /// since a week's change is under a stone.
    public func rateText(_ kilogramsPerWeek: Double, locale: Locale) -> String {
        let units: WeightUnits = self == .kilograms ? .kilograms : .pounds
        let rest = units.fields(abs(kilogramsPerWeek)).rest
        let number = rest.formatted(
            .number.precision(.fractionLength(1)).grouping(.never).locale(locale)
        )
        let sign = rest == 0 ? "" : kilogramsPerWeek < 0 ? "−" : "+"
        return "\(sign)\(number) \(units == .kilograms ? "kg" : "lb") a week"
    }

    /// What the chart plots: kg in kg units, total pounds in lb or st units.
    public func chartValue(_ kilograms: Double) -> Double {
        self == .kilograms ? kilograms : kilograms / Self.kilogramsPerPound
    }

    /// `kilograms` as a Weigh-in sheet fills it in, to one decimal: kg, lb, or whole stones and
    /// the pounds left over (rounded as a whole first, so never 14.0 lb).
    public func fields(_ kilograms: Double) -> WeightFields {
        switch self {
        case .kilograms:
            return WeightFields(stones: nil, rest: Self.oneDecimal(kilograms))
        case .pounds:
            return WeightFields(
                stones: nil,
                rest: Self.oneDecimal(kilograms / Self.kilogramsPerPound)
            )
        case .stonesAndPounds:
            let tenthsOfPounds = Int((kilograms / Self.kilogramsPerPound * 10).rounded())
            let tenthsPerStone = Self.poundsPerStone * 10
            return WeightFields(
                stones: tenthsOfPounds / tenthsPerStone,
                rest: Double(tenthsOfPounds % tenthsPerStone) / 10
            )
        }
    }

    /// The weight a Weigh-in sheet's fields hold, in kg.
    public func kilograms(_ fields: WeightFields) -> Double {
        switch self {
        case .kilograms:
            return fields.rest
        case .pounds:
            return fields.rest * Self.kilogramsPerPound
        case .stonesAndPounds:
            let pounds = Double((fields.stones ?? 0) * Self.poundsPerStone) + fields.rest
            return pounds * Self.kilogramsPerPound
        }
    }

    private static func oneDecimal(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}

/// A weight as a Weigh-in sheet's fields hold it: kg, lb, or (in st and lb) whole stones and
/// the pounds left over.
public struct WeightFields: Equatable, Sendable {
    /// Whole stones, in st and lb only.
    public let stones: Int?
    /// kg, lb, or the pounds after whole stones.
    public let rest: Double

    public init(stones: Int?, rest: Double) {
        self.stones = stones
        self.rest = rest
    }
}

/// The Profile's height as shown and picked (spec 014, Units and Profile): cm with kg, ft and in
/// with lb or st. Height is always stored in cm.
public enum Height {
    /// Centimetres in one inch, exactly, by the international yard and pound agreement (1959).
    static let centimetresPerInch = 2.54
    /// Inches in one foot.
    static let inchesPerFoot = 12
    /// The heights offered, in whole cm (120–230) or whole inches (4 ft to 7 ft 6 in): wide
    /// enough for any adult.
    static let centimetreOptions = 120...230
    static let inchOptions = 48...90

    /// `centimetres` as "180 cm", or "6 ft 0 in" in lb or st units.
    public static func text(centimetres: Double, units: WeightUnits) -> String {
        guard units != .kilograms else { return "\(Int(centimetres.rounded())) cm" }
        let inches = Int((centimetres / centimetresPerInch).rounded())
        return "\(inches / inchesPerFoot) ft \(inches % inchesPerFoot) in"
    }

    /// The heights the picker offers, in cm: whole cm, or whole inches in lb or st units, so no
    /// two read the same.
    public static func options(units: WeightUnits) -> [Double] {
        guard units != .kilograms else { return centimetreOptions.map(Double.init) }
        return inchOptions.map { Double($0) * centimetresPerInch }
    }
}
