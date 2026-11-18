import SleepAccuracy
import Testing

/// Spec 019, Scorer: Time Asleep biases of +10 and −10 minutes pool to mean 0.0, SD 14.1 and
/// limits −27.7 to +27.7 minutes (sample SD √200 ≈ 14.142; limits ±1.96 × 14.142 ≈ ±27.72).
@Test func biasesOfPlusAndMinusTenPoolToTheSpecsBlandAltmanLimits() throws {
    let summary = ErrorSummary([10, -10])

    #expect(summary.count == 2)
    #expect(try #require(summary.mean) == 0.0)
    #expect(abs(try #require(summary.sd) - 14.1) < 0.05)
    #expect(abs(try #require(summary.lowerLimit) - -27.7) < 0.05)
    #expect(abs(try #require(summary.upperLimit) - 27.7) < 0.05)
}

/// One value has a mean but no SD or limits.
@Test func oneErrorHasAMeanButNoSpreadOrLimits() {
    let summary = ErrorSummary([5])

    #expect(summary.count == 1)
    #expect(summary.mean == 5)
    #expect(summary.sd == nil)
    #expect(summary.lowerLimit == nil)
    #expect(summary.upperLimit == nil)
}

/// No values have no mean.
@Test func noErrorsHaveNoMean() {
    let summary = ErrorSummary([])

    #expect(summary.count == 0)
    #expect(summary.mean == nil)
    #expect(summary.sd == nil)
}
