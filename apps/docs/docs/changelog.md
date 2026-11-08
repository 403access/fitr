---
sidebar_position: 4
title: Changelog
---

# Changelog

All notable changes to Fitr. The format follows [Keep a Changelog](https://keepachangelog.com)
and the project follows [Semantic Versioning](https://semver.org).

## [Unreleased]

### Added

#### Apple Health

- Native HealthKit integration with the `com.apple.developer.healthkit` entitlement and
  generated read/write usage descriptions.
- Explicit permission flow that never prompts on cold launch.
- Today snapshot for steps, active energy, exercise minutes, stand hours, distance, flights,
  mindful minutes, sleep, resting heart rate, heart rate, HRV and body weight.
- Seven-day step chart and recent workouts from Apple Health, including third-party source apps.
- Source discovery for apps and devices contributing to Health.
- One-tap and optional automatic export of completed Fitr days as idempotent Health workouts.
- Body-today strip on the Today screen.
- New Health tab with rings, metrics, workouts, sources and privacy notes.
- Health views for Overview, Trends, Workouts, Routes and Sources.
- Range filters for 1D/7D/30D/90D/1Y and metric filters across eleven Health metrics.
- Daily trend charts, averages, best/latest values and workout-mix visualisation.
- Workout filters by activity type and source app, with count/minutes/energy summaries.
- Routes view with an interactive MapKit map of GPS routes from Apple Health workouts,
  range totals and a day-grouped route list.
- Opt-in Core Location recording for continuous day-long movement history, stored only on the
  device and pruned after 400 days. iOS has no system-wide location history, so workout routes
  are imported and all-day trails are recorded locally.
- Source breakdown and a Fitr-authored data audit confirming Fitr has not modified Health.
- Unit tests for overlapping sleep intervals, Health session energy mapping and route metrics.
- HealthKit setup, location permissions, privacy and capability documentation.

#### iOS

- A section drawer on the You tab groups Profile, Training, Connection, Program and About
  behind one header gesture, with a scrim, close drag and modal accessibility traits.

#### Website and docs

- Marketing site refreshed with the Health tab, GPS routes, the You drawer, new simulator
  screenshots and FAQ answers about HealthKit and location privacy.
- Docs now cover route import, local GPS recording, location permissions, the You drawer and
  the updated architecture.

## [0.1.0] — 2026-11-08

The first complete vertical slice: a self-hosted training system with a native iOS client,
procedural animations, adaptive weekly plans, a progress engine, documentation and a marketing
site.

### Added

#### Catalogue

- 60 exercises across strength, calisthenics, yoga, mobility, cardio and recovery.
- 6 topics, 8 exercise types, 15 body regions and 29 muscles with primary/auxiliary roles.
- Coaching content for every exercise: instructions, cues, benefits, breathing and equipment.
- Faceted search and filtering in the app, working offline from a bundled snapshot.
- Exercise detail with animated figure and muscle breakdown.

#### Training

- Six time regions per day: after wake, morning, midday, afternoon, evening, before sleep.
- Deterministic weekly plan generation based on goal, experience, equipment, days and minutes.
- Recovery days with intentional low-load work.
- Weekly volume (+6%/week, capped +80%) and intensity (+4%/week, capped +50%) progression.
- Autoregulation: +2.5 kg load or +2 reps after a completed exercise at average effort ≤ 7.
- Time-aware hold progression and per-exercise rest targets.
- Task completion, skipping and reset with actuals and perceived effort.

#### Progress

- Day, week, month and year analysis.
- Adherence, minutes, volume, active days, sessions and streak.
- Calendar heatmap with done, partial, missed, rest and future states.
- Swift Charts training-load chart with monthly aggregation for year view.
- Muscle balance from primary muscle work.
- Personal records using Epley e1RM, rep totals and hold totals.
- Period-over-period improvement deltas.

#### iOS

- SwiftUI app for iOS 18+ with custom design system and floating tab bar.
- 41 hand-keyframed Canvas animations covering all 60 exercises.
- Exercise player with hold timer, load/reps steppers, set tracking and effort selector.
- Onboarding with goal, rhythm and server connection test.
- Profile editing with server validation and connection diagnostics.
- Bootstrap cache for instant launches; inline offline/error recovery.
- Haptics, pull-to-refresh, context menus and accessibility labels.
- Unit tests for dates, formatting, decoding and animation movement.

#### Server

- Bun + Hono TypeScript API with zod validation and JSON error envelopes.
- SQLite schema with WAL, foreign keys, indexes and idempotent startup migration.
- Seeded demo history: three completed weeks plus the current week to yesterday.
- Catalogue, bootstrap, tasks, plans, progress and profile endpoints.
- In-memory test suite covering the domain and HTTP layer.
- Catalogue export to the iOS bundle.

#### Documentation and web

- Docusaurus 3 documentation: vision, features, progression, design, architecture, data model,
  API, iOS internals, animations, development, deployment, roadmap, decisions and changelog.
- Dark branded marketing site with real simulator screenshots and an accessible carousel.
- GitHub Actions CI for server, iOS and docs.
- One GitHub Pages workflow that publishes marketing at `/` and docs at `/docs/`.

### Known limitations

- Single-user identity (`x-user-id`) with no authentication.
- No offline writes; logging requires the server.
- No automatic deload; opt-in planned.
- Time zones are server-local rather than per user.
- iOS screenshots are simulator captures; no snapshot tests.
- The app is not distributed via the App Store.

### Commit trail

| Commit | Summary |
| --- | --- |
| `1abc85f` | Server, catalogue, adaptive plans and progress engine |
| `0114335` | iOS app, animation engine, daily rhythm and tracker |
| `d3014b3` | Docusaurus product, technology and roadmap documentation |
| `2ae4103` | Marketing website with real simulator screenshots |
| `abe6d28` | CI and combined GitHub Pages deployment |

## Unreleased

### Planned

- Authentication and production hardening.
- Opt-in deload and readiness check-ins.
- Per-set logging and rest timers.
- Body map and form annotations.
- Apple Health and Live Activities.
- Localisation and unit preferences.
