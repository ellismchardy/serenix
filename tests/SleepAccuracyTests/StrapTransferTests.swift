import Foundation
import SerenixCore
import SleepAccuracy
import Testing

/// 2027-01-15 08:00:00 UTC, a whole UTC minute.
private let wholeMinute = Date(timeIntervalSince1970: 1_800_000_000)

/// A Strap motion quaternion in the Strap's float order (x, y, z, w) for a rotation of
/// `degrees` about the unit `axis`.
private func quaternion(degrees: Double, about axis: (Double, Double, Double)) -> [Double] {
    let half = degrees * .pi / 360
    let s = sin(half)
    return [axis.0 * s, axis.1 * s, axis.2 * s, cos(half)]
}

/// The Hamilton product `a ⊗ b` of two (x, y, z, w) quaternions.
private func product(_ a: [Double], _ b: [Double]) -> [Double] {
    let (ax, ay, az, aw) = (a[0], a[1], a[2], a[3])
    let (bx, by, bz, bw) = (b[0], b[1], b[2], b[3])
    return [
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    ]
}

private let worldX = (1.0, 0.0, 0.0)
/// The vertical.
private let worldZ = (0.0, 0.0, 1.0)

/// 43 minutes of History Records 1 s apart from `wholeMinute` at 60 bpm. Minutes 0–19 are still
/// at 40° about world x. In minutes 20–22 (seconds 1200–1379) every second turns a further 5°
/// about the vertical from the second before, the first of them included; minutes 23–42 stay
/// still at the last orientation.
/// - Turn: seconds 1200–1379 each turn 5° (> 2°), so 180 active seconds, 60 in each of minutes
///   20–22, which are wake (≥ 10). Their neighbours' 5-minute medians are 0, heart rate never
///   rises, so minutes 0–19 and 23–42 are sleep runs merged across the 3 recorded wake minutes:
///   one Sleep Period over all 43 minutes, 40 minutes asleep.
/// - Tilt: a turn about the vertical moves gravity at the wrist not at all, so no second is
///   active and every minute is sleep: the same Sleep Period, 43 minutes asleep.
/// - Every minute has 60 records; turn and Tilt agree on all but minutes 20–22: 40 of 43.
private func verticalRotationNight() -> [HistoryRecord] {
    var orientation = quaternion(degrees: 40, about: worldX)
    return (0..<(43 * 60)).map { second in
        if (1200..<1380).contains(second) {
            orientation = product(quaternion(degrees: 5, about: worldZ), orientation)
        }
        return HistoryRecord(
            recordCounter: UInt32(second + 1),
            timestamp: wholeMinute.addingTimeInterval(TimeInterval(second)),
            heartRate: 60,
            rrIntervals: [],
            motion: orientation.map { Float($0) },
            skinTemperature: 33,
            steps: 0,
            spo2: 0,
            isInSpO2Window: false,
            rawBytes: []
        )
    }
}

private let strapStamp = RunStamp(
    labeller: "spec003-rule",
    dataset: "hand-built",
    commandLine: "sleep-accuracy strap --data in --out out --threshold 2.0",
    gitSHA: "unknown"
)

private func verticalRotationReport() -> StrapTransferReport {
    StrapTransferReport.compare(
        [(id: "vertical-rotation", records: verticalRotationNight())],
        tiltThreshold: 2.0,
        stamp: strapStamp
    )
}

/// Spec 019, Strap transfer run: on a night where every turn is a rotation about the vertical
/// above 2°, Tilt misses every turn-active second (share 0%) and the turn series has more wake
/// minutes: 3 fewer minutes of Time Asleep.
@Test func turnsAboutTheVerticalAreAllMissedByTiltAndTheTurnSeriesHasMoreWake() throws {
    let report = verticalRotationReport()

    try #require(report.nights.count == 1)
    let night = report.nights[0]
    #expect(night.id == "vertical-rotation")
    #expect(night.turnActiveSeconds == 180)
    #expect(night.alsoTiltActiveShare == 0.0)
    let agreeing = try #require(night.agreeingMinuteShare)
    #expect(abs(agreeing - 40.0 / 43.0) < 1e-9)
    #expect(night.turn.timeAsleep == 40.0)
    #expect(night.tilt.timeAsleep == 43.0)
    #expect(night.timeAsleepDifference == 3.0)
}

/// Spec 019, Strap transfer run: the report holds Time Asleep, Sleep Onset and Final Wake from
/// both series and their differences in minutes, in Markdown and JSON alike.
@Test func theTransferReportHoldsBothSeriesAndTheirDifferences() throws {
    let report = verticalRotationReport()

    #expect(report.threshold == 2.0)
    #expect(report.stamp.thresholds == [2.0])
    try #require(report.nights.count == 1)
    let night = report.nights[0]
    let periodEnd = wholeMinute.addingTimeInterval(43 * 60)
    #expect(night.turn.sleepOnset == wholeMinute)
    #expect(night.tilt.sleepOnset == wholeMinute)
    #expect(night.turn.finalWake == periodEnd)
    #expect(night.tilt.finalWake == periodEnd)
    #expect(night.sleepOnsetDifference == 0)
    #expect(night.finalWakeDifference == 0)

    let markdown = report.markdown()
    let row = try #require(
        markdown.split(separator: "\n").first { $0.hasPrefix("| vertical-rotation |") }
    )
    #expect(row.hasPrefix("| vertical-rotation | 180 | 0% | 93% | 40.0 / 43.0 / 3.0 |"))
    #expect(row.contains(" / 0.0 |"))
    #expect(markdown.contains(strapStamp.labeller))
    #expect(markdown.contains("Tilt threshold: 2°"))
    #expect(markdown.contains(strapStamp.dataset))
    #expect(markdown.contains(strapStamp.commandLine))
    #expect(markdown.contains("Git SHA: unknown"))

    let decoded = try JSONDecoder().decode(StrapTransferReport.self, from: report.json())
    #expect(decoded == report)
}

/// Spec 019, Strap transfer run: History Record files in the fixture CSV format are read into
/// History Records, oldest first, whatever order the rows come in.
@Test func fixtureCSVRowsBecomeHistoryRecordsOldestFirst() throws {
    let text = """
        counter,utc,hr,rr_ms,q0,q1,q2,q3,temp_c,spo2_window,spo2
        2918884,2026-10-28T12:00:01+00:00,65,,0.0098,-0.1650,0.0370,0.9982,32.10,0,0
        2918883,2026-10-28T12:00:00+00:00,64,849 851,0.0200,-0.1653,0.0374,0.9978,32.09,0,0
        """

    let records = try HistoryRecordCSV.records(from: text, file: "night.csv")

    try #require(records.count == 2)
    let noon = Date(timeIntervalSince1970: 1_793_188_800)  // 2026-10-28T12:00:00Z
    #expect(records[0].timestamp == noon)
    #expect(records[0].recordCounter == 2_918_883)
    #expect(records[0].heartRate == 64)
    #expect(records[0].rrIntervals == [849, 851])
    #expect(records[0].motion == [0.0200, -0.1653, 0.0374, 0.9978])
    #expect(records[1].timestamp == noon.addingTimeInterval(1))
    #expect(records[1].recordCounter == 2_918_884)
    #expect(records[1].heartRate == 65)
    #expect(records[1].rrIntervals == [])
    #expect(records[1].motion == [0.0098, -0.1650, 0.0370, 0.9982])
}

/// Spec 019: a History Record file without the fixture header stops the run, naming the file.
@Test func aFixtureCSVWithoutItsHeaderIsRejected() {
    let text = "2918883,2026-10-28T12:00:00+00:00,64,849,0.0200,-0.1653,0.0374,0.9978,32.09,0,0"

    #expect(throws: HistoryRecordCSVError.missingHeader(file: "night.csv")) {
        try HistoryRecordCSV.records(from: text, file: "night.csv")
    }
}

/// Spec 019: a row whose heart rate isn't a number stops the run, naming the file and its line
/// (1-based, the header being line 1).
@Test func aFixtureCSVRowWithANonNumberHeartRateIsRejected() {
    let text = """
        counter,utc,hr,rr_ms,q0,q1,q2,q3,temp_c,spo2_window,spo2
        2918883,2026-10-28T12:00:00+00:00,abc,849,0.0200,-0.1653,0.0374,0.9978,32.09,0,0
        """

    #expect(throws: HistoryRecordCSVError.malformedLine(file: "night.csv", line: 2)) {
        try HistoryRecordCSV.records(from: text, file: "night.csv")
    }
}

/// Spec 019: the same History Record twice (same timestamp and Record Counter) is read once,
/// and a file with the optional `steps` column reads its steps.
@Test func aRepeatedRowIsReadOnceAndAStepsColumnIsRead() throws {
    let text = """
        counter,utc,hr,rr_ms,q0,q1,q2,q3,temp_c,spo2_window,spo2,steps
        2918883,2026-10-28T12:00:00+00:00,64,849,0.0200,-0.1653,0.0374,0.9978,32.09,0,0,3
        2918883,2026-10-28T12:00:00+00:00,64,849,0.0200,-0.1653,0.0374,0.9978,32.09,0,0,3
        """

    let records = try HistoryRecordCSV.records(from: text, file: "day.csv")

    try #require(records.count == 1)
    #expect(records[0].steps == 3)
}

/// Spec 019 (never guess): an RR interval that isn't a whole number, a motion value that isn't
/// finite, or a row wider than the header stops the run, naming the file and line.
@Test func aRowWithABadRRIntervalMotionValueOrWidthIsRejected() {
    let header = "counter,utc,hr,rr_ms,q0,q1,q2,q3,temp_c,spo2_window,spo2"
    let rows = [
        "2918883,2026-10-28T12:00:00+00:00,64,849 8x1,0.0200,-0.1653,0.0374,0.9978,32.09,0,0",
        "2918883,2026-10-28T12:00:00+00:00,64,849,nan,-0.1653,0.0374,0.9978,32.09,0,0",
        "2918883,2026-10-28T12:00:00+00:00,64,849,0.0200,-0.1653,0.0374,0.9978,32.09,0,0,3",
    ]
    for row in rows {
        #expect(throws: HistoryRecordCSVError.malformedLine(file: "night.csv", line: 2)) {
            try HistoryRecordCSV.records(from: header + "\n" + row, file: "night.csv")
        }
    }
}
