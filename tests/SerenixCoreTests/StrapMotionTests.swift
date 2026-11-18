import Foundation
import SerenixCore
import Testing

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

private func floats(_ q: [Double]) -> [Float] { q.map { Float($0) } }

private let worldX = (1.0, 0.0, 0.0)
private let worldY = (0.0, 1.0, 0.0)
/// The vertical.
private let worldZ = (0.0, 0.0, 1.0)
private let identity: [Double] = [0, 0, 0, 1]
/// A tilted, non-identity starting orientation: 40° about world x.
private let tiltedStart = quaternion(degrees: 40, about: worldX)

/// Degrees; the inputs are Float, so allow a thousandth of a degree.
private let tolerance = 1e-3

/// Spec 019, "Tilt from quaternion": turning 30° about the vertical moves the direction of
/// gravity at the wrist not at all, though the Strap turned 30°.
@Test func aTurnAboutTheVerticalIsNoTiltButIsAThirtyDegreeTurn() {
    let previous = tiltedStart
    let current = product(quaternion(degrees: 30, about: worldZ), previous)

    let tilt = StrapMotion.tilt(from: floats(previous), to: floats(current))
    let turn = StrapMotion.turn(from: floats(previous), to: floats(current))

    #expect(abs(tilt) < tolerance)
    #expect(abs(turn - 30) < tolerance)
}

/// Spec 019, "Tilt from quaternion": turning 30° about a horizontal axis tilts the wrist 30°.
@Test func aThirtyDegreeTurnAboutAHorizontalAxisIsAThirtyDegreeTilt() {
    let previous = identity
    let current = product(quaternion(degrees: 30, about: worldX), previous)

    let tilt = StrapMotion.tilt(from: floats(previous), to: floats(current))
    let turn = StrapMotion.turn(from: floats(previous), to: floats(current))

    #expect(abs(tilt - 30) < tolerance)
    #expect(abs(turn - 30) < tolerance)
}

/// Spec 019, "Tilt from quaternion": from an already tilted wrist, a further 30° about another
/// horizontal axis is still a 30° Tilt.
@Test func aThirtyDegreeTurnAboutAHorizontalAxisFromATiltedWristIsAThirtyDegreeTilt() {
    let previous = tiltedStart
    let current = product(quaternion(degrees: 30, about: worldY), previous)

    let tilt = StrapMotion.tilt(from: floats(previous), to: floats(current))

    #expect(abs(tilt - 30) < tolerance)
}

/// Three History Records 1 s apart whose motion turns 30° about the vertical each second, from
/// the tilted start.
private func recordsTurningAboutTheVertical() -> [HistoryRecord] {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    var orientation = tiltedStart
    var records: [HistoryRecord] = []
    for second in 0..<3 {
        records.append(
            HistoryRecord(
                recordCounter: UInt32(second + 1),
                timestamp: start.addingTimeInterval(TimeInterval(second)),
                heartRate: 55,
                rrIntervals: [],
                motion: floats(orientation),
                skinTemperature: 33,
                steps: 0,
                spo2: 0,
                isInSpO2Window: false,
                rawBytes: []
            )
        )
        orientation = product(quaternion(degrees: 30, about: worldZ), orientation)
    }
    return records
}

/// Spec 019: labelling input built with the Tilt gives each second after the first the Tilt
/// from the second before, which is 0° for turns about the vertical; the first has no angle.
@Test func labellingInputWithTiltGivesNoAngleForTurnsAboutTheVertical() throws {
    let input = SleepWakeLabeller.input(from: recordsTurningAboutTheVertical(), angle: .tilt)

    try #require(input.count == 3)
    #expect(input[0].angle == nil)
    let second1 = try #require(input[1].angle)
    let second2 = try #require(input[2].angle)
    #expect(abs(second1 - 0) < tolerance)
    #expect(abs(second2 - 0) < tolerance)
}

/// Spec 019: the same records with the turn give 30° each second after the first.
@Test func labellingInputWithTurnGivesThirtyDegreesForTurnsAboutTheVertical() throws {
    let input = SleepWakeLabeller.input(from: recordsTurningAboutTheVertical(), angle: .turn)

    try #require(input.count == 3)
    #expect(input[0].angle == nil)
    let second1 = try #require(input[1].angle)
    let second2 = try #require(input[2].angle)
    #expect(abs(second1 - 30) < tolerance)
    #expect(abs(second2 - 30) < tolerance)
}
