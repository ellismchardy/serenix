import SerenixCore
import Testing

// Spec 005, success criterion "Profile": Max HR is accepted from 100 to 230 and refused outside
// it; birth year from 100 to 13 years before the current year; the estimate for birth year 1986
// in 2026 is 180. Expected values are the spec's literals.

@Test func aNewProfileHasNoBirthYearNoMaxHRAndPreferNotToSayAsSex() {
    let profile = Profile(name: "Ellis")

    #expect(profile.birthYear == nil)
    #expect(profile.sex == .preferNotToSay)
    #expect(profile.maxHR == nil)
}

@Test func maxHRCanBeEnteredFrom100To230() {
    #expect(Profile.allowedMaxHR == 100...230)
}

@Test(arguments: [100, 230])
func maxHRAtTheEdgesOfTheAllowedRangeIsAccepted(maxHR: Int) {
    #expect(Profile(name: nil, maxHR: maxHR).maxHR == maxHR)
}

@Test(arguments: [99, 231])
func maxHROutsideTheAllowedRangeIsRefused(maxHR: Int) {
    #expect(Profile(name: nil, maxHR: maxHR).maxHR == nil)
}

@Test func birthYearCanBeFrom100To13YearsBeforeTheCurrentYear() {
    #expect(Profile.allowedBirthYears(in: 2026) == 1926...2013)
}

@Test func theMaxHREstimateForBirthYear1986In2026Is180() throws {
    let estimate = try #require(Profile(name: nil, birthYear: 1986).estimatedMaxHR(in: 2026))

    #expect(abs(estimate - 180) < 1e-9)
}

@Test func withoutABirthYearThereIsNoMaxHREstimate() {
    #expect(Profile(name: nil).estimatedMaxHR(in: 2026) == nil)
}

/// Any birth year that's set is used: only the picker limits the range. Birth year 2013 picked
/// in January 2026 still gives Days in December 2025 a Max HR (age 12).
@Test(arguments: [(2013, 2025, 199.6), (1925, 2026, 137.3)])
func aBirthYearOutsideThePickersRangeStillGivesAnEstimate(birthYear: Int, year: Int, maxHR: Double)
    throws
{
    let estimate = try #require(Profile(name: nil, birthYear: birthYear).estimatedMaxHR(in: year))

    #expect(abs(estimate - maxHR) < 1e-9)
}
