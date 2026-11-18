import SleepAccuracy
import Testing

/// Spec 019 criterion: `sleep-accuracy` with no `--out` is a usage error (so the run writes
/// nothing).
@Test(arguments: [
    ["walch", "--data", "d", "--threshold", "2"],
    ["strap", "--data", "d", "--threshold", "2"],
])
func aCommandLineWithoutOutIsAUsageError(arguments: [String]) {
    #expect(throws: HarnessArgumentsError.self) {
        try HarnessArguments.parse(arguments)
    }
}

/// Spec 019, Command line: a Walch run with one threshold, flags in any order.
@Test(arguments: [
    ["walch", "--data", "d", "--out", "o", "--threshold", "2"],
    ["walch", "--threshold", "2", "--out", "o", "--data", "d"],
])
func aWalchRunWithOneThresholdParses(arguments: [String]) throws {
    let command = try HarnessArguments.parse(arguments)

    #expect(command == .walch(data: "d", out: "o", thresholds: .single(2)))
}

/// Spec 019, Command line: `--sweep` takes comma-separated degrees, kept in the order given.
@Test func aWalchSweepParsesEveryThresholdInOrder() throws {
    let command = try HarnessArguments.parse([
        "walch", "--data", "d", "--out", "o", "--sweep", "1,2.5,3",
    ])

    #expect(command == .walch(data: "d", out: "o", thresholds: .sweep([1, 2.5, 3])))
}

/// Spec 019, Command line: a Strap run takes one threshold.
@Test func aStrapRunWithOneThresholdParses() throws {
    let command = try HarnessArguments.parse([
        "strap", "--data", "d", "--out", "o", "--threshold", "1.5",
    ])

    #expect(command == .strap(data: "d", out: "o", threshold: 1.5))
}

/// Every command line outside spec 019's two forms is a usage error.
@Test(arguments: [
    // No arguments at all.
    [],
    // Unknown command.
    ["nap", "--data", "d", "--out", "o", "--threshold", "2"],
    // Walch with both a threshold and a sweep.
    ["walch", "--data", "d", "--out", "o", "--threshold", "2", "--sweep", "1,2"],
    // Walch with neither a threshold nor a sweep.
    ["walch", "--data", "d", "--out", "o"],
    // An empty sweep.
    ["walch", "--data", "d", "--out", "o", "--sweep", ""],
    // A sweep with an empty value.
    ["walch", "--data", "d", "--out", "o", "--sweep", "1,,2"],
    // A sweep with a value that isn't a number.
    ["walch", "--data", "d", "--out", "o", "--sweep", "1,x"],
    // A threshold that isn't a finite number.
    ["walch", "--data", "d", "--out", "o", "--threshold", "nan"],
    // Strap doesn't take a sweep.
    ["strap", "--data", "d", "--out", "o", "--sweep", "1,2"],
    // `--out` last, with no value.
    ["walch", "--data", "d", "--threshold", "2", "--out"],
    // An unknown flag.
    ["walch", "--data", "d", "--out", "o", "--threshold", "2", "--colour", "red"],
    // A repeated flag.
    ["walch", "--data", "a", "--data", "b", "--out", "o", "--threshold", "2"],
])
func aCommandLineOutsideTheTwoFormsIsAUsageError(arguments: [String]) {
    #expect(throws: HarnessArgumentsError.self) {
        try HarnessArguments.parse(arguments)
    }
}

/// The usage message shows both of spec 019's command lines.
@Test func theUsageShowsBothCommandLines() {
    #expect(HarnessArguments.usage.contains("sleep-accuracy walch"))
    #expect(HarnessArguments.usage.contains("sleep-accuracy strap"))
}

/// Spec 019: a command line missing `--data`, or a `strap` run without `--threshold`, or a
/// negative threshold, is a usage error.
@Test func aMissingDataOrStrapThresholdOrANegativeThresholdIsAUsageError() {
    let commandLines = [
        ["walch", "--out", "o", "--threshold", "2"],
        ["strap", "--data", "d", "--out", "o"],
        ["walch", "--data", "d", "--out", "o", "--threshold", "-1"],
        ["walch", "--data", "d", "--out", "o", "--sweep", "1,-2"],
    ]
    for arguments in commandLines {
        #expect(throws: HarnessArgumentsError.self) {
            try HarnessArguments.parse(arguments)
        }
    }
}
