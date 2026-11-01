import Foundation

/// A Day's heart rate against its Max HR (spec 006), worked out with its Load and kept with it.
public struct DayHeartRate: Equatable, Codable, Sendable {
    /// Seconds in each HR Zone; every HR Zone has a key (0 when none).
    public var zoneSeconds: [HRZone: Int]
    public var maxHRUsed: MaxHRUsed

    public init(zoneSeconds: [HRZone: Int], maxHRUsed: MaxHRUsed) {
        self.zoneSeconds = zoneSeconds
        self.maxHRUsed = maxHRUsed
    }

    /// The HR Zone seconds of `heartRates`, one per second, against `maxHRUsed`.
    init(heartRates: [Int], maxHRUsed: MaxHRUsed) {
        var seconds = Dictionary(uniqueKeysWithValues: HRZone.allCases.map { ($0, 0) })
        for heartRate in heartRates {
            if let zone = HRZone.zone(forHeartRate: heartRate, maxHR: maxHRUsed.bpm) {
                seconds[zone, default: 0] += 1
            }
        }
        self.init(zoneSeconds: seconds, maxHRUsed: maxHRUsed)
    }
}

/// Whether a Max HR was entered or estimated from age (spec 005).
public enum MaxHRSource: String, Codable, Sendable {
    case entered, estimated
}

/// The Max HR a Day's Load and HR Zones were worked out with (spec 006).
public struct MaxHRUsed: Equatable, Codable, Sendable {
    public var bpm: Double
    public var source: MaxHRSource

    public init(bpm: Double, source: MaxHRSource) {
        self.bpm = bpm
        self.source = source
    }
}
