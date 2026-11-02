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

    init(_ dayLoad: DayLoad) {
        dateKey = StoredNight.dateKey(dayLoad.day)
        year = dayLoad.day.year
        month = dayLoad.day.month
        dayOfMonth = dayLoad.day.dayOfMonth
        load = dayLoad.load
        missingReason = dayLoad.missingReason?.rawValue
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
            }
        )
    }
}

/// Works out each Day's Load from stored History Records and keeps it (spec 005), one Day at a
/// time so at most a Day of History Records (~86,000) is in memory. Run it off the main thread.
enum DayLoadStore {
    /// Every stored Day Load, oldest first.
    static func dayLoads(in container: ModelContainer) throws -> [DayLoad] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<StoredDayLoad>())
            .map(\.dayLoad)
            .sorted { $0.day < $1.day }
    }

    /// Works out the Load of `rebuild.day` again from the History Records `rebuild` names, the
    /// stored `nights` and `profile`, and replaces the stored one.
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
        let dayLoad = SerenixCore.load(
            of: rebuild.day,
            records: records,
            nights: nights,
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
