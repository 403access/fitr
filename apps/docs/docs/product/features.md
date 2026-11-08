---
sidebar_position: 2
title: Features
---

import useBaseUrl from '@docusaurus/useBaseUrl';

# Features

Everything below is implemented in the current repository. Each section lists the user-facing
behaviour and the acceptance criteria used to verify it.

## 1. Exercise catalogue

A structured library of **60 exercises** across six topics:

| Topic | Count | Examples |
| --- | ---: | --- |
| Strength | 16 | Back squat, Romanian deadlift, hip thrust, bench press, face pull |
| Calisthenics | 12 | Push-up, pull-up, dip, hollow hold, hanging leg raise, inverted row |
| Yoga | 10 | Downward dog, cobra, warrior II, tree, pigeon, legs up the wall |
| Mobility | 11 | 90/90 rotation, couch stretch, wall slide, wrist prep, deep squat hold |
| Cardio | 6 | Zone 2 run, high knees, jumping jacks, jump rope, shadow boxing |
| Recovery | 5 | Box breathing, physiological sigh, body scan, supine twist, PMR |

Every exercise carries:

- **Topic** — the discipline (strength, yoga, mobility, calisthenics, cardio, recovery).
- **Type** — strength, stretch, mobility, balance, cardio, breathwork, plyometric, isometric.
- **Body regions** — 15 options from full body to wrists and ankles.
- **Primary muscles** — the muscles doing the work.
- **Auxiliary muscles** — supporting muscles, kept distinct from primary work.
- **Difficulty** — 1–5, used to filter plan candidates by experience.
- **Equipment** — used to restrict plan generation to what you own.
- **Coaching content** — numbered instructions, cues, benefits, breathing and safety notes.
- **Animation key** — maps to one of 41 hand-authored motion sequences.

### Filtering

The Explore screen filters client-side against the bundled catalogue: search by name, summary,
topic, type or muscle; filter by topic, type, region, muscle and difficulty. Filters combine
with AND semantics, and the active filter count is shown on the filter button.

**Acceptance criteria**

- [x] Filtering by `muscle=quads` includes barbell back squat and excludes biceps curl.
- [x] Search is case-insensitive across name, summary, topic and muscles.
- [x] The catalogue renders with the server offline (bundled `catalog.json`).
- [x] Every exercise has at least one primary muscle, one region and a working animation.
- [x] Exercise detail exposes instructions, cues, benefits, breathing, equipment and both muscle roles.

<img className="docs-phone-frame" src={useBaseUrl('/img/screenshots/catalogue.jpg')} alt="Fitr catalogue with animated exercise cards" />

## 2. Daily tasks by time region

The day is divided into six windows, each with a purpose:

| Time region | Intent | Typical content |
| --- | --- | --- |
| After wake | Wake the body before the day starts | Short mobility, deep squat hold |
| Morning | Main quality block | Compound strength + accessory |
| Midday | Reset posture and focus | Mobility, 90/90, thoracic rotation |
| Afternoon | Second quality block | Bodyweight, accessory, conditioning |
| Evening | Flow, cardio and decompress | Yoga, zone 2, mobility |
| Before sleep | Downshift for recovery | Breathwork, restorative stretch |

The plan respects training frequency. With five training days, Wednesday and Saturday are
recovery days: only a wake mobility, a midday reset and a pre-sleep downshift are scheduled.
Sunday is a full training day in the default seed.

Each task includes:

- Prescription: sets × reps, hold seconds, load, rest.
- A human-readable target (`4 × 9 @ 55 kg`, `2 × 45s hold`, `15 min conversational`).
- Estimated duration, used for the daily total and volume trends.
- Status: pending, done or skipped, with actuals and perceived effort.

**Acceptance criteria**

- [x] `GET /api/bootstrap` returns all six regions for any valid date.
- [x] The Today screen groups tasks in region order with per-region progress.
- [x] Completing, skipping and resetting a task update the day summary immediately.
- [x] Rest days are visually distinct and still contain recovery work.
- [x] Day navigation and week navigation load or generate the correct plan.

## 3. Tracker and progress

The tracker is designed to answer two questions: *did I show up?* and *am I getting better?*

### Views

- **Day** — completed vs scheduled, minutes, volume, session count.
- **Week** — seven-day chart, adherence, active days, period comparison.
- **Month** — calendar heatmap, daily bars, consistency and muscle balance.
- **Year** — twelve monthly buckets, annual totals and best records.

### Metrics

| Metric | Definition |
| --- | --- |
| Adherence | completed ÷ scheduled (tasks on or before today) |
| Minutes | sum of prescribed duration for completed tasks |
| Volume | Σ actual reps × sets × actual load, for loaded work |
| Sessions / active days | distinct dates with at least one completed task |
| Streak | consecutive dates with a completed task, ending today or yesterday |
| Personal record | best e1RM, rep total or hold total, compared with the previous period |
| Improvement | period best vs previous-period best, as a percentage |

### Improvement display

The “Proof of progress” section ranks exercises by improvement. For loaded movements the
metric is estimated one-rep max (Epley); for bodyweight movements it is total reps; for
isometrics it is total hold seconds. Each row shows the current value and a signed delta.
Personal bests appear separately with the same period-over-period comparison.

**Acceptance criteria**

- [x] `GET /api/progress?period=week` returns totals, previous totals, deltas, a seven-day series, streak, muscle shares, PRs and improvements.
- [x] Month view shows a calendar heatmap with done, partial, missed, rest and future states.
- [x] Year view aggregates the same data into twelve month buckets.
- [x] Invalid periods and dates return a 400 with a JSON error body.
- [x] Completing a task invalidates cached progress and refreshes the active period.

<img className="docs-phone-frame" src={useBaseUrl('/img/screenshots/progress.jpg')} alt="Fitr progress dashboard" />

## 4. Apple Health integration

Fitr reads the health data already available on the iPhone through HealthKit. This makes Apple
Watch, Apple Fitness, the Health app and any third-party training app that writes to Health
(Oura, Whoop, Garmin, Strava, Nike Run Club, and others) part of the same picture.

### Read

- **Overview** — today's move/exercise/stand rings, steps, sleep, resting heart rate, active
  energy and the rest of today's metrics.
- **Trends** — a 1-day, 7-day, 30-day, 90-day or 1-year range with a metric picker covering steps,
  energy, exercise, distance, sleep, resting heart rate, heart rate, HRV, mindful minutes,
  weight and stand hours. Each metric has a daily chart, average line, total/average, best day,
  latest value and a period-over-period change.
- **Workouts** — the last range of workouts from every source, filtered by activity type
  (strength, cardio, yoga, mobility, recovery, other) and source app. Includes workout count,
  minutes, energy, a workout-minutes chart and session rows.
- **Sources** — the apps and devices contributing data, what Fitr reads, and an explicit
  **Fitr-authored data** audit showing whether Fitr has ever written a workout into Health.
- **Today** — the same data is summarized in the Body-today strip on the Today screen.

Data is normalized into a local snapshot. The app does not send Health samples to the Fitr
server, and the bundle never requests clinical health records.

### Write

Completed Fitr sessions can be saved back to Health as workouts. The export uses the completed
minutes, maps the dominant exercise topic to a HealthKit activity type, adds a conservative
active-energy estimate, and writes a single workout with a stable external UUID. It is
idempotent per calendar day and can run automatically when a training day is complete.

**Acceptance criteria**

- [x] The app declares the HealthKit capability and both read/write usage descriptions.
- [x] The permission sheet is explicit; the app never prompts on cold launch.
- [x] Read data includes activity, sleep, heart, HRV, energy and body weight.
- [x] Third-party workouts and sources appear with their app names.
- [x] Trends can be filtered by 1D/7D/30D/90D/1Y and by any supported metric.
- [x] Workouts can be filtered by activity type and source app.
- [x] Sources exposes the Fitr-authored audit so write-back is verifiable.
- [x] A completed day can be written to Health once, with duplicate protection.
- [x] Health data stays on-device and is not uploaded to the API.

## 5. Exercise visualization

There are no video files and no sprite sheets. Each exercise is drawn live with SwiftUI
`Canvas` from keyframed joint positions. The renderer supports:

- eased interpolation between poses;
- mirrored poses for alternating sides;
- a loose motion trail, ambient aura, floor shadow and drifting sparks;
- topic-tinted gradients and a rotating calibration ring;
- arbitrary size, from 58 pt task thumbnails to a 360 pt player hero;
- 30 fps animation that pauses when a task is complete or a view is off screen.

See [Animations](/technology/animations) for the engine design and how to add a sequence.

## 6. Player and logging

Tapping a task opens the exercise player:

- large animated demonstration and coaching content;
- prescription tiles for sets, reps, hold, load and rest;
- a countdown timer for holds up to four minutes;
- a minute stepper for long cardio;
- load stepper in 2.5 kg increments and rep stepper;
- set dots that track how many sets you finished;
- a 1–10 perceived-effort selector with plain-language labels;
- “Complete exercise” and “Skip” actions.

Effort is not decorative: an average of 7 or below across a completed exercise allows the plan
generator to add load or reps in the following week.

**Acceptance criteria**

- [x] Completing a task sends actual reps/hold/load and effort, then refreshes the day.
- [x] The timer auto-completes a set when it reaches zero and fires a success haptic.
- [x] Skipped tasks are excluded from completed volume but visible in the day.
- [x] Done tasks can be reopened and updated, or reset to pending.

## 7. Profile, goals and equipment

The You screen controls the inputs to plan generation:

- name, goal (balanced, strength, endurance, mobility, recovery), experience;
- training days per week (2–7) and session length (15–90 minutes);
- available equipment;
- server URL with connection test and reconnect;
- current program phase, week index and multipliers;
- links to documentation and the marketing site.

Settings changes apply to **next week's** plan so the current progression stays honest. The
profile is validated server-side (days 1–7, session 10–120 minutes, known enum values).

## 8. Offline behaviour and recovery

- The catalogue ships inside the app; Explore works without a server.
- The last successful bootstrap is cached in Application Support and restored on launch.
- Connection failures show an inline banner with a retry action, never a blocking modal.
- The server URL is editable, so a physical device can target the Mac's LAN IP.
- Task completion requires the server; failed writes surface an error and keep the UI state.

## 9. Developer experience

- One command seeds the database, catalogue and demo history.
- Catalogue changes are exported to the iOS bundle with `bun run export:catalog`.
- Server tests cover catalogue filtering, plan generation, progression, completion, progress and profile validation.
- iOS tests cover date math, JSON decoding, formatting and every animation sequence.
- GitHub Actions builds the server, tests the iOS app, builds docs and deploys both websites.

## Known gaps

- Single-user mode; user identity is a header with a demo default.
- No authentication or transport security configuration for remote hosting.
- Progress sessions are measured by distinct days, not by explicit workout sessions.
- Bodyweight volume is not normalised by body mass.
- Deload weeks are not automatic; this is intentional for v0.1 but planned as a setting.
- App Store distribution, push notifications and an Apple Watch companion are not implemented.
- Health treats Apple Health as the source of truth for body data; Fitr only writes completed
  sessions back as workouts.
- Clinical health records and direct third-party APIs are not used; everything arrives via HealthKit.
