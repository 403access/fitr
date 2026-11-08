import SwiftUI

/// A normalized (0…1) skeleton used by the Canvas renderer. Coordinates are
/// intentionally resolution independent so the same motion looks crisp from a
/// 56pt thumbnail to a full-screen player.
struct BodyPose {
    var head: CGPoint
    var neck: CGPoint
    var shoulderL: CGPoint
    var shoulderR: CGPoint
    var elbowL: CGPoint
    var elbowR: CGPoint
    var handL: CGPoint
    var handR: CGPoint
    var hipL: CGPoint
    var hipR: CGPoint
    var kneeL: CGPoint
    var kneeR: CGPoint
    var ankleL: CGPoint
    var ankleR: CGPoint
    var headRadius: CGFloat = 0.052

    init(
        head: CGPoint,
        neck: CGPoint,
        headRadius: CGFloat = 0.052,
        shoulderL: CGPoint,
        shoulderR: CGPoint,
        elbowL: CGPoint,
        elbowR: CGPoint,
        handL: CGPoint,
        handR: CGPoint,
        hipL: CGPoint,
        hipR: CGPoint,
        kneeL: CGPoint,
        kneeR: CGPoint,
        ankleL: CGPoint,
        ankleR: CGPoint
    ) {
        self.head = head
        self.neck = neck
        self.headRadius = headRadius
        self.shoulderL = shoulderL
        self.shoulderR = shoulderR
        self.elbowL = elbowL
        self.elbowR = elbowR
        self.handL = handL
        self.handR = handR
        self.hipL = hipL
        self.hipR = hipR
        self.kneeL = kneeL
        self.kneeR = kneeR
        self.ankleL = ankleL
        self.ankleR = ankleR
    }

    func with(_ edit: (inout BodyPose) -> Void) -> BodyPose {
        var copy = self
        edit(&copy)
        return copy
    }

    func mirrored() -> BodyPose {
        func m(_ point: CGPoint) -> CGPoint { CGPoint(x: 1 - point.x, y: point.y) }
        return BodyPose(
            head: m(head),
            neck: m(neck),
            headRadius: headRadius,
            shoulderL: m(shoulderR),
            shoulderR: m(shoulderL),
            elbowL: m(elbowR),
            elbowR: m(elbowL),
            handL: m(handR),
            handR: m(handL),
            hipL: m(hipR),
            hipR: m(hipL),
            kneeL: m(kneeR),
            kneeR: m(kneeL),
            ankleL: m(ankleR),
            ankleR: m(ankleL)
        )
    }

    static func lerp(_ a: BodyPose, _ b: BodyPose, _ t: CGFloat) -> BodyPose {
        func l(_ p: CGPoint, _ q: CGPoint) -> CGPoint {
            CGPoint(x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t)
        }
        return BodyPose(
            head: l(a.head, b.head),
            neck: l(a.neck, b.neck),
            headRadius: a.headRadius + (b.headRadius - a.headRadius) * t,
            shoulderL: l(a.shoulderL, b.shoulderL),
            shoulderR: l(a.shoulderR, b.shoulderR),
            elbowL: l(a.elbowL, b.elbowL),
            elbowR: l(a.elbowR, b.elbowR),
            handL: l(a.handL, b.handL),
            handR: l(a.handR, b.handR),
            hipL: l(a.hipL, b.hipL),
            hipR: l(a.hipR, b.hipR),
            kneeL: l(a.kneeL, b.kneeL),
            kneeR: l(a.kneeR, b.kneeR),
            ankleL: l(a.ankleL, b.ankleL),
            ankleR: l(a.ankleR, b.ankleR)
        )
    }
}

enum Poses {
    static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    static let stand = BodyPose(
        head: p(0.50, 0.13), neck: p(0.50, 0.235),
        shoulderL: p(0.42, 0.275), shoulderR: p(0.58, 0.275),
        elbowL: p(0.395, 0.385), elbowR: p(0.605, 0.385),
        handL: p(0.395, 0.495), handR: p(0.605, 0.495),
        hipL: p(0.445, 0.515), hipR: p(0.555, 0.515),
        kneeL: p(0.435, 0.695), kneeR: p(0.565, 0.695),
        ankleL: p(0.425, 0.895), ankleR: p(0.575, 0.895)
    )

    static let squat = BodyPose(
        head: p(0.50, 0.20), neck: p(0.50, 0.30),
        shoulderL: p(0.42, 0.33), shoulderR: p(0.58, 0.33),
        elbowL: p(0.36, 0.42), elbowR: p(0.64, 0.42),
        handL: p(0.30, 0.455), handR: p(0.70, 0.455),
        hipL: p(0.44, 0.60), hipR: p(0.56, 0.60),
        kneeL: p(0.35, 0.735), kneeR: p(0.65, 0.735),
        ankleL: p(0.42, 0.90), ankleR: p(0.58, 0.90)
    )

    static let deepSquat = squat.with {
        $0.head = p(0.50, 0.22)
        $0.neck = p(0.50, 0.32)
        $0.hipL = p(0.44, 0.63)
        $0.hipR = p(0.56, 0.63)
        $0.kneeL = p(0.32, 0.76)
        $0.kneeR = p(0.68, 0.76)
        $0.handL = p(0.38, 0.50)
        $0.handR = p(0.62, 0.50)
    }

    static let hinge = stand.with {
        $0.head = p(0.60, 0.245)
        $0.neck = p(0.555, 0.325)
        $0.shoulderL = p(0.525, 0.36)
        $0.shoulderR = p(0.60, 0.375)
        $0.elbowL = p(0.515, 0.465)
        $0.elbowR = p(0.61, 0.48)
        $0.handL = p(0.51, 0.57)
        $0.handR = p(0.62, 0.585)
        $0.hipL = p(0.465, 0.535)
        $0.hipR = p(0.565, 0.545)
        $0.kneeL = p(0.445, 0.705)
        $0.kneeR = p(0.58, 0.715)
        $0.ankleL = p(0.425, 0.895)
        $0.ankleR = p(0.585, 0.90)
    }

    static let lungeL = BodyPose(
        head: p(0.49, 0.15), neck: p(0.49, 0.255),
        shoulderL: p(0.41, 0.295), shoulderR: p(0.57, 0.295),
        elbowL: p(0.385, 0.405), elbowR: p(0.595, 0.405),
        handL: p(0.385, 0.515), handR: p(0.595, 0.515),
        hipL: p(0.44, 0.54), hipR: p(0.55, 0.54),
        kneeL: p(0.38, 0.70), kneeR: p(0.65, 0.70),
        ankleL: p(0.37, 0.895), ankleR: p(0.74, 0.86)
    )
    static let lungeR = lungeL.mirrored()

    static let pushupHigh = BodyPose(
        head: p(0.21, 0.40), neck: p(0.29, 0.42), headRadius: 0.045,
        shoulderL: p(0.33, 0.435), shoulderR: p(0.35, 0.45),
        elbowL: p(0.33, 0.555), elbowR: p(0.35, 0.57),
        handL: p(0.33, 0.685), handR: p(0.35, 0.70),
        hipL: p(0.56, 0.50), hipR: p(0.595, 0.515),
        kneeL: p(0.72, 0.555), kneeR: p(0.75, 0.57),
        ankleL: p(0.85, 0.615), ankleR: p(0.88, 0.63)
    )

    static let pushupLow = pushupHigh.with {
        $0.head = p(0.19, 0.53)
        $0.neck = p(0.28, 0.545)
        $0.shoulderL = p(0.32, 0.555)
        $0.shoulderR = p(0.34, 0.565)
        $0.elbowL = p(0.265, 0.55)
        $0.elbowR = p(0.285, 0.56)
        $0.handL = p(0.33, 0.685)
        $0.handR = p(0.35, 0.70)
        $0.hipL = p(0.56, 0.61)
        $0.hipR = p(0.595, 0.62)
        $0.kneeL = p(0.72, 0.635)
        $0.kneeR = p(0.75, 0.645)
        $0.ankleL = p(0.85, 0.665)
        $0.ankleR = p(0.88, 0.675)
    }

    static let plank = BodyPose(
        head: p(0.20, 0.40), neck: p(0.28, 0.43), headRadius: 0.045,
        shoulderL: p(0.33, 0.445), shoulderR: p(0.35, 0.455),
        elbowL: p(0.34, 0.665), elbowR: p(0.36, 0.675),
        handL: p(0.47, 0.675), handR: p(0.49, 0.685),
        hipL: p(0.56, 0.515), hipR: p(0.595, 0.53),
        kneeL: p(0.72, 0.57), kneeR: p(0.75, 0.585),
        ankleL: p(0.85, 0.63), ankleR: p(0.88, 0.645)
    )

    static let sidePlank = BodyPose(
        head: p(0.30, 0.40), neck: p(0.37, 0.44), headRadius: 0.045,
        shoulderL: p(0.42, 0.47), shoulderR: p(0.43, 0.48),
        elbowL: p(0.48, 0.64), elbowR: p(0.43, 0.47),
        handL: p(0.62, 0.66), handR: p(0.50, 0.25),
        hipL: p(0.60, 0.58), hipR: p(0.61, 0.59),
        kneeL: p(0.75, 0.68), kneeR: p(0.76, 0.69),
        ankleL: p(0.87, 0.79), ankleR: p(0.88, 0.80)
    )

    static let dipTop = BodyPose(
        head: p(0.50, 0.16), neck: p(0.50, 0.27),
        shoulderL: p(0.42, 0.30), shoulderR: p(0.58, 0.30),
        elbowL: p(0.42, 0.43), elbowR: p(0.58, 0.43),
        handL: p(0.42, 0.56), handR: p(0.58, 0.56),
        hipL: p(0.46, 0.54), hipR: p(0.54, 0.54),
        kneeL: p(0.53, 0.70), kneeR: p(0.61, 0.70),
        ankleL: p(0.62, 0.84), ankleR: p(0.70, 0.84)
    )

    static let dipBottom = BodyPose(
        head: p(0.50, 0.23), neck: p(0.50, 0.34),
        shoulderL: p(0.42, 0.37), shoulderR: p(0.58, 0.37),
        elbowL: p(0.31, 0.48), elbowR: p(0.69, 0.48),
        handL: p(0.42, 0.58), handR: p(0.58, 0.58),
        hipL: p(0.46, 0.62), hipR: p(0.54, 0.62),
        kneeL: p(0.52, 0.77), kneeR: p(0.60, 0.77),
        ankleL: p(0.59, 0.90), ankleR: p(0.67, 0.90)
    )

    static let pullupHang = BodyPose(
        head: p(0.50, 0.25), neck: p(0.50, 0.34), headRadius: 0.048,
        shoulderL: p(0.44, 0.37), shoulderR: p(0.56, 0.37),
        elbowL: p(0.43, 0.22), elbowR: p(0.57, 0.22),
        handL: p(0.42, 0.08), handR: p(0.58, 0.08),
        hipL: p(0.46, 0.56), hipR: p(0.54, 0.56),
        kneeL: p(0.445, 0.735), kneeR: p(0.555, 0.735),
        ankleL: p(0.445, 0.905), ankleR: p(0.555, 0.905)
    )

    static let pullupTop = BodyPose(
        head: p(0.50, 0.145), neck: p(0.50, 0.235), headRadius: 0.048,
        shoulderL: p(0.44, 0.265), shoulderR: p(0.56, 0.265),
        elbowL: p(0.355, 0.185), elbowR: p(0.645, 0.185),
        handL: p(0.42, 0.08), handR: p(0.58, 0.08),
        hipL: p(0.46, 0.45), hipR: p(0.54, 0.45),
        kneeL: p(0.40, 0.60), kneeR: p(0.60, 0.60),
        ankleL: p(0.37, 0.72), ankleR: p(0.63, 0.72)
    )

    static let pressDown = stand.with {
        $0.shoulderL = p(0.42, 0.29)
        $0.shoulderR = p(0.58, 0.29)
        $0.elbowL = p(0.37, 0.375)
        $0.elbowR = p(0.63, 0.375)
        $0.handL = p(0.37, 0.27)
        $0.handR = p(0.63, 0.27)
    }

    static let pressUp = stand.with {
        $0.elbowL = p(0.42, 0.205)
        $0.elbowR = p(0.58, 0.205)
        $0.handL = p(0.45, 0.075)
        $0.handR = p(0.55, 0.075)
    }

    static let benchDown = BodyPose(
        head: p(0.20, 0.60), neck: p(0.27, 0.615), headRadius: 0.048,
        shoulderL: p(0.32, 0.63), shoulderR: p(0.34, 0.64),
        elbowL: p(0.31, 0.49), elbowR: p(0.37, 0.49),
        handL: p(0.33, 0.40), handR: p(0.39, 0.40),
        hipL: p(0.55, 0.66), hipR: p(0.58, 0.66),
        kneeL: p(0.70, 0.56), kneeR: p(0.64, 0.57),
        ankleL: p(0.72, 0.84), ankleR: p(0.66, 0.84)
    )

    static let benchUp = benchDown.with {
        $0.elbowL = p(0.315, 0.445)
        $0.elbowR = p(0.37, 0.445)
        $0.handL = p(0.325, 0.285)
        $0.handR = p(0.38, 0.285)
    }

    static let rowHinge = hinge.with {
        $0.elbowL = p(0.515, 0.50)
        $0.elbowR = p(0.61, 0.51)
        $0.handL = p(0.51, 0.62)
        $0.handR = p(0.62, 0.63)
    }

    static let rowPull = rowHinge.with {
        $0.elbowL = p(0.60, 0.45)
        $0.elbowR = p(0.65, 0.47)
        $0.handL = p(0.50, 0.53)
        $0.handR = p(0.57, 0.55)
    }

    static let curlDown = stand

    static let curlUp = stand.with {
        $0.elbowL = p(0.42, 0.385)
        $0.elbowR = p(0.58, 0.385)
        $0.handL = p(0.435, 0.285)
        $0.handR = p(0.565, 0.285)
    }

    static let lateralUp = stand.with {
        $0.elbowL = p(0.295, 0.305)
        $0.elbowR = p(0.705, 0.305)
        $0.handL = p(0.18, 0.315)
        $0.handR = p(0.82, 0.315)
    }

    static let calfUp = stand.with {
        $0.head = p(0.50, 0.11)
        $0.neck = p(0.50, 0.215)
        $0.shoulderL = p(0.42, 0.255)
        $0.shoulderR = p(0.58, 0.255)
        $0.elbowL = p(0.395, 0.365)
        $0.elbowR = p(0.605, 0.365)
        $0.handL = p(0.395, 0.475)
        $0.handR = p(0.605, 0.475)
        $0.hipL = p(0.445, 0.495)
        $0.hipR = p(0.555, 0.495)
        $0.kneeL = p(0.435, 0.675)
        $0.kneeR = p(0.565, 0.675)
        $0.ankleL = p(0.43, 0.865)
        $0.ankleR = p(0.57, 0.865)
    }

    static let hipThrustDown = BodyPose(
        head: p(0.20, 0.46), neck: p(0.28, 0.50), headRadius: 0.048,
        shoulderL: p(0.34, 0.52), shoulderR: p(0.36, 0.53),
        elbowL: p(0.33, 0.64), elbowR: p(0.37, 0.65),
        handL: p(0.29, 0.75), handR: p(0.33, 0.76),
        hipL: p(0.58, 0.63), hipR: p(0.61, 0.63),
        kneeL: p(0.70, 0.55), kneeR: p(0.74, 0.56),
        ankleL: p(0.80, 0.74), ankleR: p(0.84, 0.75)
    )

    static let hipThrustUp = hipThrustDown.with {
        $0.hipL = p(0.58, 0.48)
        $0.hipR = p(0.61, 0.48)
        $0.kneeL = p(0.69, 0.56)
        $0.kneeR = p(0.73, 0.57)
        $0.ankleL = p(0.76, 0.76)
        $0.ankleR = p(0.80, 0.77)
    }

    static let bridgeDown = BodyPose(
        head: p(0.18, 0.78), neck: p(0.26, 0.78), headRadius: 0.048,
        shoulderL: p(0.32, 0.79), shoulderR: p(0.34, 0.80),
        elbowL: p(0.29, 0.84), elbowR: p(0.37, 0.84),
        handL: p(0.27, 0.90), handR: p(0.39, 0.90),
        hipL: p(0.57, 0.78), hipR: p(0.60, 0.78),
        kneeL: p(0.64, 0.60), kneeR: p(0.68, 0.60),
        ankleL: p(0.64, 0.90), ankleR: p(0.68, 0.90)
    )

    static let bridgeUp = bridgeDown.with {
        $0.hipL = p(0.57, 0.61)
        $0.hipR = p(0.60, 0.61)
        $0.kneeL = p(0.67, 0.58)
        $0.kneeR = p(0.71, 0.58)
    }

    static let hollow = BodyPose(
        head: p(0.25, 0.64), neck: p(0.32, 0.68), headRadius: 0.048,
        shoulderL: p(0.37, 0.70), shoulderR: p(0.39, 0.71),
        elbowL: p(0.28, 0.64), elbowR: p(0.30, 0.65),
        handL: p(0.18, 0.60), handR: p(0.20, 0.61),
        hipL: p(0.58, 0.74), hipR: p(0.61, 0.74),
        kneeL: p(0.70, 0.66), kneeR: p(0.74, 0.66),
        ankleL: p(0.84, 0.58), ankleR: p(0.88, 0.58)
    )

    static let legRaiseDown = pullupHang.with {
        $0.hipL = p(0.47, 0.58)
        $0.hipR = p(0.53, 0.58)
        $0.kneeL = p(0.465, 0.75)
        $0.kneeR = p(0.535, 0.75)
        $0.ankleL = p(0.465, 0.91)
        $0.ankleR = p(0.535, 0.91)
    }

    static let legRaiseUp = legRaiseDown.with {
        $0.kneeL = p(0.40, 0.47)
        $0.kneeR = p(0.60, 0.47)
        $0.ankleL = p(0.31, 0.56)
        $0.ankleR = p(0.69, 0.56)
    }

    static let mountainClimberL = plank.with {
        $0.kneeL = p(0.44, 0.60)
        $0.ankleL = p(0.32, 0.66)
    }
    static let mountainClimberR = mountainClimberL.mirrored()

    static let burpeeStand = stand
    static let burpeeSquat = squat.with {
        $0.handL = p(0.40, 0.80)
        $0.handR = p(0.60, 0.80)
        $0.elbowL = p(0.40, 0.64)
        $0.elbowR = p(0.60, 0.64)
    }

    static let burpeePlank = pushupHigh
    static let burpeeJump = BodyPose(
        head: p(0.50, 0.11), neck: p(0.50, 0.22),
        shoulderL: p(0.42, 0.26), shoulderR: p(0.58, 0.26),
        elbowL: p(0.34, 0.18), elbowR: p(0.66, 0.18),
        handL: p(0.38, 0.06), handR: p(0.62, 0.06),
        hipL: p(0.45, 0.50), hipR: p(0.55, 0.50),
        kneeL: p(0.40, 0.68), kneeR: p(0.60, 0.68),
        ankleL: p(0.34, 0.84), ankleR: p(0.66, 0.84)
    )

    static let downDog = BodyPose(
        head: p(0.23, 0.61), neck: p(0.31, 0.60), headRadius: 0.048,
        shoulderL: p(0.36, 0.58), shoulderR: p(0.38, 0.59),
        elbowL: p(0.29, 0.68), elbowR: p(0.31, 0.69),
        handL: p(0.18, 0.82), handR: p(0.20, 0.83),
        hipL: p(0.55, 0.28), hipR: p(0.58, 0.29),
        kneeL: p(0.64, 0.55), kneeR: p(0.67, 0.56),
        ankleL: p(0.73, 0.88), ankleR: p(0.76, 0.89)
    )

    static let cobra = BodyPose(
        head: p(0.20, 0.47), neck: p(0.28, 0.53), headRadius: 0.048,
        shoulderL: p(0.34, 0.57), shoulderR: p(0.36, 0.58),
        elbowL: p(0.32, 0.68), elbowR: p(0.35, 0.69),
        handL: p(0.32, 0.82), handR: p(0.35, 0.83),
        hipL: p(0.58, 0.73), hipR: p(0.61, 0.73),
        kneeL: p(0.73, 0.77), kneeR: p(0.76, 0.77),
        ankleL: p(0.87, 0.81), ankleR: p(0.90, 0.81)
    )

    static let warrior = BodyPose(
        head: p(0.50, 0.15), neck: p(0.50, 0.25),
        shoulderL: p(0.41, 0.29), shoulderR: p(0.59, 0.29),
        elbowL: p(0.28, 0.30), elbowR: p(0.72, 0.30),
        handL: p(0.14, 0.31), handR: p(0.86, 0.31),
        hipL: p(0.44, 0.53), hipR: p(0.56, 0.53),
        kneeL: p(0.32, 0.70), kneeR: p(0.68, 0.70),
        ankleL: p(0.28, 0.90), ankleR: p(0.79, 0.90)
    )

    static let tree = BodyPose(
        head: p(0.50, 0.12), neck: p(0.50, 0.22),
        shoulderL: p(0.43, 0.26), shoulderR: p(0.57, 0.26),
        elbowL: p(0.42, 0.16), elbowR: p(0.58, 0.16),
        handL: p(0.47, 0.055), handR: p(0.53, 0.055),
        hipL: p(0.46, 0.52), hipR: p(0.54, 0.52),
        kneeL: p(0.455, 0.71), kneeR: p(0.60, 0.66),
        ankleL: p(0.455, 0.90), ankleR: p(0.51, 0.72)
    )

    static let childsPose = BodyPose(
        head: p(0.30, 0.68), neck: p(0.37, 0.65), headRadius: 0.048,
        shoulderL: p(0.41, 0.64), shoulderR: p(0.43, 0.65),
        elbowL: p(0.31, 0.71), elbowR: p(0.33, 0.72),
        handL: p(0.19, 0.76), handR: p(0.21, 0.77),
        hipL: p(0.57, 0.74), hipR: p(0.60, 0.74),
        kneeL: p(0.65, 0.82), kneeR: p(0.68, 0.82),
        ankleL: p(0.73, 0.89), ankleR: p(0.76, 0.89)
    )

    static let cat = BodyPose(
        head: p(0.19, 0.56), neck: p(0.28, 0.55), headRadius: 0.045,
        shoulderL: p(0.34, 0.57), shoulderR: p(0.36, 0.58),
        elbowL: p(0.34, 0.68), elbowR: p(0.36, 0.69),
        handL: p(0.34, 0.81), handR: p(0.36, 0.82),
        hipL: p(0.59, 0.53), hipR: p(0.62, 0.54),
        kneeL: p(0.64, 0.68), kneeR: p(0.67, 0.69),
        ankleL: p(0.72, 0.82), ankleR: p(0.75, 0.83)
    )

    static let cow = cat.with {
        $0.head = p(0.19, 0.48)
        $0.neck = p(0.28, 0.50)
        $0.hipL = p(0.59, 0.58)
        $0.hipR = p(0.62, 0.59)
    }

    static let twistL = BodyPose(
        head: p(0.48, 0.27), neck: p(0.48, 0.36),
        shoulderL: p(0.38, 0.39), shoulderR: p(0.58, 0.41),
        elbowL: p(0.30, 0.47), elbowR: p(0.66, 0.48),
        handL: p(0.39, 0.55), handR: p(0.60, 0.54),
        hipL: p(0.44, 0.60), hipR: p(0.56, 0.60),
        kneeL: p(0.32, 0.73), kneeR: p(0.68, 0.73),
        ankleL: p(0.39, 0.86), ankleR: p(0.61, 0.86)
    )
    static let twistR = twistL.mirrored()

    static let pigeon = BodyPose(
        head: p(0.40, 0.31), neck: p(0.42, 0.40),
        shoulderL: p(0.34, 0.44), shoulderR: p(0.48, 0.45),
        elbowL: p(0.27, 0.55), elbowR: p(0.55, 0.56),
        handL: p(0.22, 0.67), handR: p(0.62, 0.67),
        hipL: p(0.48, 0.60), hipR: p(0.56, 0.60),
        kneeL: p(0.30, 0.68), kneeR: p(0.72, 0.72),
        ankleL: p(0.52, 0.76), ankleR: p(0.86, 0.82)
    )

    static let legsUp = BodyPose(
        head: p(0.20, 0.76), neck: p(0.28, 0.76), headRadius: 0.048,
        shoulderL: p(0.33, 0.78), shoulderR: p(0.35, 0.78),
        elbowL: p(0.29, 0.85), elbowR: p(0.38, 0.85),
        handL: p(0.24, 0.90), handR: p(0.42, 0.90),
        hipL: p(0.56, 0.76), hipR: p(0.59, 0.76),
        kneeL: p(0.58, 0.54), kneeR: p(0.61, 0.54),
        ankleL: p(0.58, 0.30), ankleR: p(0.61, 0.30)
    )

    static let hipRotationL = BodyPose(
        head: p(0.48, 0.28), neck: p(0.48, 0.37),
        shoulderL: p(0.39, 0.40), shoulderR: p(0.57, 0.40),
        elbowL: p(0.33, 0.50), elbowR: p(0.63, 0.50),
        handL: p(0.36, 0.61), handR: p(0.60, 0.61),
        hipL: p(0.44, 0.61), hipR: p(0.56, 0.61),
        kneeL: p(0.31, 0.69), kneeR: p(0.66, 0.68),
        ankleL: p(0.44, 0.83), ankleR: p(0.55, 0.84)
    )
    static let hipRotationR = hipRotationL.mirrored()

    static let shoulderStretchDown = BodyPose(
        head: p(0.50, 0.16), neck: p(0.50, 0.255),
        shoulderL: p(0.42, 0.295), shoulderR: p(0.58, 0.295),
        elbowL: p(0.40, 0.42), elbowR: p(0.60, 0.42),
        handL: p(0.47, 0.53), handR: p(0.53, 0.53),
        hipL: p(0.445, 0.53), hipR: p(0.555, 0.53),
        kneeL: p(0.435, 0.715), kneeR: p(0.565, 0.715),
        ankleL: p(0.425, 0.90), ankleR: p(0.575, 0.90)
    )

    static let shoulderStretchUp = shoulderStretchDown.with {
        $0.elbowL = p(0.39, 0.20)
        $0.elbowR = p(0.61, 0.20)
        $0.handL = p(0.47, 0.10)
        $0.handR = p(0.53, 0.10)
    }

    static let hipFlexorStretch = BodyPose(
        head: p(0.48, 0.18), neck: p(0.48, 0.28),
        shoulderL: p(0.40, 0.32), shoulderR: p(0.56, 0.32),
        elbowL: p(0.37, 0.20), elbowR: p(0.59, 0.42),
        handL: p(0.36, 0.09), handR: p(0.60, 0.53),
        hipL: p(0.44, 0.52), hipR: p(0.54, 0.52),
        kneeL: p(0.35, 0.70), kneeR: p(0.68, 0.72),
        ankleL: p(0.34, 0.90), ankleR: p(0.80, 0.84)
    )

    static let hamstringStretch = BodyPose(
        head: p(0.54, 0.34), neck: p(0.52, 0.42),
        shoulderL: p(0.45, 0.45), shoulderR: p(0.57, 0.46),
        elbowL: p(0.42, 0.56), elbowR: p(0.56, 0.57),
        handL: p(0.41, 0.68), handR: p(0.55, 0.69),
        hipL: p(0.45, 0.55), hipR: p(0.55, 0.55),
        kneeL: p(0.47, 0.72), kneeR: p(0.62, 0.72),
        ankleL: p(0.44, 0.90), ankleR: p(0.73, 0.80)
    )

    static let calfStretch = BodyPose(
        head: p(0.44, 0.18), neck: p(0.45, 0.27),
        shoulderL: p(0.38, 0.31), shoulderR: p(0.52, 0.31),
        elbowL: p(0.31, 0.36), elbowR: p(0.60, 0.37),
        handL: p(0.20, 0.40), handR: p(0.70, 0.41),
        hipL: p(0.43, 0.52), hipR: p(0.53, 0.52),
        kneeL: p(0.49, 0.69), kneeR: p(0.32, 0.72),
        ankleL: p(0.54, 0.90), ankleR: p(0.22, 0.90)
    )

    static let neckStretchL = stand.with {
        $0.head = p(0.58, 0.14)
        $0.neck = p(0.51, 0.235)
        $0.handR = p(0.60, 0.19)
        $0.elbowR = p(0.62, 0.31)
    }
    static let neckStretchR = neckStretchL.mirrored()

    static let wristPrep = BodyPose(
        head: p(0.24, 0.55), neck: p(0.32, 0.55), headRadius: 0.045,
        shoulderL: p(0.37, 0.57), shoulderR: p(0.39, 0.58),
        elbowL: p(0.38, 0.69), elbowR: p(0.40, 0.70),
        handL: p(0.46, 0.80), handR: p(0.48, 0.81),
        hipL: p(0.58, 0.55), hipR: p(0.61, 0.56),
        kneeL: p(0.63, 0.70), kneeR: p(0.66, 0.71),
        ankleL: p(0.70, 0.85), ankleR: p(0.73, 0.86)
    )

    static let breatheIn = BodyPose(
        head: p(0.50, 0.26), neck: p(0.50, 0.35),
        shoulderL: p(0.42, 0.39), shoulderR: p(0.58, 0.39),
        elbowL: p(0.34, 0.47), elbowR: p(0.66, 0.47),
        handL: p(0.40, 0.56), handR: p(0.60, 0.56),
        hipL: p(0.44, 0.61), hipR: p(0.56, 0.61),
        kneeL: p(0.33, 0.74), kneeR: p(0.67, 0.74),
        ankleL: p(0.41, 0.87), ankleR: p(0.59, 0.87)
    )

    static let breatheOut = breatheIn.with {
        $0.head = p(0.50, 0.28)
        $0.shoulderL = p(0.435, 0.40)
        $0.shoulderR = p(0.565, 0.40)
        $0.elbowL = p(0.37, 0.49)
        $0.elbowR = p(0.63, 0.49)
        $0.handL = p(0.42, 0.58)
        $0.handR = p(0.58, 0.58)
    }

    static let runA = BodyPose(
        head: p(0.52, 0.13), neck: p(0.51, 0.23),
        shoulderL: p(0.44, 0.27), shoulderR: p(0.58, 0.27),
        elbowL: p(0.36, 0.34), elbowR: p(0.65, 0.35),
        handL: p(0.30, 0.40), handR: p(0.70, 0.42),
        hipL: p(0.46, 0.51), hipR: p(0.56, 0.51),
        kneeL: p(0.35, 0.63), kneeR: p(0.61, 0.72),
        ankleL: p(0.30, 0.73), ankleR: p(0.70, 0.88)
    )

    static let runB = runA.mirrored()

    static let jumpingJackIn = stand

    static let jumpingJackOut = BodyPose(
        head: p(0.50, 0.12), neck: p(0.50, 0.22),
        shoulderL: p(0.43, 0.26), shoulderR: p(0.57, 0.26),
        elbowL: p(0.33, 0.17), elbowR: p(0.67, 0.17),
        handL: p(0.35, 0.05), handR: p(0.65, 0.05),
        hipL: p(0.45, 0.50), hipR: p(0.55, 0.50),
        kneeL: p(0.33, 0.69), kneeR: p(0.67, 0.69),
        ankleL: p(0.20, 0.88), ankleR: p(0.80, 0.88)
    )

    static let boxingGuard = BodyPose(
        head: p(0.56, 0.16), neck: p(0.54, 0.25),
        shoulderL: p(0.46, 0.29), shoulderR: p(0.60, 0.30),
        elbowL: p(0.47, 0.40), elbowR: p(0.64, 0.41),
        handL: p(0.55, 0.32), handR: p(0.58, 0.29),
        hipL: p(0.46, 0.53), hipR: p(0.55, 0.53),
        kneeL: p(0.41, 0.71), kneeR: p(0.61, 0.71),
        ankleL: p(0.37, 0.89), ankleR: p(0.67, 0.89)
    )

    static let boxingPunch = boxingGuard.with {
        $0.head = p(0.52, 0.16)
        $0.neck = p(0.51, 0.25)
        $0.shoulderL = p(0.43, 0.30)
        $0.elbowL = p(0.31, 0.31)
        $0.handL = p(0.13, 0.32)
        $0.handR = p(0.54, 0.29)
    }

    static let pikeUp = downDog
    static let pikeDown = downDog.with {
        $0.head = p(0.26, 0.70)
        $0.neck = p(0.33, 0.65)
        $0.elbowL = p(0.24, 0.74)
        $0.elbowR = p(0.26, 0.75)
    }

    static let wallSit = BodyPose(
        head: p(0.46, 0.18), neck: p(0.46, 0.28),
        shoulderL: p(0.38, 0.32), shoulderR: p(0.54, 0.32),
        elbowL: p(0.36, 0.44), elbowR: p(0.56, 0.44),
        handL: p(0.39, 0.54), handR: p(0.57, 0.54),
        hipL: p(0.45, 0.58), hipR: p(0.55, 0.58),
        kneeL: p(0.58, 0.72), kneeR: p(0.62, 0.72),
        ankleL: p(0.60, 0.90), ankleR: p(0.64, 0.90)
    )
}
