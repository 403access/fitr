---
sidebar_position: 3
title: Progression model
---

# Progression model

Fitr’s promise is that every training week asks a little more than the last. This page
documents the exact rules, so the behaviour is auditable and tunable.

## Week index

Every plan belongs to a Monday-based week. The week index is relative to the user’s
`program_start`:

```text
weekIndex = floor((startOfWeek(weekStart) − startOfWeek(programStart)) / 7) + 1
```

A fresh program starts at week 1. The seeded demo starts three weeks back, so the current week
is week 4.

## Weekly multipliers

Two multipliers define the block:

```text
volumeMultiplier    = min(1 + 0.06 × (weekIndex − 1), 1.8)
intensityMultiplier = min(1 + 0.04 × (weekIndex − 1), 1.5)
```

| Week | Volume | Intensity | Phase |
| ---: | ---: | ---: | --- |
| 1 | 1.00× | 1.00× | Foundation |
| 2 | 1.06× | 1.04× | Foundation |
| 3 | 1.12× | 1.08× | Foundation |
| 4 | 1.18× | 1.12× | Foundation |
| 5 | 1.24× | 1.16× | Build |
| 6 | 1.30× | 1.20× | Build |
| 9 | 1.48× | 1.32× | Capacity |
| 13+ | 1.72× → 1.8× | 1.48× → 1.5× | Peak |

Volume is capped at +80% and intensity at +50% relative to the catalogue baseline. This keeps
the progression meaningful without pretending that linear loading is infinite.

## Exercise-level prescription

Given the catalogue defaults for an exercise:

```text
sets  = clamp(baseSets + floor((weekIndex − 1) / 8), 1, 6)
reps  = round(baseReps × volumeMultiplier) + autoregulationReps
load  = roundTo2.5(baseLoad × intensityMultiplier + autoregulationLoad)
hold  = baseHold × clamp(1 + 0.025 × (weekIndex − 1), 1, 1.6)
```

Hold progression applies only to stretch, mobility, isometric and balance work with a base hold
of 90 seconds or less. Breathwork and long cardio keep their prescribed duration; progression
for those comes from pace, distance or consistency, not from holding a breath longer.

Recovery slots (wake, midday, pre-sleep on any day, and every slot on a recovery day) are
excluded from weekly loading. Recovery should restore capacity, not compete with it.

## Autoregulation

The engine looks at the last seven days of completed work for the same exercise:

```sql
SELECT COUNT(*), AVG(effort)
FROM tasks
WHERE user_id = ? AND exercise_id = ? AND status = 'done'
  AND date >= date(day, '-7 days') AND date < day;
```

If at least one session was completed and the average effort is **≤ 7**, the next prescription
receives one bump:

- **Loaded exercises:** +2.5 kg after the intensity multiplier, then rounded to the nearest 2.5 kg.
- **Bodyweight rep exercises:** +2 reps.
- **Isometrics and holds:** handled by the time-based hold progression.

This is deliberately conservative. It rewards sustainable completion, not grinding to failure.

## Example

Barbell back squat, base 4 × 8 @ 50 kg, rest 120 s:

| Week | Prescription | Why |
| ---: | --- | --- |
| 1 | 4 × 8 @ 50 kg | Baseline |
| 2 | 4 × 8 @ 52.5 kg | +4% intensity |
| 3 | 4 × 9 @ 55 kg | +8% intensity, +6% volume |
| 4 | 4 × 9 @ 55 kg | Rounded 2.5 kg step |
| 5 | 4 × 10 @ 57.5 kg | +16% intensity, +24% volume |

If week 4 was completed at effort 6, week 5 would receive an additional +2.5 kg.

## Plan generation

Plans are deterministic for a given user, week, day and slot. Candidate exercises are ranked by
a stable FNV-1a hash of `user:date:region:slot:week:slug`, after filtering by:

1. **Topic pool** for the slot (compound, accessory, mobility, yoga, cardio, recovery).
2. **Difficulty ceiling** from experience (beginner 2, intermediate 4, advanced 5).
3. **Equipment availability** — if the profile lists equipment, exercises requiring anything
   not listed are excluded. An empty list means a fully equipped gym.
4. **No duplicate exercise within the same day.**

This produces variety across weeks without randomness that changes on refresh.

## Improvement definitions

Progress is always compared with the immediately preceding period of the same length.

### Loaded exercises

Estimated one-rep max, Epley formula:

```text
e1RM = load × (1 + reps / 30)
```

The best e1RM in the current period is compared with the best in the previous period.

### Bodyweight reps

```text
volume = actualReps × sets
```

The best single-session total is the record.

### Isometric holds

```text
holdTotal = actualHoldSeconds × sets
```

Breathwork and cardio are excluded from PR calculations because “longer” is not always better.

### Period deltas

```text
delta% = (current − previous) / previous × 100
```

Adherence is shown as a percentage-point difference instead of a relative change, because
“adherence went up 10%” is ambiguous when the baseline is 80%.

## Why no automatic deload yet

A deload week would temporarily make the program easier, which conflicts with the explicit v0.1
requirement that each week get harder. The autoregulation rule already provides a safety valve:
if effort stays high, the engine does not add extra load. A configurable deload every 4–8 weeks
is on the [roadmap](/roadmap) as an opt-in setting.

## Tuning guide

All constants live in `apps/server/src/domain/plans.ts`:

- `createPlanRecord` — multipliers and phase label.
- `prescribe` — sets, reps, hold and load maths.
- `progressionBump` — autoregulation window and effort threshold.
- `slotsForDay` — time-region intent and session length.
- `poolFor` — how exercises are grouped for selection.

When changing the model, update this page and add a test that asserts the new invariant.
