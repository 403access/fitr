import SwiftUI

struct MotionSequence {
    enum LoopMode { case pingPong, loop }

    let keyframes: [BodyPose]
    let duration: Double
    let mode: LoopMode

    func pose(at elapsed: Double) -> BodyPose {
        guard keyframes.count > 1 else { return keyframes.first ?? Poses.stand }
        var phase = (elapsed / duration).truncatingRemainder(dividingBy: 1)
        if phase < 0 { phase += 1 }
        let t: CGFloat
        switch mode {
        case .pingPong:
            t = phase < 0.5 ? CGFloat(phase * 2) : CGFloat(2 - phase * 2)
        case .loop:
            t = CGFloat(phase)
        }
        let eased = t * t * (3 - 2 * t)
        let position = eased * CGFloat(keyframes.count - 1)
        let lower = Int(floor(position))
        let upper = min(lower + 1, keyframes.count - 1)
        let fraction = position - CGFloat(lower)
        return BodyPose.lerp(keyframes[lower], keyframes[upper], fraction)
    }
}

enum ExerciseMotion {
    static func sequence(for animation: String) -> MotionSequence {
        switch animation {
        case "squat":
            return .init(keyframes: [Poses.stand, Poses.squat], duration: 3.6, mode: .pingPong)
        case "hinge":
            return .init(keyframes: [Poses.stand, Poses.hinge], duration: 3.8, mode: .pingPong)
        case "lunge":
            return .init(
                keyframes: [Poses.lungeL, Poses.stand, Poses.lungeR, Poses.stand],
                duration: 5.4, mode: .loop
            )
        case "pushup":
            return .init(keyframes: [Poses.pushupHigh, Poses.pushupLow], duration: 3.1, mode: .pingPong)
        case "pike":
            return .init(keyframes: [Poses.pikeUp, Poses.pikeDown], duration: 3.2, mode: .pingPong)
        case "bench":
            return .init(keyframes: [Poses.benchDown, Poses.benchUp], duration: 3.2, mode: .pingPong)
        case "row":
            return .init(keyframes: [Poses.rowHinge, Poses.rowPull], duration: 2.9, mode: .pingPong)
        case "press":
            return .init(keyframes: [Poses.pressDown, Poses.pressUp], duration: 3.2, mode: .pingPong)
        case "curl":
            return .init(keyframes: [Poses.curlDown, Poses.curlUp], duration: 2.7, mode: .pingPong)
        case "lateralRaise":
            return .init(keyframes: [Poses.stand, Poses.lateralUp], duration: 2.8, mode: .pingPong)
        case "calfRaise":
            return .init(keyframes: [Poses.stand, Poses.calfUp], duration: 2.4, mode: .pingPong)
        case "hipThrust":
            return .init(keyframes: [Poses.hipThrustDown, Poses.hipThrustUp], duration: 3.3, mode: .pingPong)
        case "bridge":
            return .init(keyframes: [Poses.bridgeDown, Poses.bridgeUp], duration: 3.8, mode: .pingPong)
        case "pullup":
            return .init(keyframes: [Poses.pullupHang, Poses.pullupTop], duration: 3.5, mode: .pingPong)
        case "dip":
            return .init(keyframes: [Poses.dipTop, Poses.dipBottom], duration: 3.0, mode: .pingPong)
        case "plank":
            return .init(
                keyframes: [Poses.plank, Poses.plank.with { $0.hipL.y += 0.018; $0.hipR.y += 0.018 }],
                duration: 5.2, mode: .pingPong
            )
        case "sidePlank":
            return .init(
                keyframes: [
                    Poses.sidePlank,
                    Poses.sidePlank.with { $0.handR = Poses.p(0.50, 0.22); $0.hipL.y += 0.014 },
                ],
                duration: 5.4, mode: .pingPong
            )
        case "hollowHold":
            return .init(
                keyframes: [Poses.hollow, Poses.hollow.with { $0.ankleL.y += 0.04; $0.ankleR.y += 0.04 }],
                duration: 4.6, mode: .pingPong
            )
        case "legRaise":
            return .init(keyframes: [Poses.legRaiseDown, Poses.legRaiseUp], duration: 3.3, mode: .pingPong)
        case "mountainClimber":
            return .init(
                keyframes: [Poses.plank, Poses.mountainClimberL, Poses.plank, Poses.mountainClimberR],
                duration: 2.4, mode: .loop
            )
        case "burpee":
            return .init(
                keyframes: [Poses.burpeeStand, Poses.burpeeSquat, Poses.burpeePlank, Poses.burpeeSquat, Poses.burpeeJump],
                duration: 5.0, mode: .loop
            )
        case "downwardDog":
            return .init(
                keyframes: [Poses.downDog, Poses.downDog.with { $0.hipL.y -= 0.02; $0.hipR.y -= 0.02 }],
                duration: 7.0, mode: .pingPong
            )
        case "cobra":
            return .init(
                keyframes: [Poses.cobra, Poses.cobra.with { $0.head.y += 0.025; $0.neck.y += 0.02 }],
                duration: 6.0, mode: .pingPong
            )
        case "warrior":
            return .init(
                keyframes: [Poses.warrior, Poses.warrior.with { $0.handL.y -= 0.012; $0.handR.y -= 0.012 }],
                duration: 7.0, mode: .pingPong
            )
        case "tree":
            return .init(
                keyframes: [Poses.tree, Poses.tree.with { $0.hipL.x += 0.008; $0.hipR.x += 0.008 }],
                duration: 7.2, mode: .pingPong
            )
        case "childsPose":
            return .init(
                keyframes: [Poses.childsPose, Poses.childsPose.with { $0.head.y += 0.012; $0.neck.y += 0.008 }],
                duration: 7.4, mode: .pingPong
            )
        case "catCow":
            return .init(keyframes: [Poses.cat, Poses.cow], duration: 5.0, mode: .pingPong)
        case "twist":
            return .init(keyframes: [Poses.twistL, Poses.twistR, Poses.twistL], duration: 6.2, mode: .loop)
        case "pigeon":
            return .init(
                keyframes: [Poses.pigeon, Poses.pigeon.with { $0.head.y += 0.02; $0.neck.y += 0.015 }],
                duration: 7.0, mode: .pingPong
            )
        case "legsUp":
            return .init(
                keyframes: [Poses.legsUp, Poses.legsUp.with { $0.ankleL.y -= 0.02; $0.ankleR.y -= 0.02 }],
                duration: 8.0, mode: .pingPong
            )
        case "hipRotation":
            return .init(
                keyframes: [Poses.hipRotationL, Poses.hipRotationR, Poses.hipRotationL],
                duration: 5.6, mode: .loop
            )
        case "shoulderStretch":
            return .init(
                keyframes: [Poses.shoulderStretchDown, Poses.shoulderStretchUp],
                duration: 4.4, mode: .pingPong
            )
        case "hipFlexorStretch":
            return .init(
                keyframes: [Poses.hipFlexorStretch, Poses.hipFlexorStretch.with { $0.head.x -= 0.02; $0.hipL.y += 0.01 }],
                duration: 7.0, mode: .pingPong
            )
        case "hamstringStretch":
            return .init(
                keyframes: [Poses.hamstringStretch, Poses.hamstringStretch.with { $0.head.y += 0.02; $0.neck.y += 0.015 }],
                duration: 7.0, mode: .pingPong
            )
        case "calfStretch":
            return .init(
                keyframes: [Poses.calfStretch, Poses.calfStretch.with { $0.head.x -= 0.02; $0.shoulderL.x -= 0.015 }],
                duration: 6.4, mode: .pingPong
            )
        case "neckStretch":
            return .init(
                keyframes: [Poses.neckStretchL, Poses.stand, Poses.neckStretchR, Poses.stand],
                duration: 8.0, mode: .loop
            )
        case "wristPrep":
            return .init(
                keyframes: [Poses.wristPrep, Poses.wristPrep.with { $0.handL.x += 0.03; $0.handR.x += 0.03 }],
                duration: 4.2, mode: .pingPong
            )
        case "breathe":
            return .init(keyframes: [Poses.breatheOut, Poses.breatheIn], duration: 10.0, mode: .pingPong)
        case "run":
            return .init(keyframes: [Poses.runA, Poses.runB], duration: 1.15, mode: .pingPong)
        case "jumpingJack":
            return .init(keyframes: [Poses.jumpingJackIn, Poses.jumpingJackOut], duration: 1.5, mode: .pingPong)
        case "boxing":
            return .init(
                keyframes: [Poses.boxingGuard, Poses.boxingPunch, Poses.boxingGuard],
                duration: 2.0, mode: .loop
            )
        default:
            return .init(keyframes: [Poses.breatheOut, Poses.breatheIn], duration: 9.0, mode: .pingPong)
        }
    }
}
