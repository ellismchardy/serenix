import Foundation
import SerenixCore

/// A stretch of whole minutes of hand-built History Records (spec 003's Sleep Period method).
enum RecordStretch {
    /// Minutes of 60 records 1 s apart with the Strap never turning: 0 active seconds, so each is
    /// a sleep minute.
    case still(minutes: Int)
    /// Minutes of 60 records 1 s apart with the Strap turning 10° every second: about 60 active
    /// seconds, so each is a wake minute and, three in a row, out of bed.
    case moving(minutes: Int)
    /// Minutes of only 29 still records (seconds 0–28): too few for the minute to have data.
    case sparse(minutes: Int)
}

/// Heart rate of every hand-built record, bpm. Constant, so heart rate never extends a wake bout
/// and Resting HR is exactly this.
private let builtHeartRate = 55

/// History Records for `stretches`, back to back from `start` (which should be a whole UTC
/// minute). Every record has heart rate `builtHeartRate`, skin temperature 33 °C, no RR
/// intervals, no SpO2, and a Record Counter one higher than the last, from `firstRecordCounter`.
func historyRecords(
    startingAt start: Date,
    _ stretches: [RecordStretch],
    firstRecordCounter: UInt32 = 1
) -> [HistoryRecord] {
    var records: [HistoryRecord] = []
    var minuteStart = start
    var counter = firstRecordCounter
    for stretch in stretches {
        let (minutes, seconds, isMoving): (Int, Int, Bool) =
            switch stretch {
            case .still(let minutes): (minutes, 60, false)
            case .moving(let minutes): (minutes, 60, true)
            case .sparse(let minutes): (minutes, 29, false)
            }
        for _ in 0..<minutes {
            for second in 0..<seconds {
                // Moving records alternate by Record Counter, so the turn carries on across
                // minutes.
                let motion = isMoving && counter % 2 == 1 ? turnedMotion : stillMotion
                records.append(
                    HistoryRecord(
                        recordCounter: counter,
                        timestamp: minuteStart.addingTimeInterval(TimeInterval(second)),
                        heartRate: builtHeartRate,
                        rrIntervals: [],
                        motion: motion,
                        skinTemperature: 33,
                        steps: 0,
                        spo2: 0,
                        isInSpO2Window: false,
                        rawBytes: []
                    )
                )
                counter += 1
            }
            minuteStart = minuteStart.addingTimeInterval(60)
        }
    }
    return records
}

/// One History Record a second at `bpm`, from `start`, with increasing Record Counters (spec
/// 005's Load and spec 006's HR Zones).
func historyRecords(
    at bpm: Int,
    for seconds: Int,
    from start: Date,
    firstRecordCounter: UInt32 = 1
) -> [HistoryRecord] {
    (0..<seconds).map { offset in
        HistoryRecord(
            recordCounter: firstRecordCounter + UInt32(offset),
            timestamp: start.addingTimeInterval(TimeInterval(offset)),
            heartRate: bpm,
            rrIntervals: [],
            // Motion is ignored by Load and HR Zones.
            motion: [1, 0, 0, 0],
            skinTemperature: 33,
            steps: 0,
            spo2: 0,
            isInSpO2Window: false,
            rawBytes: []
        )
    }
}

/// The resting orientation quaternion.
private let stillMotion: [Float] = [0, 0, 0, 1]
/// `stillMotion` turned 10° about one axis: (sin 5°, 0, 0, cos 5°), well over the 2° that makes
/// a second active.
private let turnedMotion: [Float] = [0.0871557, 0, 0, 0.9961947]

/// A UTC date, for hand-built records and their expected times.
func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let components = DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    )
    return calendar.date(from: components)!
}
