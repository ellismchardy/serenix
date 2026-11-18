import Foundation

/// Which motion angle labelling input is built from (spec 019).
public enum MotionAngle: Sendable {
    /// The Strap's full rotation (the app's).
    case turn
    /// Tilt: only the change in the direction of gravity, as an accelerometer alone sees it.
    case tilt
}

/// Angles between two of the Strap's motion readings: four floats taken as a quaternion in the
/// order (x, y, z, w), the scalar last as the fixture nights' readings show (w ≈ 1 at rest).
/// Whether they truly are an orientation quaternion is unconfirmed (docs/research/
/// walch-motion-for-serenix-motion-rule.md, Open). An all-zero reading is left unscaled: its
/// turn from any reading is 180° and its vertical is (0, 0, 1).
public enum StrapMotion {
    /// Degrees turned between two readings: 2·acos(|q₁·q₂|) of the normalised quaternions.
    public static func turn(from previous: [Float], to current: [Float]) -> Double {
        let dot = zip(normalised(current), normalised(previous)).map { $0 * $1 }.reduce(0, +)
        return 2 * acos(min(1, abs(dot))) * 180 / .pi
    }

    /// Tilt in degrees between two readings: the angle between the vertical (0, 0, 1) seen in the
    /// Strap's frame (Rᵀ·z) at each. A turn about the vertical leaves it unchanged. Unlike the
    /// turn, this assumes the quaternion takes the Strap's frame to the world's; were it the
    /// other way, the vertical would be R·z and a turn about the vertical would show as Tilt.
    public static func tilt(from previous: [Float], to current: [Float]) -> Double {
        let before = vertical(seenAt: normalised(previous))
        let after = vertical(seenAt: normalised(current))
        let dot = zip(before, after).map { $0 * $1 }.reduce(0, +)
        return acos(max(-1, min(1, dot))) * 180 / .pi
    }

    /// The four motion values scaled to unit length (left as they are when all are 0).
    private static func normalised(_ motion: [Float]) -> [Double] {
        let values = motion.map(Double.init)
        let length = values.map { $0 * $0 }.reduce(0, +).squareRoot()
        return values.map { $0 / (length == 0 ? 1 : length) }
    }

    /// The world vertical in the Strap's frame: the third row of the rotation matrix of the unit
    /// quaternion (x, y, z, w).
    private static func vertical(seenAt q: [Double]) -> [Double] {
        let (x, y, z, w) = (q[0], q[1], q[2], q[3])
        return [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)]
    }
}
