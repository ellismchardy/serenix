import Foundation
import SerenixCore
import SwiftData

/// A Night as stored on the phone (spec 003). Nights are kept forever (docs/architecture.md),
/// one per date.
@Model
final class StoredNight {
    /// The Night's date as `yyyy-MM-dd`, so storing a Night for a date that has one replaces it.
    /// The date is also kept as numbers to rebuild the `Day`; iOS 17 has no compound `#Unique`.
    @Attribute(.unique) var dateKey: String
    var year: Int
    var month: Int
    var dayOfMonth: Int
    var restingHR: Double?
    var hrv: Double?
    var respiratoryRate: Double?
    var skinTemperature: Double?
    var spo2: Double?
    var sleepOnset: Date?
    var finalWake: Date?
    var timeAsleep: TimeInterval?
    var timeInBedStart: Date?
    var timeInBedEnd: Date?

    init(_ night: Night) {
        dateKey = Self.dateKey(night.day)
        year = night.day.year
        month = night.day.month
        dayOfMonth = night.day.dayOfMonth
        restingHR = night.restingHR
        hrv = night.hrv
        respiratoryRate = night.respiratoryRate
        skinTemperature = night.skinTemperature
        spo2 = night.spo2
        sleepOnset = night.sleepOnset
        finalWake = night.finalWake
        timeAsleep = night.timeAsleep
        timeInBedStart = night.timeInBedStart
        timeInBedEnd = night.timeInBedEnd
    }

    var night: Night {
        Night(
            day: Day(year: year, month: month, day: dayOfMonth),
            restingHR: restingHR,
            hrv: hrv,
            respiratoryRate: respiratoryRate,
            skinTemperature: skinTemperature,
            spo2: spo2,
            sleepOnset: sleepOnset,
            finalWake: finalWake,
            timeAsleep: timeAsleep,
            timeInBedStart: timeInBedStart,
            timeInBedEnd: timeInBedEnd
        )
    }

    static func dateKey(_ day: Day) -> String {
        let month = day.month < 10 ? "0\(day.month)" : "\(day.month)"
        let dayOfMonth = day.dayOfMonth < 10 ? "0\(day.dayOfMonth)" : "\(day.dayOfMonth)"
        return "\(day.year)-\(month)-\(dayOfMonth)"
    }
}

/// Works Nights out from stored History Records and keeps them (spec 003), one date at a time so
/// at most two night windows (~170,000 History Records) are in memory. Run it off the main
/// thread.
enum NightStore {
    /// Every stored Night, oldest first.
    static func nights(in container: ModelContainer) throws -> [Night] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<StoredNight>())
            .map(\.night)
            .sorted { $0.day < $1.day }
    }

    /// Works out the Night dated `rebuild.day` again from the History Records `rebuild` names
    /// and replaces the stored one; if they give no Night that date, none is kept.
    static func apply(
        _ rebuild: NightRebuild,
        in container: ModelContainer,
        timeZone: TimeZone
    ) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let records = try historyRecords(in: rebuild.records, context: context)
        let night = SerenixCore.nights(from: records, in: timeZone).first {
            $0.day == rebuild.day
        }
        if let night {
            // `dateKey` is unique, so this replaces the stored Night for that date.
            context.insert(StoredNight(night))
        } else {
            let key = StoredNight.dateKey(rebuild.day)
            try context.delete(model: StoredNight.self, where: #Predicate { $0.dateKey == key })
        }
        try context.save()
    }

    /// The Night rebuilds still to do. They're kept on the phone until each is applied, so a
    /// sync's Nights are still worked out if iOS ends Serenix before the rebuild finishes.
    static var pendingRebuilds: [NightRebuild] {
        get {
            let saved = UserDefaults.standard.array(forKey: pendingRebuildsKey) as? [[Double]]
            return (saved ?? []).compactMap { values in
                guard values.count == 5 else { return nil }
                return NightRebuild(
                    day: Day(year: Int(values[0]), month: Int(values[1]), day: Int(values[2])),
                    records: DateInterval(
                        start: Date(timeIntervalSince1970: values[3]),
                        end: Date(timeIntervalSince1970: values[4])
                    )
                )
            }
        }
        set {
            let values = newValue.map { rebuild in
                [
                    Double(rebuild.day.year), Double(rebuild.day.month),
                    Double(rebuild.day.dayOfMonth), rebuild.records.start.timeIntervalSince1970,
                    rebuild.records.end.timeIntervalSince1970,
                ]
            }
            UserDefaults.standard.set(values, forKey: pendingRebuildsKey)
        }
    }

    /// The stored History Records in `interval` (end excluded), oldest first, read in batches.
    /// Their raw bytes aren't read: the Night methods don't use them.
    private static func historyRecords(
        in interval: DateInterval,
        context: ModelContext
    ) throws -> [HistoryRecord] {
        let start = interval.start
        let end = interval.end
        var descriptor = FetchDescriptor<StoredHistoryRecord>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        descriptor.propertiesToFetch = [
            \.recordCounter, \.timestamp, \.heartRate, \.rrIntervals, \.motion,
            \.skinTemperature, \.steps, \.spo2, \.isInSpO2Window,
        ]
        var records: [HistoryRecord] = []
        try context.enumerate(descriptor, batchSize: readBatchSize) { stored in
            records.append(
                HistoryRecord(
                    recordCounter: UInt32(stored.recordCounter),
                    timestamp: stored.timestamp,
                    heartRate: stored.heartRate,
                    rrIntervals: stored.rrIntervals,
                    motion: stored.motion,
                    skinTemperature: stored.skinTemperature,
                    steps: stored.steps,
                    spo2: stored.spo2,
                    isInSpO2Window: stored.isInSpO2Window,
                    rawBytes: []
                )
            )
        }
        return records
    }
}

/// How many History Records `NightStore` loads from the store at a time.
private let readBatchSize = 5_000
private let pendingRebuildsKey = "pendingNightRebuilds"
