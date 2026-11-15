import Foundation

/// A Day's heart rate against its Max HR (spec 006), worked out with its Load and kept with it.
public struct DayHeartRate: Equatable, Codable, Sendable {
    /// Seconds in each HR Zone; every HR Zone has a key (0 when none).
    public var zoneSeconds: [HRZone: Int]
    /// Seconds in each HR Zone for each hour of the Day, counted from local midnight, one entry
    /// per started hour: 24, or 23 / 25 across a clock change. Every entry has every HR Zone as a
    /// key (0 when none).
    public var hourlyZoneSeconds: [[HRZone: Int]]
    /// The highest heart rate in the Day's History Records, HR 0 skipped, even under Load's
    /// floor; the earliest time if it repeats. Nil with no heart rate over 0.
    public var highestHR: HighestHR?
    public var maxHRUsed: MaxHRUsed

    public init(
        zoneSeconds: [HRZone: Int],
        hourlyZoneSeconds: [[HRZone: Int]],
        highestHR: HighestHR?,
        maxHRUsed: MaxHRUsed
    ) {
        self.zoneSeconds = zoneSeconds
        self.hourlyZoneSeconds = hourlyZoneSeconds
        self.highestHR = highestHR
        self.maxHRUsed = maxHRUsed
    }

    /// The HR Zone seconds of `records`, one second each, against `maxHRUsed`, in total and by
    /// hour of `span` (the Day, local midnight to midnight; every record falls inside it), and
    /// their highest heart rate.
    init(records: [HistoryRecord], span: DateInterval, maxHRUsed: MaxHRUsed) {
        // Highest first, then earliest.
        let highest =
            records
            .filter { $0.heartRate > 0 }
            .min {
                ($0.heartRate, $1.timestamp) > ($1.heartRate, $0.timestamp)
            }
            .map { HighestHR(bpm: $0.heartRate, time: $0.timestamp) }
        let none = Dictionary(uniqueKeysWithValues: HRZone.allCases.map { ($0, 0) })
        var seconds = none
        // Hours are counted as time elapsed since local midnight, one entry per started hour: a
        // clock change removes or adds entries (23 or 25, or 24 for a 30-minute change).
        let hourCount = Int((span.duration / secondsPerHour).rounded(.up))
        var hourly = Array(repeating: none, count: hourCount)
        for record in records {
            guard let zone = HRZone.zone(forHeartRate: record.heartRate, maxHR: maxHRUsed.bpm)
            else { continue }
            seconds[zone, default: 0] += 1
            let hour = Int(record.timestamp.timeIntervalSince(span.start) / secondsPerHour)
            hourly[hour][zone, default: 0] += 1
        }
        self.init(
            zoneSeconds: seconds,
            hourlyZoneSeconds: hourly,
            highestHR: highest,
            maxHRUsed: maxHRUsed
        )
    }
}

/// A Day's highest heart rate and when it was first reached (spec 006).
public struct HighestHR: Equatable, Codable, Sendable {
    public var bpm: Int
    public var time: Date

    public init(bpm: Int, time: Date) {
        self.bpm = bpm
        self.time = time
    }
}

/// Seconds in an hour.
private let secondsPerHour = 3_600.0

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
