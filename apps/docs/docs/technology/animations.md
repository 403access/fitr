---
sidebar_position: 5
title: Animations
---

# Animations

Fitr has no video, GIF, Lottie or sprite-sheet assets. Every exercise is drawn live from a
14-joint skeleton. This page explains the model, the renderer and how to add a movement.

## Why procedural?

| Approach | Asset weight | Resolution | Tinting | Authoring cost |
| --- | --- | --- | --- | --- |
| Video | Very high | Fixed | Hard | Filming + editing |
| GIF / APNG | High | Fixed | Hard | Frame-by-frame |
| Lottie | Medium | Vector | Possible | After Effects |
| Sprite sheet | Medium | Fixed | Hard | Frame-by-frame |
| **Canvas skeleton** | **Zero** | **Infinite** | **One line** | **Keyframes** |

The skeleton also gives us semantic data: if we know where the joints are, we can later
highlight a muscle, add form annotations or compare the user’s pose to the model.

## The pose

```swift
struct BodyPose {
  var head: CGPoint
  var neck: CGPoint
  var shoulderL, shoulderR: CGPoint
  var elbowL, elbowR: CGPoint
  var handL, handR: CGPoint
  var hipL, hipR: CGPoint
  var kneeL, kneeR: CGPoint
  var ankleL, ankleR: CGPoint
  var headRadius: CGFloat
}
```

Coordinates are normalized to a 0–1 square, y down. The renderer maps them into the largest
centered square of the available Canvas, so the same pose works at 58 pt and 360 pt.

Poses are declared in `Poses` using a standing base and `.with { … }` overrides:

```swift
static let squat = BodyPose(
  head: p(0.50, 0.20), neck: p(0.50, 0.30),
  shoulderL: p(0.42, 0.33), shoulderR: p(0.58, 0.33),
  elbowL: p(0.36, 0.42), elbowR: p(0.64, 0.42),
  handL: p(0.30, 0.455), handR: p(0.70, 0.455),
  hipL: p(0.44, 0.60), hipR: p(0.56, 0.60),
  kneeL: p(0.35, 0.735), kneeR: p(0.65, 0.735),
  ankleL: p(0.42, 0.90), ankleR: p(0.58, 0.90)
)
```

`mirrored()` swaps left and right and mirrors x, which is how lunges, running and twists alternate
without duplicating every pose.

## The sequence

```swift
struct MotionSequence {
  let keyframes: [BodyPose]
  let duration: Double
  let mode: LoopMode // pingPong | loop
}
```

- **pingPong** plays 0 → 1 → 0. Used for reps (squat, push-up, curl) and holds (plank, cobra).
- **loop** walks through every keyframe and back to the first. Used for alternating patterns
  (lunge, mountain climber, burpee, twist) and boxing combos.

Timing is intentional:

| Family | Duration | Feel |
| --- | ---: | --- |
| Run / jumping jacks | 1.1–1.5 s | Fast, elastic |
| Strength reps | 2.4–3.8 s | Controlled tempo |
| Holds and yoga | 4.5–8 s | Slow breath-led |
| Breathwork | 10 s | Full inhale/exhale cycle |

## Interpolation

```swift
let phase = (elapsed / duration).truncatingRemainder(dividingBy: 1)
let t = mode == .pingPong
  ? (phase < 0.5 ? phase * 2 : 2 - phase * 2)
  : phase
let eased = t * t * (3 - 2 * t)           // smoothstep
```

Smoothstep removes the mechanical linear feel at pose boundaries while keeping the pose exactly
on keyframes at the extremes.

## Rendering

`AnimatedExerciseFigure` uses:

```swift
TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
  Canvas { context, size in
    // draw aura, ring, floor, ghost, skeleton, sparks
  }
}
```

Drawing order:

1. **Aura** — radial gradient centred on the hips, tinted by the topic.
2. **Calibration ring** — rotating dashed circle at low opacity.
3. **Floor** — elliptical radial gradient under the feet.
4. **Ghost** — skeleton sampled 0.12 s earlier at 10% opacity.
5. **Back limbs** — right arm and leg at 34% opacity.
6. **Torso** — gradient-filled polygon from shoulders to hips.
7. **Front limbs** — angular gradient strokes with a soft glow pass.
8. **Head** — radial gradient circle with a rim.
9. **Joints** — small lime dots at elbows, knees, hands and ankles.
10. **Sparks** — five deterministic particles drifting on sine/cosine paths.

All dimensions are proportional to `min(width, height)`, and line caps are round. That is what
makes the same code read as a deliberate illustration at every size.

## Performance

- Each frame is a handful of paths; no image decoding.
- 30 fps is sufficient for the visual language and cheaper than 60.
- Animations pause for completed/skipped tasks and when the containing view is not rendered.
- Canvas is not rasterized with `.drawingGroup()`, which preserves crisp vector edges and
  avoids offscreen buffer surprises.
- The skeleton renderer is stateless; only the phase changes per frame.

## Adding an exercise animation

1. Add one or more `BodyPose` values to `Poses`.
2. Add a case to `ExerciseMotion.sequence(for:)` with keyframes, duration and mode.
3. Set `animation` on the server seed exercise to the same key.
4. Run `bun run export:catalog` to regenerate the iOS catalogue.
5. Add the key to `FitrTests.testEveryAnimationHasMovement`.
6. Verify in the simulator at thumbnail, card and player sizes.

If a new exercise can reuse an existing family (e.g. another hinge), reuse the key. A unique
key is only needed when the silhouette or tempo must differ.

## Fallback behaviour

Any unknown animation key falls back to a slow breathing sequence. This keeps new catalogue
entries safe even if the iOS build has not yet implemented the specific motion.

## Future work

- **Pose annotations** — highlights for the primary muscle group based on joint angles.
- **User pose comparison** — camera-based form feedback using the same skeleton.
- **Reduced motion** — choose a meaningful static keyframe instead of animating.
- **Live Activity timer** — show a hold countdown on the Lock Screen.
- **More archetypes** — Turkish get-up, snatch, muscle-up, kettlebell clean.
- **Sound design** — optional breath and tempo cues.
