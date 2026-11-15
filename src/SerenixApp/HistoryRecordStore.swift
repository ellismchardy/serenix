import Foundation
import SerenixCore
import SwiftData

/// A History Record as stored on the phone (spec 001): the decoded fields plus the raw bytes, so
/// an improved decoder can re-read them.
@Model
final class StoredHistoryRecord {
    /// Record Counter and timestamp together identify a History Record (GLOSSARY), so together
    /// they are the unique key. Storing a record that's already there replaces it with the same
    /// values, so a Batch the Strap re-sends is never stored twice.
    @Attribute(.unique) var identity: String
    var recordCounter: Int
    var timestamp: Date
    var heartRate: Int
    var rrIntervals: [Int]
    var motion: [Float]
    var skinTemperature: Double
    var steps: Int
    var spo2: Int
    var isInSpO2Window: Bool
    var rawBytes: Data

    init(_ record: HistoryRecord) {
        identity = record.identity
        recordCounter = Int(record.recordCounter)
        timestamp = record.timestamp
        heartRate = record.heartRate
        rrIntervals = record.rrIntervals
        motion = record.motion
        skinTemperature = record.skinTemperature
        steps = record.steps
        spo2 = record.spo2
        isInSpO2Window = record.isInSpO2Window
        rawBytes = Data(record.rawBytes)
    }
}

/// Saves the History Records a sync receives, on the phone only (ADR 0001).
final class HistoryRecordStore {
    /// Sendable, so `stats(in:)` can read the store off the main thread. It also holds the stored
    /// Nights and Day Loads, which `NightStore` and `DayLoadStore` work out from these History
    /// Records (specs 003 and 005).
    let container: ModelContainer
    private var context: ModelContext

    init() throws {
        container = try ModelContainer(
            for: StoredHistoryRecord.self,
            StoredNight.self,
            StoredDayLoad.self
        )
        context = Self.makeContext(container)
    }

    func insert(_ records: [HistoryRecord]) {
        for record in records {
            context.insert(StoredHistoryRecord(record))
        }
    }

    /// Writes what's been inserted, then starts a fresh context so a day's sync (~90,000
    /// records) doesn't keep every record in memory.
    func save() throws {
        guard context.hasChanges else { return }
        try context.save()
        context = Self.makeContext(container)
    }

    /// Drops what's been inserted but not saved, so a failed save can't fail the next sync too.
    /// Those History Records were never acknowledged, so the Strap sends them again.
    func discardUnsaved() {
        context = Self.makeContext(container)
    }

    /// What's stored, for the debug screen: how many History Records, the oldest and newest,
    /// and how many gaps their Record Counters have. Call it off the main thread: a month of
    /// History Records is ~2.6 million, so the Record Counters are read in batches.
    static func stats(in container: ModelContainer) throws -> HistoryRecordStats {
        let context = ModelContext(container)
        let count = try context.fetchCount(FetchDescriptor<StoredHistoryRecord>())
        var oldest = FetchDescriptor<StoredHistoryRecord>(sortBy: [SortDescriptor(\.timestamp)])
        oldest.fetchLimit = 1
        var newest = FetchDescriptor<StoredHistoryRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        newest.fetchLimit = 1
        let oldestRecord = try context.fetch(oldest).first
        let newestRecord = try context.fetch(newest).first
        var everyRecord = FetchDescriptor<StoredHistoryRecord>()
        everyRecord.propertiesToFetch = [\.recordCounter]
        var counters: [UInt32] = []
        counters.reserveCapacity(count)
        try context.enumerate(everyRecord, batchSize: statsBatchSize) { record in
            counters.append(UInt32(record.recordCounter))
        }
        return HistoryRecordStats(
            count: count,
            oldest: oldestRecord.map(HistoryRecordStats.End.init),
            newest: newestRecord.map(HistoryRecordStats.End.init),
            gapCount: recordCounterGapCount(counters)
        )
    }

    private static func makeContext(_ container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
}

/// How many History Records `stats(in:)` loads at a time, so only one batch is in memory.
private let statsBatchSize = 5_000

/// What the History Record store holds, for the debug screen.
struct HistoryRecordStats: Equatable, Sendable {
    /// One end of the stored History Records.
    struct End: Equatable, Sendable {
        let recordCounter: Int
        let timestamp: Date

        init(_ record: StoredHistoryRecord) {
            recordCounter = record.recordCounter
            timestamp = record.timestamp
        }
    }

    var count = 0
    var oldest: End?
    var newest: End?
    var gapCount = 0
}
