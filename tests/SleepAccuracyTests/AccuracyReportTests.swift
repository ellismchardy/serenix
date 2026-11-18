import Foundation
import SerenixCore
import SleepAccuracy
import Testing

/// 2027-01-15 08:00:00 UTC, a whole UTC minute.
private let wholeMinute = Date(timeIntervalSince1970: 1_800_000_000)

/// Seconds from `wholeMinute` at 60 bpm, each with the angle `angle(offset)` gives.
private func labellingSeconds(
    _ offsets: some Sequence<Int>,
    angle: (Int) -> Double = { _ in 0 }
) -> [LabellingSecond] {
    offsets.map {
        LabellingSecond(
            time: wholeMinute.addingTimeInterval(TimeInterval($0)),
            heartRate: 60,
            angle: angle($0)
        )
    }
}

/// Consecutive Epochs from `wholeMinute`, labelled by `label(index)`.
private func epochs(_ count: Int, label: (Int) -> EpochLabel = { _ in .n2 }) -> [Epoch] {
    (0..<count).map {
        Epoch(start: wholeMinute.addingTimeInterval(TimeInterval($0 * 30)), label: label($0))
    }
}

/// 30 minutes at 60 bpm whose seconds move 1.5° everywhere but minutes 10–12, which move 2.5°.
/// PSG is wake at those minutes' Epochs (20–25) and N2 elsewhere (60 Epochs).
/// - At 1.0° every second is active, so every minute is wake: Serenix calls nothing asleep, κ 0.
/// - At 2.0° (and 2.2°) only minutes 10–12 are active (60 active seconds, wake); the sleep runs
///   0–9 and 13–29 merge into one Sleep Period over all 30 minutes with minutes 10–12 as wake
///   inside it, matching PSG Epoch for Epoch: κ 1.
/// - At 3.0° no second is active, so every minute is sleep: Serenix calls everything asleep, κ 0.
private func sweepNight() -> ReferenceNight {
    ReferenceNight(
        id: "sweep-night",
        seconds: labellingSeconds(0..<(30 * 60)) { (10...12).contains($0 / 60) ? 2.5 : 1.5 },
        epochs: epochs(60) { (20...25).contains($0) ? .wake : .n2 }
    )
}

private let sweepStamp = RunStamp(
    labeller: "spec003-rule",
    dataset: "hand-built",
    commandLine: "sleep-accuracy walch --data in --out out --sweep 1.0,2.0,3.0",
    gitSHA: "unknown"
)

/// Spec 019, Threshold sweep: a sweep over 1.0, 2.0 and 3.0 writes three rows, in that order,
/// and marks the highest-κ row (2.0, κ 1.000) best; the full report is for that threshold.
@Test func aSweepWritesOneRowPerThresholdAndMarksTheHighestKappaBest() throws {
    let report = try #require(
        AccuracyReport.sweep([sweepNight()], thresholds: [1.0, 2.0, 3.0], stamp: sweepStamp)
    )
    let rows = try #require(report.sweep)

    #expect(report.stamp.thresholds == [1.0, 2.0, 3.0])
    #expect(rows.map(\.threshold) == [1.0, 2.0, 3.0])
    #expect(rows.map(\.isBest) == [false, true, false])
    #expect(abs(try #require(rows[0].kappa) - 0.0) < 1e-9)
    #expect(abs(try #require(rows[1].kappa) - 1.0) < 1e-9)
    #expect(abs(try #require(rows[2].kappa) - 0.0) < 1e-9)
    #expect(report.threshold == 2.0)
    #expect(abs(try #require(report.scores.pooled?.visible.kappa) - 1.0) < 1e-9)
}

/// Spec 019, Threshold sweep: two rows tied on κ mark the lower threshold best. On the sweep
/// night 2.2° and 2.0° both give κ 1; 2.0 is best though it is listed second.
@Test func twoRowsTiedOnKappaMarkTheLowerThresholdBest() throws {
    let report = try #require(
        AccuracyReport.sweep([sweepNight()], thresholds: [2.2, 2.0], stamp: sweepStamp)
    )
    let rows = try #require(report.sweep)

    #expect(report.stamp.thresholds == [2.2, 2.0])
    #expect(rows.map(\.threshold) == [2.2, 2.0])
    #expect(rows.map(\.isBest) == [false, true])
    #expect(report.threshold == 2.0)
}

/// 20 minutes, still but minute 10 (moving 3° every second, so wake inside the Sleep Period).
/// PSG wake at Epochs 1 and 20, else N2. Visible: sleepAsSleep 37, sleepAsWake 1, wakeAsSleep 1,
/// wakeAsWake 1. Observed 38/40 = 0.95; chance 0.95·0.95 + 0.05·0.05 = 0.905;
/// κ = 0.045 / 0.095 ≈ 0.474. Time Asleep 19 min on both sides, bias 0.0.
private func keptNight() -> ReferenceNight {
    ReferenceNight(
        id: "kept-night",
        seconds: labellingSeconds(0..<(20 * 60)) { $0 / 60 == 10 ? 3 : 0 },
        epochs: epochs(40) { $0 == 1 || $0 == 20 ? .wake : .n2 }
    )
}

/// 200 scored Epochs (100 minutes) with seconds for only the first 89 minutes: coverage 89%,
/// left out.
private func leftOutNight() -> ReferenceNight {
    ReferenceNight(
        id: "gappy-night-89",
        seconds: labellingSeconds(0..<(89 * 60)),
        epochs: epochs(200)
    )
}

private let singleStamp = RunStamp(
    labeller: "spec003-rule",
    dataset: "sleep-accel-1.0.0-fixture",
    commandLine: "sleep-accuracy walch --data /tmp/walch --out /tmp/report --threshold 2.0",
    gitSHA: "0123456789abcdef0123456789abcdef01234567"
)

/// Spec 019, Reports: the Markdown and JSON from one run hold the same numbers and both carry
/// the stamp. The JSON decodes back to the same report and spells out κ; the Markdown has the
/// headline κ (0.474), the pooled and per-Reference-Night sections, the left-out night with its
/// 89% coverage, and no sweep table for a single-threshold run.
@Test func markdownAndJSONFromOneRunHoldTheSameNumbersAndCarryTheStamp() throws {
    let report = AccuracyReport.single(
        [keptNight(), leftOutNight()],
        threshold: 2.0,
        stamp: singleStamp
    )

    #expect(report.threshold == 2.0)
    #expect(report.sweep == nil)
    #expect(report.scores.kept.map(\.id) == ["kept-night"])
    #expect(report.scores.leftOut.map(\.id) == ["gappy-night-89"])
    #expect(abs(try #require(report.scores.pooled?.visible.kappa) - 0.045 / 0.095) < 1e-9)
    #expect(report.stamp.thresholds == [2.0])

    let json = try report.json()
    let decoded = try JSONDecoder().decode(AccuracyReport.self, from: json)
    #expect(decoded == report)
    #expect(abs(try #require(decoded.scores.pooled?.visible.kappa) - 0.474) < 5e-4)
    #expect(try #require(decoded.scores.pooled?.timeAsleepBias.mean) == 0.0)
    #expect(decoded.stamp.thresholds == [2.0])
    let jsonText = try #require(String(data: json, encoding: .utf8))
    #expect(jsonText.contains("\"kappa\""))
    #expect(jsonText.contains(singleStamp.labeller))
    #expect(jsonText.contains(singleStamp.dataset))
    #expect(jsonText.contains(singleStamp.gitSHA))

    let markdown = report.markdown()
    #expect(markdown.contains(singleStamp.labeller))
    #expect(markdown.contains(singleStamp.dataset))
    #expect(markdown.contains(singleStamp.commandLine))
    #expect(markdown.contains(singleStamp.gitSHA))
    let headline = try #require(markdown.split(separator: "\n").first { $0.contains("Headline") })
    #expect(headline.contains("0.474"))
    #expect(headline.contains("0.0 min"))
    #expect(markdown.contains("2°"))
    #expect(markdown.contains("| Visible verdict | 40 |"))
    #expect(markdown.contains("| Raw labels | 40 |"))
    #expect(markdown.contains("## Pooled"))
    #expect(markdown.contains("## Per Reference Night"))
    #expect(markdown.contains("## Reference Nights left out"))
    #expect(markdown.contains("gappy-night-89"))
    #expect(markdown.contains("89%"))
    #expect(!markdown.contains("## Sweep"))
}

/// Spec 019, Reports: a swept run's Markdown has the sweep table, one row per threshold, with
/// the best mark on 2°.
@Test func aSweptReportsMarkdownHasTheSweepTable() throws {
    let report = try #require(
        AccuracyReport.sweep([sweepNight()], thresholds: [1.0, 2.0, 3.0], stamp: sweepStamp)
    )
    let markdown = report.markdown()

    #expect(markdown.contains("## Sweep"))
    #expect(markdown.contains("| 1° | 0.000 |"))
    #expect(markdown.contains("| 2° | 1.000 |"))
    #expect(markdown.contains("| 3° | 0.000 |"))
    let bestRows = markdown.split(separator: "\n").filter { $0.hasSuffix("| ✓ |") }
    #expect(bestRows == ["| 2° | 1.000 | 1.000 | 1.000 | 0.0 | ✓ |"])
}

/// Spec 019, Threshold sweep: when no Reference Night is kept there is no κ at any threshold;
/// the rows still come out, with no κ, and the lowest threshold is marked best.
@Test func aSweepWithNoKeptReferenceNightHasNoKappaAndMarksTheLowestThreshold() throws {
    let report = try #require(
        AccuracyReport.sweep([], thresholds: [2.0, 1.0], stamp: sweepStamp)
    )
    let rows = try #require(report.sweep)

    #expect(rows.map(\.kappa) == [nil, nil])
    #expect(rows.map(\.isBest) == [false, true])
    #expect(report.threshold == 1.0)
}

/// A sweep needs a threshold: with none there is no report, rather than a crash.
@Test func aSweepWithNoThresholdsHasNoReport() {
    #expect(AccuracyReport.sweep([sweepNight()], thresholds: [], stamp: sweepStamp) == nil)
}
