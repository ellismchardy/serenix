import Foundation

/// A trend line's values (spec 002, Tiles): the most recent `trendNights` Nights up to and
/// including `night`, oldest first, with the Nights missing the value left out.
func trendValues(of value: (Night) -> Double?, upTo night: Night, among nights: [Night])
    -> [Double]
{
    nights
        .filter { $0.day <= night.day }
        .sorted { $0.day > $1.day }
        .prefix(trendNights)
        .reversed()
        .compactMap(value)
}

/// How many Nights a tile's trend line covers (spec 002, Tiles).
let trendNights = 7
