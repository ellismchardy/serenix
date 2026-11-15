import Foundation
import SerenixCore
import SwiftData
import os

/// A Day's Load as stored on the phone (spec 005). Loads are kept forever, one per Day.
@Model
final class StoredDayLoad {
    /// The Day as `yyyy-MM-dd`, so storing a Load for a Day that has one replaces it.
    @Attribute(.unique) var dateKey: String
    var year: Int
    var month: Int
    var dayOfMonth: Int
    var load: Int?
    /// `LoadMissing`'s raw value; nil when `load` is there.
    var missingReason: String?
    /// `DayHeartRate` as JSON (spec 006); nil for a Day without one, including every Day stored
    /// before spec 006 (optional, so the store migrates by itself).
    var heartRate: Data?
    /// The Day's Resting HR, bpm (spec 007); nil for a Day without one, including every Day stored
    /// before spec 007 (optional, so the store migrates by itself).
    var restingHR: Double?
    /// Whether this Day's HR Zones and Resting HR were kept when it was worked out (spec 007, Days
    /// missing their values). Nil reads as not kept: a Day stored before this field, or one whose
    /// values another build of Serenix that doesn't store them dropped (it drops this too).
    var valuesKept: Bool?

    init(_ dayLoad: DayLoad) {
        dateKey = StoredNight.dateKey(dayLoad.day)
        year = dayLoad.day.year
        month = dayLoad.day.month
        dayOfMonth = dayLoad.day.dayOfMonth
        load = dayLoad.load
        missingReason = dayLoad.missingReason?.rawValue
        restingHR = dayLoad.restingHR
        valuesKept = dayLoad.valuesKept
        heartRate = dayLoad.heartRate.flatMap { heartRate in
            do {
                return try JSONEncoder().encode(heartRate)
            } catch {
                loadLog.error(
                    "Couldn't keep a Day's HR Zones: \(error.localizedDescription, privacy: .public)"
                )
                return nil
            }
        }
    }

    var dayLoad: DayLoad {
        DayLoad(
            day: Day(year: year, month: month, day: dayOfMonth),
            load: load,
            missingReason: missingReason.flatMap(LoadMissing.init(rawValue:)),
            heartRate: heartRate.flatMap { data in
                do {
                    return try JSONDecoder().decode(DayHeartRate.self, from: data)
                } catch {
                    // Shown as "not available" rather than hiding the Day's Load.
                    loadLog.error(
                        "Couldn't read a Day's HR Zones: \(error.localizedDescription, privacy: .public)"
                    )
                    return nil
                }
            },
            restingHR: restingHR,
            valuesKept: valuesKept ?? false
        )
    }
}

/// Works out each Day's Resting HR (spec 007) and Load (spec 005) from stored History Records and
/// keeps them, one Day at a time so at most a Day of History Records (~86,000) is in memory. Run
/// it off the main thread.
enum DayLoadStore {
    /// Every stored Day Load, oldest first.
    static func dayLoads(in container: ModelContainer) throws -> [DayLoad] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<StoredDayLoad>())
            .map(\.dayLoad)
            .sorted { $0.day < $1.day }
    }

    /// Works out the Resting HR of `rebuild.day` again from the History Records `rebuild` names and
    /// the stored `nights` (spec 007), then its Load from those records, the stored Days with this
    /// Resting HR, and `profile`, and replaces the stored Day.
    static func apply(
        _ rebuild: DayRebuild,
        nights: [Night],
        profile: Profile,
        in container: ModelContainer,
        timeZone: TimeZone
    ) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let records = try NightStore.historyRecords(in: rebuild.records, context: context)
        let restingHR = SerenixCore.restingHR(
            of: rebuild.day,
            records: records,
            nights: nights,
            in: timeZone
        )
        // Load reads only the Days' Resting HR, so neither fetch nor decode their HR Zones.
        var storedDaysDescriptor = FetchDescriptor<StoredDayLoad>()
        storedDaysDescriptor.propertiesToFetch = [\.year, \.month, \.dayOfMonth, \.restingHR]
        let storedDays = try context.fetch(storedDaysDescriptor).map { stored in
            DayLoad(
                day: Day(year: stored.year, month: stored.month, day: stored.dayOfMonth),
                load: nil,
                restingHR: stored.restingHR
            )
        }
        // The new entry comes last, so it replaces the stored one for this Day.
        let dayLoad = SerenixCore.load(
            of: rebuild.day,
            records: records,
            days: storedDays + [DayLoad(day: rebuild.day, load: nil, restingHR: restingHR)],
            profile: profile,
            in: timeZone
        )
        // `dateKey` is unique, so this replaces the stored Load for that Day.
        context.insert(StoredDayLoad(dayLoad))
        try context.save()
    }

    /// The Day rebuilds still to do, kept on the phone until each is applied, as
    /// `NightStore.pendingRebuilds`.
    static var pendingRebuilds: [DayRebuild] {
        get {
            guard let data = UserDefaults.standard.data(forKey: pendingRebuildsKey) else {
                return []
            }
            do {
                return try JSONDecoder().decode([DayRebuild].self, from: data)
            } catch {
                // A queue that can't be read is dropped rather than blocking every later one.
                loadLog.error(
                    "Couldn't read queued Day rebuilds: \(error.localizedDescription, privacy: .public)"
                )
                return []
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: pendingRebuildsKey)
            } catch {
                loadLog.error(
                    "Couldn't keep queued Day rebuilds: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}

private let pendingRebuildsKey = "pendingDayRebuilds"
private let loadLog = Logger(subsystem: "com.ellismchardy.Serenix", category: "load")
