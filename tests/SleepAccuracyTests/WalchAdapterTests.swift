import Foundation
import SerenixCore
import SleepAccuracy
import Testing

/// A fresh folder in Walch's sleep-accel 1.0.0 layout, removed after the test.
private struct WalchFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("walch-\(UUID().uuidString)", isDirectory: true)
        for sub in ["motion", "heart_rate", "labels"] {
            try FileManager.default.createDirectory(
                at: url.appendingPathComponent(sub, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }

    func write(_ lines: [String], to path: String) throws {
        try (lines.joined(separator: "\n") + "\n")
            .write(to: url.appendingPathComponent(path), atomically: true, encoding: .utf8)
    }

    /// Writes all three files of one recording; nil leaves that file out.
    func recording(
        _ id: String,
        motion: [String]?,
        heartRate: [String]? = ["0,60"],
        labels: [String]? = ["0 0"]
    ) throws {
        if let motion { try write(motion, to: "motion/\(id)_acceleration.txt") }
        if let heartRate { try write(heartRate, to: "heart_rate/\(id)_heartrate.txt") }
        if let labels { try write(labels, to: "labels/\(id)_labeled_sleep.txt") }
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

private func psgTime(_ seconds: TimeInterval) -> Date {
    WalchAdapter.psgStart.addingTimeInterval(seconds)
}

private func second(_ seconds: TimeInterval, in night: ReferenceNight) -> LabellingSecond? {
    night.seconds.first { $0.time == psgTime(seconds) }
}

/// Spec 019, Walch adapter: gravity along z in second 0 and along x in second 1 gives second 1 a
/// Tilt of 90°; second 0 has no second before it, so no angle.
@Test func gravityTurningFromZToXGivesATiltOf90Degrees() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording(
        "1",
        motion: ["0.0 0 0 1", "0.5 0 0 1", "1.0 1 0 0", "1.5 1 0 0"]
    )

    let nights = try WalchAdapter.referenceNights(in: folder.url)

    let night = try #require(nights.first)
    let first = try #require(second(0, in: night))
    let next = try #require(second(1, in: night))
    #expect(first.angle == nil)
    #expect(abs(try #require(next.angle) - 90) < 1e-6)
}

/// Spec 019, Walch adapter: a second with no samples has no angle (it isn't in the labelling
/// input at all), and nor does the second after it.
@Test func aSecondWithNoSamplesLeavesNoAngleForTheSecondAfterIt() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording(
        "1",
        motion: ["0.0 0 0 1", "1.0 1 0 0", "3.0 0 0 1", "4.0 1 0 0"]
    )

    let night = try #require(try WalchAdapter.referenceNights(in: folder.url).first)

    #expect(night.seconds.map(\LabellingSecond.time) == [0, 1, 3, 4].map(psgTime))
    #expect(second(2, in: night) == nil)
    #expect(try #require(second(3, in: night)).angle == nil)
    #expect(try #require(second(4, in: night)).angle != nil)
}

/// Spec 019, Walch adapter: readings at 0 s (60 bpm) and 20 s (70 bpm) give seconds 0–15 60 bpm,
/// seconds 16–19 none, and second 20 70 bpm.
@Test func aHeartRateReadingIsCarriedForwardAtMost15Seconds() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording(
        "1",
        motion: (0...20).map { "\($0).0 0 0 1" },
        heartRate: ["0,60", "20,70"]
    )

    let night = try #require(try WalchAdapter.referenceNights(in: folder.url).first)

    #expect(WalchAdapter.longestHeartRateCarry == 15)
    #expect(night.seconds.count == 21)
    for s in 0...15 {
        #expect(try #require(second(TimeInterval(s), in: night)).heartRate == 60, "second \(s)")
    }
    for s in 16...19 {
        #expect(try #require(second(TimeInterval(s), in: night)).heartRate == nil, "second \(s)")
    }
    #expect(try #require(second(20, in: night)).heartRate == 70)
}

/// Spec 019, Walch adapter: labels 0, 1, 2, 3, 4, 5 and −1 become wake, N1, N2, N3, N3, REM and
/// unscored, each Epoch starting at PSG time 0 plus its label time.
@Test func walchLabelsMapToEpochLabels() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording(
        "1",
        motion: ["0.0 0 0 1"],
        labels: ["0 0", "30 1", "60 2", "90 3", "120 4", "150 5", "180 -1"]
    )

    let night = try #require(try WalchAdapter.referenceNights(in: folder.url).first)

    #expect(
        night.epochs == [
            Epoch(start: psgTime(0), label: .wake),
            Epoch(start: psgTime(30), label: .n1),
            Epoch(start: psgTime(60), label: .n2),
            Epoch(start: psgTime(90), label: .n3),
            Epoch(start: psgTime(120), label: .n3),
            Epoch(start: psgTime(150), label: .rem),
            Epoch(start: psgTime(180), label: .unscored),
        ]
    )
}

/// Spec 019, Walch adapter: PSG time 0 falls on a whole UTC minute, so the Epochs at 0 s and
/// 30 s share one Serenix minute.
@Test func psgTimeZeroFallsOnAWholeUTCMinute() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording("1", motion: ["0.0 0 0 1"], labels: ["0 0", "30 0"])

    let night = try #require(try WalchAdapter.referenceNights(in: folder.url).first)

    #expect(WalchAdapter.psgStart.timeIntervalSince1970.truncatingRemainder(dividingBy: 60) == 0)
    #expect(night.epochs.count == 2)
    let minutes = night.epochs.map { ($0.start.timeIntervalSince1970 / 60).rounded(.down) }
    #expect(minutes[0] == minutes[1])
}

/// Spec 019, Walch adapter: seconds before PSG time 0 are kept in the labelling input.
@Test func secondsBeforePSGTimeZeroAreKept() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording(
        "1",
        motion: (1...90).reversed().map { "-\($0).0 0 0 1" } + ["0.0 0 0 1"]
    )

    let night = try #require(try WalchAdapter.referenceNights(in: folder.url).first)

    #expect(night.seconds.first?.time == psgTime(-90))
    #expect(night.seconds.count == 91)
}

/// Spec 019, Walch adapter: a recording missing its labels file stops the run, naming the
/// recording and the file.
@Test func aRecordingMissingItsLabelsFileThrowsNamingIt() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording("7", motion: ["0.0 0 0 1"], labels: nil)

    #expect(
        throws: WalchAdapterError.missingFile(recording: "7", file: "labels/7_labeled_sleep.txt")
    ) {
        try WalchAdapter.referenceNights(in: folder.url)
    }
}

/// Spec 019, Open questions: a label time off the 30-s grid is rejected, naming the recording.
@Test func aLabelOffThe30SecondGridThrowsNamingIt() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording("3", motion: ["0.0 0 0 1"], labels: ["0 0", "45 0"])

    #expect(throws: WalchAdapterError.offGridLabel(recording: "3", time: 45)) {
        try WalchAdapter.referenceNights(in: folder.url)
    }
}

/// Plan 019, Walch file format: the separator isn't documented, so a comma-separated motion file
/// reads the same as a space-separated one.
@Test func aCommaSeparatedMotionFileReadsTheSameAsASpaceSeparatedOne() throws {
    let samples = [
        ["0.0", "0", "0", "1"], ["0.5", "0", "0.1", "0.9"], ["1.0", "1", "0", "0"],
        ["2.2", "0.6", "0.6", "0.5"],
    ]
    let spaced = try WalchFolder()
    defer { spaced.remove() }
    let commas = try WalchFolder()
    defer { commas.remove() }
    try spaced.recording("1", motion: samples.map { $0.joined(separator: " ") })
    try commas.recording("1", motion: samples.map { $0.joined(separator: ",") })

    let fromSpaced = try #require(try WalchAdapter.referenceNights(in: spaced.url).first)
    let fromCommas = try #require(try WalchAdapter.referenceNights(in: commas.url).first)

    #expect(fromSpaced.seconds.count == 3)
    #expect(fromCommas.seconds == fromSpaced.seconds)
}

/// Spec 019, command line: a folder with no Walch recordings (a wrong `--data`) stops the run
/// with a message naming it, rather than scoring nothing.
@Test func aFolderWithNoRecordingsThrowsNamingIt() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }

    #expect(throws: WalchAdapterError.noRecordings(folder: folder.url.path)) {
        try WalchAdapter.referenceNights(in: folder.url)
    }
}

/// Spec 019 (never guess): a time that isn't a finite number, or a line short of columns, stops
/// the run naming the recording, file and line rather than crashing.
@Test func aLineWithoutEnoughFiniteNumbersThrowsNamingIt() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording("4", motion: ["0.0 0 0 1", "nan 0 0 1"])

    #expect(
        throws: WalchAdapterError.malformedLine(
            recording: "4",
            file: "motion/4_acceleration.txt",
            line: 2
        )
    ) {
        try WalchAdapter.referenceNights(in: folder.url)
    }
}

/// Spec 019 (never guess): a stage code Walch doesn't define stops the run naming it.
@Test func anUnknownStageCodeThrowsNamingIt() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording("5", motion: ["0.0 0 0 1"], labels: ["0 0", "30 7"])

    #expect(throws: WalchAdapterError.unknownLabel(recording: "5", time: 30, code: 7)) {
        try WalchAdapter.referenceNights(in: folder.url)
    }
}

/// Spec 019: a file that exists but isn't UTF-8 text is reported as unreadable, not missing.
@Test func aFileThatIsNotTextThrowsUnreadableNotMissing() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording("6", motion: ["0.0 0 0 1"])
    try Data([0xFF, 0xFE, 0xFD])
        .write(to: folder.url.appendingPathComponent("labels/6_labeled_sleep.txt"))

    #expect(
        throws: WalchAdapterError.unreadableFile(recording: "6", file: "labels/6_labeled_sleep.txt")
    ) {
        try WalchAdapter.referenceNights(in: folder.url)
    }
}

/// An all-zero reading has no gravity direction, so neither its second nor the next gets a Tilt
/// (rather than a made-up 90°).
@Test func anAllZeroReadingGivesNoTilt() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording("8", motion: ["0.0 0 0 1", "1.0 0 0 0", "2.0 1 0 0", "3.0 1 0 0"])

    let night = try #require(try WalchAdapter.referenceNights(in: folder.url).first)

    #expect(try #require(second(1, in: night)).angle == nil)
    #expect(try #require(second(2, in: night)).angle == nil)
    #expect(try #require(second(3, in: night)).angle == 0)
}

/// Spec 019, Walch adapter: with labels at 0 s and 30 s the last Epoch ends at 60 s, so the
/// labelling input runs from −43 200 s (12 h before PSG time 0) to 43 260 s (12 h after 60 s),
/// both ends kept; the seconds just outside, −43 201 s and 43 261 s, are dropped.
@Test func secondsMoreThan12HoursEitherSideOfThePSGAreDropped() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording(
        "1",
        motion: [-43_201, -43_200, 0, 43_260, 43_261].map { "\($0).0 0 0 1" },
        labels: ["0 0", "30 0"]
    )

    let night = try #require(try WalchAdapter.referenceNights(in: folder.url).first)

    #expect(night.seconds.map(\LabellingSecond.time) == [-43_200, 0, 43_260].map(psgTime))
}

/// The 12-hour span keeps or drops whole seconds: a sample at −43 200.5 s falls in second
/// −43 201, outside, so it is dropped; one at 43 260.9 s falls in second 43 260, the last kept.
@Test func theTwelveHourSpanKeepsOrDropsWholeSeconds() throws {
    let folder = try WalchFolder()
    defer { folder.remove() }
    try folder.recording(
        "1",
        motion: ["-43200.5 0 0 1", "0.0 0 0 1", "43260.9 0 0 1"],
        labels: ["0 0", "30 0"]
    )

    let night = try #require(try WalchAdapter.referenceNights(in: folder.url).first)

    #expect(night.seconds.map(\LabellingSecond.time) == [0, 43_260].map(psgTime))
}
