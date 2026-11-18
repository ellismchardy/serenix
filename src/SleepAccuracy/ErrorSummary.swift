import Foundation

/// Some errors summed up across Reference Nights (spec 019): their mean and SD, and Bland–Altman
/// 95% limits of agreement (mean ± 1.96 SD). Units are the errors' own (minutes, or a count).
public struct ErrorSummary: Equatable, Codable, Sendable {
    public let count: Int
    /// Nil with no errors.
    public let mean: Double?
    /// Sample SD (n − 1); nil with fewer than 2 errors.
    public let sd: Double?
    /// Mean − 1.96 SD; nil with fewer than 2 errors.
    public let lowerLimit: Double?
    /// Mean + 1.96 SD; nil with fewer than 2 errors.
    public let upperLimit: Double?

    public init(_ values: [Double]) {
        count = values.count
        guard !values.isEmpty else {
            (mean, sd, lowerLimit, upperLimit) = (nil, nil, nil, nil)
            return
        }
        let mean = values.reduce(0, +) / Double(values.count)
        self.mean = mean
        guard values.count >= 2 else {
            (sd, lowerLimit, upperLimit) = (nil, nil, nil)
            return
        }
        let variance =
            values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count - 1)
        let sd = variance.squareRoot()
        self.sd = sd
        lowerLimit = mean - limitsOfAgreementSDs * sd
        upperLimit = mean + limitsOfAgreementSDs * sd
    }
}

/// SDs either side of the mean for 95% limits of agreement (Bland & Altman 1986).
private let limitsOfAgreementSDs = 1.96
