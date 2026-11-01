import Foundation

/// One of five bands of heart rate by share of Max HR (spec 006; GLOSSARY). Never bare "Zone",
/// which is a Nightly Metric against its Baseline. Stored by number ("1"–"5") as a key.
public enum HRZone: Int, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case one = 1
    case two, three, four, five

    /// Each HR Zone's lower edge as a share of Max HR, from HR Zone 5 down, so the first edge a
    /// heart rate reaches is its HR Zone (Edwards' bands; issue 16). HR Zone 1's edge is Load's
    /// floor, so time in HR Zones is the time Load counts.
    static let lowerEdges: [(zone: HRZone, share: Double)] = [
        (.five, 0.9), (.four, 0.8), (.three, 0.7), (.two, 0.6),
        (.one, LoadMethod.floorFractionOfMaxHR),
    ]

    /// The HR Zone `heartRate` falls in for `maxHR`, by its exact share (each band includes its
    /// lower edge; over Max HR is still HR Zone 5), or nil under HR Zone 1 or at 0.
    public static func zone(forHeartRate heartRate: Int, maxHR: Double) -> HRZone? {
        guard heartRate > 0 else { return nil }
        let share = Double(heartRate) / maxHR
        return lowerEdges.first { share >= $0.share }?.zone
    }
}
