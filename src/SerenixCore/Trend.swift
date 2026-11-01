import Foundation

/// A trend line's values (spec 002, Tiles): the most recent `trendNights` Nights up to and
/// including `night`, oldest first, with the Nights missing the value left out.
func trendValues(of value: (Night) -> Double?, upTo night: Night, among nights: [Night])
    -> [Double]
{
    recentNights(trendNights, upTo: night, among: nights).compactMap(value)
}

/// The `count` most recent Nights up to and including `night`, oldest first.
func recentNights(_ count: Int, upTo night: Night, among nights: [Night]) -> [Night] {
    nights
        .filter { $0.day <= night.day }
        .sorted { $0.day > $1.day }
        .prefix(count)
        .reversed()
}

/// How many Nights a tile's trend line covers (spec 002, Tiles).
let trendNights = 7
