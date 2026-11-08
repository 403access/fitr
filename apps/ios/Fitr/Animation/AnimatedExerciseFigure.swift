import SwiftUI

/// A living, resolution-independent exercise illustration rendered entirely in
/// SwiftUI Canvas. No video, no sprite sheets — every rep is generated from
/// keyframed joint positions.
struct AnimatedExerciseFigure: View {
    let animation: String
    var accent: Color = Theme.lime
    var isActive: Bool = true
    var showsChrome: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                draw(context: &context, size: size, elapsed: elapsed)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(context: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let side = min(size.width, size.height)
        let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)

        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + point.x * side, y: origin.y + point.y * side)
        }

        let motion = ExerciseMotion.sequence(for: animation)
        let pose = motion.pose(at: elapsed)
        let ghost = motion.pose(at: elapsed - 0.12)

        // Ambient aura
        let center = map(CGPoint(x: (pose.hipL.x + pose.hipR.x) / 2, y: (pose.hipL.y + pose.hipR.y) / 2))
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [accent.opacity(0.20), accent.opacity(0.03), .clear]),
                center: center,
                startRadius: 0,
                endRadius: side * 0.62
            )
        )

        // Rotating calibration ring
        if showsChrome {
            var ring = context
            ring.translateBy(x: size.width / 2, y: size.height / 2)
            ring.rotate(by: .radians(elapsed.truncatingRemainder(dividingBy: 24) / 24 * .pi * 2))
            let circle = Path(ellipseIn: CGRect(x: -side * 0.44, y: -side * 0.44, width: side * 0.88, height: side * 0.88))
            ring.stroke(
                circle,
                with: .color(accent.opacity(0.10)),
                style: StrokeStyle(lineWidth: 1, dash: [1.5, 9], dashPhase: 0)
            )
        }

        // Floor
        let floor = CGRect(
            x: map(CGPoint(x: 0.30, y: 0.94)).x,
            y: map(CGPoint(x: 0.5, y: 0.94)).y,
            width: side * 0.40,
            height: side * 0.026
        )
        context.fill(
            Path(ellipseIn: floor),
            with: .radialGradient(
                Gradient(colors: [accent.opacity(0.22), .clear]),
                center: CGPoint(x: floor.midX, y: floor.midY),
                startRadius: 0,
                endRadius: floor.width / 2
            )
        )

        // Motion trail
        strokeSkeleton(
            ghost,
            in: &context,
            map: map,
            side: side,
            color: accent.opacity(0.10),
            headOpacity: 0.08,
            glow: 0
        )

        strokeSkeleton(
            pose,
            in: &context,
            map: map,
            side: side,
            color: accent,
            headOpacity: 0.92,
            glow: 1
        )

        // Drifting sparks
        if showsChrome {
            for index in 0..<5 {
                let seed = Double(index) * 1.7
                let x = 0.22 + (sin(elapsed * 0.35 + seed) * 0.5 + 0.5) * 0.56
                let y = 0.16 + (cos(elapsed * 0.28 + seed * 1.4) * 0.5 + 0.5) * 0.64
                let radius = side * (0.004 + (index % 2 == 0 ? 0.003 : 0))
                let alpha = 0.18 + (sin(elapsed * 0.9 + seed) * 0.5 + 0.5) * 0.24
                let dot = Path(ellipseIn: CGRect(
                    x: map(CGPoint(x: x, y: y)).x - radius,
                    y: map(CGPoint(x: x, y: y)).y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.fill(dot, with: .color(accent.opacity(alpha)))
            }
        }
    }

    private func strokeSkeleton(
        _ pose: BodyPose,
        in context: inout GraphicsContext,
        map: (CGPoint) -> CGPoint,
        side: CGFloat,
        color: Color,
        headOpacity: Double,
        glow: CGFloat
    ) {
        let limbWidth = side * 0.022
        let backColor = color.opacity(headOpacity > 0.5 ? 0.34 : 0.09)
        let frontColor = color.opacity(headOpacity > 0.5 ? 0.92 : 0.10)

        func chain(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
            var path = Path()
            path.move(to: map(a))
            path.addLine(to: map(b))
            path.addLine(to: map(c))
            return path
        }

        let backLimbs = [
            chain(pose.shoulderR, pose.elbowR, pose.handR),
            chain(pose.hipR, pose.kneeR, pose.ankleR),
        ]
        let frontLimbs = [
            chain(pose.shoulderL, pose.elbowL, pose.handL),
            chain(pose.hipL, pose.kneeL, pose.ankleL),
        ]

        // Back limbs
        for path in backLimbs {
            if glow > 0 {
                context.stroke(
                    path,
                    with: .color(color.opacity(0.12)),
                    style: StrokeStyle(lineWidth: limbWidth * 2.1, lineCap: .round, lineJoin: .round)
                )
            }
            context.stroke(
                path,
                with: .color(backColor),
                style: StrokeStyle(lineWidth: limbWidth * 0.92, lineCap: .round, lineJoin: .round)
            )
        }

        // Torso
        var torso = Path()
        torso.move(to: map(pose.shoulderL))
        torso.addLine(to: map(pose.hipL))
        torso.addLine(to: map(pose.hipR))
        torso.addLine(to: map(pose.shoulderR))
        torso.closeSubpath()
        let torsoGradient = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [color.opacity(headOpacity > 0.5 ? 0.38 : 0.08), color.opacity(0.06)]),
            startPoint: map(pose.neck),
            endPoint: map(pose.hipL)
        )
        context.fill(torso, with: torsoGradient)
        context.stroke(
            torso,
            with: .color(frontColor.opacity(headOpacity > 0.5 ? 0.55 : 0.12)),
            style: StrokeStyle(lineWidth: side * 0.007, lineJoin: .round)
        )

        // Neck
        var neck = Path()
        neck.move(to: map(pose.neck))
        neck.addLine(to: map(CGPoint(x: (pose.shoulderL.x + pose.shoulderR.x) / 2, y: (pose.shoulderL.y + pose.shoulderR.y) / 2)))
        context.stroke(neck, with: .color(frontColor), style: StrokeStyle(lineWidth: side * 0.016, lineCap: .round))

        // Front limbs
        let limbShading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [color.opacity(headOpacity > 0.5 ? 1.0 : 0.12), color.opacity(headOpacity > 0.5 ? 0.62 : 0.08)]),
            startPoint: map(pose.shoulderL),
            endPoint: map(pose.ankleR)
        )
        for path in frontLimbs {
            if glow > 0 {
                context.stroke(
                    path,
                    with: .color(color.opacity(0.18)),
                    style: StrokeStyle(lineWidth: limbWidth * 2.4, lineCap: .round, lineJoin: .round)
                )
            }
            context.stroke(
                path,
                with: limbShading,
                style: StrokeStyle(lineWidth: limbWidth, lineCap: .round, lineJoin: .round)
            )
        }

        // Head
        let headCenter = map(pose.head)
        let radius = pose.headRadius * side
        let headRect = CGRect(x: headCenter.x - radius, y: headCenter.y - radius, width: radius * 2, height: radius * 2)
        if glow > 0 {
            context.fill(
                Path(ellipseIn: headRect.insetBy(dx: -radius * 0.55, dy: -radius * 0.55)),
                with: .color(color.opacity(0.14))
            )
        }
        context.fill(
            Path(ellipseIn: headRect),
            with: .radialGradient(
                Gradient(colors: [color.opacity(headOpacity), color.opacity(headOpacity * 0.45)]),
                center: CGPoint(x: headCenter.x - radius * 0.25, y: headCenter.y - radius * 0.3),
                startRadius: 0,
                endRadius: radius * 1.3
            )
        )
        context.stroke(
            Path(ellipseIn: headRect),
            with: .color(color.opacity(headOpacity > 0.5 ? 0.9 : 0.1)),
            lineWidth: side * 0.004
        )

        // Joints
        if headOpacity > 0.5 {
            let joints = [
                pose.kneeL, pose.kneeR, pose.elbowL, pose.elbowR,
                pose.handL, pose.handR, pose.ankleL, pose.ankleR,
            ]
            for joint in joints {
                let center = map(joint)
                let dot = CGRect(x: center.x - side * 0.006, y: center.y - side * 0.006, width: side * 0.012, height: side * 0.012)
                context.fill(Path(ellipseIn: dot), with: .color(accent.opacity(0.95)))
            }
        }
    }
}

/// Compact thumbnail used in catalogue and task rows.
struct ExerciseThumbnail: View {
    let exercise: Exercise
    var size: CGFloat = 64
    var isActive = true

    var body: some View {
        let accent = Theme.color(hex: exercise.topic.accent)
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.16), Theme.surfaceRaised],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            AnimatedExerciseFigure(animation: exercise.animation, accent: accent, isActive: isActive, showsChrome: false)
                .padding(size * 0.06)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}
