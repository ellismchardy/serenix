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
    private let container: ModelContainer
    private var context: ModelContext

    init() throws {
        container = try ModelContainer(for: StoredHistoryRecord.self)
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

    /// How many History Records are stored.
    func count() throws -> Int {
        try ModelContext(container).fetchCount(FetchDescriptor<StoredHistoryRecord>())
    }

    private static func makeContext(_ container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
}
