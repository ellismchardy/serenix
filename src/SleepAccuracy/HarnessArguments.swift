import Foundation

/// What the `sleep-accuracy` command line asks for (spec 019).
public enum HarnessCommand: Equatable, Sendable {
    /// Score Serenix's labelling against Walch's Reference Nights.
    case walch(data: String, out: String, thresholds: ThresholdChoice)
    /// Compare Tilt with the turn on the owner's Strap nights; `threshold` is the Tilt's.
    case strap(data: String, out: String, threshold: Double)
}

/// Degrees: one threshold, or several to sweep.
public enum ThresholdChoice: Equatable, Sendable {
    case single(Double)
    case sweep([Double])
}

/// Reads the `sleep-accuracy` command line (spec 019). Anything outside its two forms is a usage
/// error, so a run never starts on a guess.
public enum HarnessArguments {
    public static let usage = """
        usage: sleep-accuracy walch --data <dir> --out <dir> (--threshold <deg> | --sweep <deg,…>)
               sleep-accuracy strap --data <dir> --out <dir> --threshold <deg>
        """

    /// `arguments` excludes the program name. Flags may come in any order.
    public static func parse(_ arguments: [String]) throws -> HarnessCommand {
        guard let command = arguments.first else { throw usageError("no command given") }
        var flags: [String: String] = [:]
        var rest = arguments.dropFirst()
        while let flag = rest.popFirst() {
            guard ["--data", "--out", "--threshold", "--sweep"].contains(flag) else {
                throw usageError("unknown argument \(flag)")
            }
            guard let value = rest.popFirst() else { throw usageError("\(flag) needs a value") }
            guard flags.updateValue(value, forKey: flag) == nil else {
                throw usageError("\(flag) given twice")
            }
        }
        guard let data = flags["--data"] else { throw usageError("--data is required") }
        guard let out = flags["--out"] else { throw usageError("--out is required") }
        switch (command, flags["--threshold"], flags["--sweep"]) {
        case ("walch", let threshold?, nil):
            return .walch(data: data, out: out, thresholds: .single(try degrees(threshold)))
        case ("walch", nil, let sweep?):
            guard !sweep.isEmpty else { throw usageError("--sweep needs at least one threshold") }
            let values = sweep.split(separator: ",", omittingEmptySubsequences: false)
            return .walch(
                data: data,
                out: out,
                thresholds: .sweep(try values.map { try degrees(String($0)) })
            )
        case ("walch", _, _):
            throw usageError("walch takes one of --threshold or --sweep")
        case ("strap", let threshold?, nil):
            return .strap(data: data, out: out, threshold: try degrees(threshold))
        case ("strap", _, _):
            throw usageError("strap takes --threshold, and no --sweep")
        default:
            throw usageError("unknown command \(command)")
        }
    }

    /// A finite, non-negative number of degrees (below 0 every second would be active).
    private static func degrees(_ text: String) throws -> Double {
        guard let value = Double(text), value.isFinite, value >= 0 else {
            throw usageError("\"\(text)\" is not a threshold in degrees (0 or more, no spaces)")
        }
        return value
    }

    private static func usageError(_ reason: String) -> HarnessArgumentsError {
        .usage(reason: reason)
    }
}

/// A command line outside `sleep-accuracy`'s two forms. The command prints the reason and the
/// usage, exits non-zero and writes nothing.
public enum HarnessArgumentsError: Error, Equatable {
    case usage(reason: String)
}
