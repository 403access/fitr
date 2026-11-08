---
sidebar_position: 4
title: Design & motion
---

import useBaseUrl from '@docusaurus/useBaseUrl';

# Design & motion

Fitr should feel like a precision instrument that happens to be beautiful: dark, quiet,
high-contrast, with movement used to explain rather than entertain.

## Brand

- **Name:** Fitr — the person who trains, not the app that trains them.
- **Tagline:** *Train on your rhythm.*
- **Voice:** direct, calm, specific. “4 × 9 @ 55 kg” over “ crush your workout.”
- **Promise:** personalised training with visible, honest progression.

## Palette

| Token | Hex | Use |
| --- | --- | --- |
| Ink | `#08090C` | App and site background |
| Surface | `#13151C` | Cards, sheets, inputs |
| Surface raised | `#191C25` | Nested cards, tab bar |
| Lime | `#C9FB4B` | Primary action, completion, brand |
| Violet | `#9B7BFF` | Progress, planning, secondary emphasis |
| Coral | `#FF8A66` | Load, strength, warnings |
| Mint | `#6FE7DD` | Mobility, cues, recovery |
| Sky | `#77B7FF` | Connection, recovery, secondary data |
| Pink | `#FF6B9A` | Cardio and endurance |

Text is white at 100%, 64% and 38% opacity for three levels of hierarchy. Borders are 8%
white. The result is depth through luminance, not through a rainbow of surfaces.

## Typography

System rounded type is used throughout the app. It gives the product a human, almost tactile
quality while remaining native and free of font loading. Weights:

- **Heavy** for page titles and the primary metric on a card.
- **Bold** for card titles, buttons and navigation labels.
- **Semibold** for metadata and chips.
- **Regular** for body copy.
- **Monospaced** for numbers, prescriptions and timers, so digits do not jitter.

The marketing site and docs use the same rounded heading family with a system body stack.

## Layout

- 20 pt horizontal gutters on mobile.
- 26–30 pt corner radii for primary cards, 14–18 pt for controls.
- A floating capsule tab bar with a lime selected pill; a bottom fade keeps content legible.
- Cards use a single surface tone with subtle inner borders and occasional topic-tinted glows.
- Every screen starts with a small uppercase eyebrow, a heavy title and one sentence of context.

## Motion principles

1. **Motion is explanatory.** The figure performs the actual movement pattern, at a tempo close
   to the exercise’s real cadence (running is fast; restorative holds are slow).
2. **Nothing bounces for attention.** Springs are used for state changes, not for idle decoration.
3. **Numbers change, layouts do not.** `.contentTransition(.numericText())` keeps metrics stable.
4. **Respect reduced motion.** The Canvas renderer pauses when inactive; future work can read
   `accessibilityReduceMotion` to freeze at a representative pose.
5. **Haptics confirm, never celebrate.** Soft impact for selection, success notification for a
   completed exercise, error notification for a failed request.

## The animated figure

Every exercise is a `BodyPose`: 14 joints and a head radius in normalized 0–1 space. A
`MotionSequence` holds two to five keyframes, a duration and a loop mode. Rendering happens in
a `TimelineView(.animation)` and a SwiftUI `Canvas`:

- eased interpolation (`smoothstep`) between keyframes;
- back and front limbs drawn with different opacity for depth;
- a gradient torso, glowing head, joint dots and a soft motion trail;
- ambient radial aura and topic-tinted ring;
- five deterministic sparks drifting with sine/cosine paths.

This approach has three advantages over video: zero asset weight, infinite resolution, and
the ability to tint every illustration by its topic or re-pose it for a new variation.

<img className="docs-phone-frame" src={useBaseUrl('/img/screenshots/player.jpg')} alt="Fitr exercise player with animated figure" />

## Motion catalogue

| Family | Sequences |
| --- | --- |
| Strength | squat, hinge, lunge, bench, press, row, curl, lateral raise, calf raise, hip thrust, pull-up, dip |
| Bodyweight | push-up, pike push-up, plank, side plank, hollow hold, leg raise, mountain climber, burpee, bridge |
| Yoga | downward dog, cobra, warrior II, tree, child’s pose, cat–cow, twist, pigeon, legs up the wall |
| Mobility | hip rotation, shoulder stretch, hip-flexor stretch, hamstring stretch, calf stretch, neck stretch, wrist prep |
| Cardio | run, jumping jack, boxing |
| Recovery | breathe |

## Accessibility

- All icon-only controls carry accessibility labels.
- Key metrics combine value and label in a predictable reading order.
- Color is never the only signal: status uses icon + fill + text.
- Dynamic Type is partially supported; the design uses fixed sizes for visual rhythm today, and
  moving to `@ScaledMetric` is on the roadmap.
- Decorative Canvas art is hidden from VoiceOver; the exercise name and instructions carry the
  information.

## Website and docs

The marketing site mirrors the app: ink background, lime accents, phone frames built with CSS,
and real screenshots captured from the simulator. The Docusaurus theme overrides the default
Infima variables rather than replacing the theme, which keeps docs navigation familiar while
matching the brand.

## Design backlog

- Light theme with the same information hierarchy.
- Body map that highlights primary and auxiliary muscles spatially.
- Live Activity / Lock Screen timer for holds.
- Reduced-motion static pose selection.
- App icon variants and a proper launch animation.
