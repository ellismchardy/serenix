import Foundation
import SleepAccuracy

// The sleep accuracy harness's command line (spec 019). Developer machine only, never CI. All the
// deciding is in the SleepAccuracy library; this file reads folders, runs git and writes files.
// Everything is worked out before either report file is written, and a failed write removes what
// was written, so a failed run leaves no partial report.

/// The labeller every run scores.
let labeller = "Serenix sleep/wake labelling (spec 003)"

/// Prints `message` to standard error and exits with `status`.
func fail(_ message: String, status: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(status)
}

/// The commit the harness was built from, or "unknown" when git can't be found or run. git runs
/// in the executable's own folder (inside the repo's `.build`), not wherever the run started.
func gitSHA() -> String {
    #if os(Windows)
        let separator: Character = ";"
    #else
        let separator: Character = ":"
    #endif
    // Windows spells the variable `Path`.
    let path =
        ProcessInfo.processInfo.environment.first { $0.key.uppercased() == "PATH" }?.value ?? ""
    let candidates = path.split(separator: separator).flatMap { folder in
        ["git", "git.exe"].map { URL(fileURLWithPath: String(folder)).appendingPathComponent($0) }
    }
    let isExecutable = { (url: URL) in FileManager.default.isExecutableFile(atPath: url.path) }
    guard let git = candidates.first(where: isExecutable) else { return "unknown" }
    let process = Process()
    process.executableURL = git
    process.arguments = ["rev-parse", "HEAD"]
    process.currentDirectoryURL = Bundle.main.executableURL?.deletingLastPathComponent()
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return "unknown"
    }
    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return process.terminationStatus == 0 && !text.isEmpty ? text : "unknown"
}

/// A folder given on the command line, which must exist.
func folder(_ path: String) -> URL {
    var isFolder: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isFolder), isFolder.boolValue
    else { fail("sleep-accuracy: no such folder: \(path)") }
    return URL(fileURLWithPath: path, isDirectory: true)
}

let arguments = Array(CommandLine.arguments.dropFirst())
let command: HarnessCommand
do {
    command = try HarnessArguments.parse(arguments)
} catch HarnessArgumentsError.usage(let reason) {
    fail("sleep-accuracy: \(reason)\n\(HarnessArguments.usage)", status: 2)
}

// Reports are published, so the stamp keeps only the last folder name of each path given, never
// the developer's own folders.
let shownArguments = arguments.enumerated().map { index, argument in
    index > 0 && ["--data", "--out"].contains(arguments[index - 1])
        ? URL(fileURLWithPath: argument).lastPathComponent : argument
}
let commandLine = (["sleep-accuracy"] + shownArguments).joined(separator: " ")
func dataset(_ name: String, _ path: String) -> String {
    "\(name) (\(URL(fileURLWithPath: path).lastPathComponent))"
}

let files: (name: String, markdown: String, json: Data)
let out: URL
do {
    switch command {
    case .walch(let data, let outPath, let thresholds):
        let nights = try WalchAdapter.referenceNights(in: folder(data))
        let stamp = RunStamp(
            labeller: labeller,
            dataset: dataset("Walch sleep-accel 1.0.0", data),
            commandLine: commandLine,
            gitSHA: gitSHA()
        )
        let report: AccuracyReport
        switch thresholds {
        case .single(let threshold):
            report = AccuracyReport.single(nights, threshold: threshold, stamp: stamp)
        case .sweep(let values):
            // Parsing already rejects an empty sweep.
            guard let swept = AccuracyReport.sweep(nights, thresholds: values, stamp: stamp)
            else { fail("sleep-accuracy: --sweep needs at least one threshold", status: 2) }
            report = swept
        }
        files = ("walch", report.markdown(), try report.json())
        out = URL(fileURLWithPath: outPath, isDirectory: true)
    case .strap(let data, let outPath, let threshold):
        let nights = try HistoryRecordCSV.nights(in: folder(data))
        let stamp = RunStamp(
            labeller: labeller,
            dataset: dataset("Strap History Records", data),
            commandLine: commandLine,
            gitSHA: gitSHA()
        )
        let report = StrapTransferReport.compare(nights, tiltThreshold: threshold, stamp: stamp)
        files = ("strap-transfer", report.markdown(), try report.json())
        out = URL(fileURLWithPath: outPath, isDirectory: true)
    }
} catch {
    fail("sleep-accuracy: \(error)")
}

let markdownFile = out.appendingPathComponent("\(files.name).md")
let jsonFile = out.appendingPathComponent("\(files.name).json")
do {
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    try files.markdown.write(to: markdownFile, atomically: true, encoding: .utf8)
    do {
        try files.json.write(to: jsonFile, options: .atomic)
    } catch {
        try? FileManager.default.removeItem(at: markdownFile)
        throw error
    }
    print("Wrote \(markdownFile.path)\nWrote \(jsonFile.path)")
} catch {
    fail("sleep-accuracy: couldn't write the report: \(error)")
}
