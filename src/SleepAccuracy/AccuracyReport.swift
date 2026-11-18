import Foundation

/// What a harness run was (spec 019), stamped on both its report files.
public struct RunStamp: Equatable, Codable, Sendable {
    /// The labeller scored, e.g. Serenix's sleep/wake labelling (spec 003).
    public var labeller: String
    /// Degrees: the one threshold run, or every threshold swept. Set by the run itself, so it
    /// always matches what was scored.
    public internal(set) var thresholds: [Double] = []
    public var dataset: String
    public var commandLine: String
    /// The commit the harness ran at, or "unknown".
    public var gitSHA: String

    public init(labeller: String, dataset: String, commandLine: String, gitSHA: String) {
        self.labeller = labeller
        self.dataset = dataset
        self.commandLine = commandLine
        self.gitSHA = gitSHA
    }
}

/// One threshold of a sweep: the pooled visible verdict at it.
public struct SweepRow: Equatable, Codable, Sendable {
    /// Degrees.
    public let threshold: Double
    public let kappa: Double?
    public let sensitivity: Double?
    public let specificity: Double?
    /// Minutes.
    public let meanTimeAsleepBias: Double?
    /// The row with the highest pooled κ (the lowest threshold on a tie).
    public let isBest: Bool
}

/// A harness run's report (spec 019): the scores at one threshold, and the sweep that chose it.
/// Written as Markdown to read and JSON to compare, holding the same numbers.
public struct AccuracyReport: Equatable, Codable, Sendable {
    public let stamp: RunStamp
    /// Degrees: the threshold `scores` are for.
    public let threshold: Double
    public let scores: ScoredReferenceNights
    /// Nil for a single-threshold run.
    public let sweep: [SweepRow]?

    /// Scores `nights` at `threshold` (degrees).
    public static func single(
        _ nights: [ReferenceNight],
        threshold: Double,
        stamp: RunStamp
    ) -> AccuracyReport {
        var stamp = stamp
        stamp.thresholds = [threshold]
        return AccuracyReport(
            stamp: stamp,
            threshold: threshold,
            scores: Scorer.score(nights, activeAboveDegrees: threshold),
            sweep: nil
        )
    }

    /// Scores `nights` at each of `thresholds` (degrees), one row each in the order given. The
    /// best row has the highest pooled visible κ (a missing κ ranks lowest), the lowest threshold
    /// on a tie; the report's scores are the best row's. Nil with no thresholds.
    public static func sweep(
        _ nights: [ReferenceNight],
        thresholds: [Double],
        stamp: RunStamp
    ) -> AccuracyReport? {
        let runs = thresholds.map { ($0, Scorer.score(nights, activeAboveDegrees: $0)) }
        guard
            let best = runs.indices.max(by: { a, b in
                let (kappaA, kappaB) = (kappa(of: runs[a].1), kappa(of: runs[b].1))
                return kappaA != kappaB ? kappaA < kappaB : runs[a].0 > runs[b].0
            })
        else { return nil }
        var stamp = stamp
        stamp.thresholds = thresholds
        let rows = runs.indices.map { index in
            let pooled = runs[index].1.pooled
            return SweepRow(
                threshold: runs[index].0,
                kappa: pooled?.visible.kappa,
                sensitivity: pooled?.visible.sensitivity,
                specificity: pooled?.visible.specificity,
                meanTimeAsleepBias: pooled?.timeAsleepBias.mean,
                isBest: index == best
            )
        }
        return AccuracyReport(
            stamp: stamp,
            threshold: runs[best].0,
            scores: runs[best].1,
            sweep: rows
        )
    }

    /// The report as JSON, keys sorted so two runs diff cleanly.
    public func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// The report as Markdown: stamp, headline, pooled tables, per-Reference-Night table, sweep
    /// table (when swept) and the Reference Nights left out. Rates and κ to 3 decimals, minutes to
    /// 1.
    public func markdown() -> String {
        var lines = [
            "# Sleep accuracy: \(stamp.dataset)",
            "",
            "- Labeller: \(stamp.labeller)",
            "- Threshold\(stamp.thresholds.count == 1 ? "" : "s"): "
                + stamp.thresholds.map { degrees($0) }.joined(separator: ", "),
            "- Dataset: \(stamp.dataset)",
            "- Command line: `\(stamp.commandLine)`",
            "- Git SHA: \(stamp.gitSHA)",
            "",
        ]
        let pooled = scores.pooled
        lines.append(
            "**Headline** (visible verdict at \(degrees(threshold))): pooled κ "
                + "\(rate(pooled?.visible.kappa)), mean Time Asleep bias "
                + "\(minutes(pooled?.timeAsleepBias.mean)) min."
        )
        lines += ["", "## Pooled", ""]
        if let pooled {
            lines += [
                "| Layer | Epochs | Sensitivity | Specificity | Accuracy | κ |",
                "|---|---|---|---|---|---|",
                agreementRow("Visible verdict", pooled.visible),
                agreementRow("Raw labels", pooled.raw),
                "",
                "| Error, Serenix − PSG | Reference Nights | Mean | SD | 95% limits |",
                "|---|---|---|---|---|",
                errorRow("Time Asleep (min)", pooled.timeAsleepBias, withLimits: true),
                errorRow("Wake after Sleep Onset, WASO (min)", pooled.wasoBias),
                errorRow("Sleep Onset (min)", pooled.sleepOnsetError),
                errorRow("Final Wake (min)", pooled.finalWakeError),
                errorRow("Wake Bout count", pooled.wakeBoutCountError),
            ]
        } else {
            lines.append("No Reference Night was kept.")
        }
        lines += [
            "", "## Per Reference Night", "",
            "Visible verdict, with its errors (Serenix − PSG):",
            "",
            "| Reference Night | Coverage | Epochs | Sensitivity | Specificity | Accuracy | κ "
                + "| Time Asleep (min) | WASO (min) | Sleep Onset (min) | Final Wake (min) "
                + "| Wake Bouts, Serenix / PSG | Mean Wake Bout (min), Serenix / PSG |",
            "|---|---|---|---|---|---|---|---|---|---|---|---|---|",
        ]
        for night in scores.kept {
            let cells = [
                cell(night.id), percent(night.coverage), "\(night.visible.comparedEpochs)",
                rate(night.visible.sensitivity), rate(night.visible.specificity),
                rate(night.visible.accuracy), rate(night.visible.kappa),
                minutes(night.timeAsleepBias), minutes(night.wasoBias),
                minutes(night.sleepOnsetError), minutes(night.finalWakeError),
                "\(night.serenixWakeBouts) / \(night.referenceWakeBouts)",
                "\(minutes(night.serenixMeanWakeBoutMinutes)) / "
                    + minutes(night.referenceMeanWakeBoutMinutes),
            ]
            lines.append("| " + cells.joined(separator: " | ") + " |")
        }
        lines += [
            "", "Raw labels:", "",
            "| Reference Night | Epochs | Sensitivity | Specificity | Accuracy | κ |",
            "|---|---|---|---|---|---|",
        ]
        lines += scores.kept.map { agreementRow(cell($0.id), $0.raw) }
        if let sweep {
            lines += [
                "", "## Sweep", "",
                "| Threshold | κ | Sensitivity | Specificity | Mean Time Asleep bias (min) | Best |",
                "|---|---|---|---|---|---|",
            ]
            for row in sweep {
                let cells = [
                    degrees(row.threshold), rate(row.kappa), rate(row.sensitivity),
                    rate(row.specificity), minutes(row.meanTimeAsleepBias), row.isBest ? "✓" : "",
                ]
                lines.append("| " + cells.joined(separator: " | ") + " |")
            }
        }
        lines += ["", "## Reference Nights left out", ""]
        if scores.leftOut.isEmpty {
            lines.append("None.")
        } else {
            lines += ["| Reference Night | Coverage |", "|---|---|"]
            lines += scores.leftOut.map { "| \(cell($0.id)) | \(percent($0.coverage)) |" }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// A run's pooled visible κ, with a missing one ranked below every real κ.
private func kappa(of scores: ScoredReferenceNights) -> Double {
    scores.pooled?.visible.kappa ?? -.infinity
}

private func agreementRow(_ layer: String, _ agreement: EpochAgreement) -> String {
    let cells = [
        layer, "\(agreement.comparedEpochs)", rate(agreement.sensitivity),
        rate(agreement.specificity), rate(agreement.accuracy), rate(agreement.kappa),
    ]
    return "| " + cells.joined(separator: " | ") + " |"
}

/// Bland–Altman limits only where the spec asks for them (Time Asleep); "—" elsewhere.
private func errorRow(_ name: String, _ summary: ErrorSummary, withLimits: Bool = false)
    -> String
{
    let limits =
        withLimits
        ? summary.lowerLimit.map { "\(minutes($0)) to \(minutes(summary.upperLimit))" } ?? "—"
        : "—"
    let cells = [name, "\(summary.count)", minutes(summary.mean), minutes(summary.sd), limits]
    return "| " + cells.joined(separator: " | ") + " |"
}
