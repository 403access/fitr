---
sidebar_position: 4
title: iOS app
---

# iOS app

The client is a SwiftUI application targeting iOS 18+, built with XcodeGen from a single
`project.yml`. It deliberately has no third-party dependencies.

## Project generation

```bash
cd apps/ios
xcodegen generate
open Fitr.xcodeproj
```

`Fitr.xcodeproj` is git-ignored. `project.yml` is the source of truth for targets, resources,
Info.plist entries and the test scheme. The generated `Info.plist` is committed for convenience
but is recreated on every generation.

## Source layout

```text
Fitr/
  App/
    FitrApp.swift             @main, environment injection
    RootView.swift            tab shell, floating tab bar, toast
    OnboardingView.swift      4-step first-run flow
    AppConfig.swift           documentation and website links
  DesignSystem/
    Theme.swift               palette, typography, card modifiers
    Components.swift          rings, pills, buttons, flow layout, states
  Models/
    Models.swift              all Codable domain models
    HealthModels.swift        normalized health snapshot and formatting
  Services/
    APIClient.swift           actor-based URLSession client
    AppStore.swift            @MainActor @Observable app state
    AppSettings.swift         UserDefaults-backed settings
    HealthStore.swift         HealthKit reads, workout routes, permissions and export
    RouteRecorder.swift       opt-in Core Location trail and local route archive
    LocalStore.swift          bootstrap cache + bundled catalogue
    FitrDate.swift            calendar, formatting, deltas
  Features/
    Today/                    week strip, hero, time regions, task rows, health pulse
    Player/                   exercise logging sheet and timer
    Catalogue/                filters, grid, detail sheet
    Progress/                 summary, chart, calendar, PRs, muscles
    Health/                   permission flow, rings, metrics, chart, workouts, sources
    Profile/                  settings, connection, program, about
  Animation/
    BodyPose.swift            14-joint skeleton and pose library
    ExerciseMotion.swift      keyframes, durations, loop modes
    AnimatedExerciseFigure.swift  Canvas renderer and thumbnail
  Resources/
    catalog.json              generated catalogue snapshot
    Assets.xcassets           accent, launch color, app icon
```

## State management

`AppStore` is the single source of truth:

```swift
@MainActor @Observable final class AppStore {
  let health: HealthStore
  private(set) var bootstrap: Bootstrap?
  private(set) var progress: ProgressSummary?
  var selectedDate: Date
  var progressPeriod: TrainingPeriod
  var isLoading: Bool
  var isOffline: Bool
  var errorMessage: String?
  ...
}
```

It is injected once at the root with `.environment(store)` and read by views with
`@Environment(AppStore.self)`. Views never construct API clients directly. Mutations flow
through the store so caching, toasts, haptics and error handling stay consistent.

### Why @Observable and not ObservableObject?

- Finer-grained dependency tracking in SwiftUI.
- No `@Published` boilerplate.
- Works with `@Environment` and `@Bindable`.
- The app targets iOS 18, so no back-deployment constraint.

### Concurrency

- `AppStore` is `@MainActor`; UI state is never touched off the main thread.
- `APIClient` is an `actor`; requests and decoding are isolated.
- Each mutation awaits the actor, then updates the store and triggers a silent refresh.
- No unstructured tasks mutate view state without inheriting the main actor.

## Networking

`APIClient` wraps `URLSession` with:

- a configurable base URL from settings;
- 12 s request timeout / 20 s resource timeout;
- JSON encoder/decoder with server-camelCase keys;
- typed errors (`invalidURL`, `transport`, `server`, `decoding`);
- a `health()` call used by the connection tester.

Endpoints map one-to-one to the [API reference](api). The bootstrap is the primary read; other
calls are mutations and progress reads.

## Offline and caching

There are two independent layers:

1. **Bundled catalogue** — `catalog.json` is copied into the app bundle and decoded at startup.
   Explore, exercise detail and all animations work with no server.
2. **Bootstrap cache** — the last successful payload is written to
   `Application Support/Fitr/bootstrap.json`. On launch it is restored before the network
   request, so the app opens to yesterday’s plan instead of a spinner.

The cache is replaced only on success. A failed fetch shows an inline banner and keeps the
cached plan visible.

## HealthKit

`HealthStore` is an `@MainActor @Observable` service owned by `AppStore`. It wraps one
`HKHealthStore` and exposes a normalized `HealthSnapshot` so views never handle framework
objects or query results.

- **Permission** — `requestAccess()` asks for read access to activity, sleep, heart, HRV,
  energy and body mass, plus write access to workouts and active energy. The sheet is only
  shown when the user taps **Connect Apple Health**.
- **Reads** — statistics queries sum daily quantities and average discrete values; sample
  queries read the latest heart and weight values; collection queries build daily series for
  trends; a workout query supplies activity type, duration, energy, distance and source app;
  a source query lists the apps contributing step samples.
- **Analysis** — `loadAnalysis(range:)` builds a multi-metric daily series for 1D/7D/30D/90D/1Y,
  caches each range, and powers the Trends, Workouts and Sources views without re-querying on
  every tab switch.
- **Routes** — iOS does not expose a system-wide location history. `loadRoutes(range:)` reads
  `HKWorkoutRoute` samples for workouts in the range with `HKWorkoutRouteQuery`, merges them
  with trails from `RouteRecorder`, and caches the imported HealthKit portion per range.
  HealthKit route import is limited to the most recent 12–300 workouts depending on the range.
- **Local recording** — `RouteRecorder` is an `@MainActor @Observable`
  `CLLocationManagerDelegate`. When the user opts in, it samples roughly every 30 metres,
  splits trails after a 15-minute pause, and writes `routes.json` to Application Support.
  Location “Always”, `NSLocationAlwaysAndWhenInUseUsageDescription` and the `location`
  background mode are required for all-day coverage. Trails are pruned after 400 days and
  never uploaded.
- **Sleep** — category samples from multiple apps are merged by interval before summing, so
  overlapping records are never double counted. Sleep is attributed to the wake-up day.
- **Write** — a completed day is saved with `HKWorkoutBuilder` as a single workout, with a
  conservative active-energy estimate and stable `HKMetadataKeyExternalUUID`. Exported dates
  are stored in `UserDefaults` to keep the operation idempotent.
- **Audit** — the Sources view reports Fitr-authored workouts in the selected range. Reading
  Health never writes; only the explicit export path does.
- **Privacy** — samples and GPS points stay on the device. Permissions, exported-date markers
  and the route archive are persisted locally; nothing health- or location-related is sent to
  the Bun API.

The HealthKit entitlement lives in `Fitr/Fitr.entitlements` and is referenced by `project.yml`.
Health read/write, location when-in-use and location-always usage strings are generated into
`Info.plist`; the `location` background mode is declared there too.

## Screens

### Today

- Greeting, name and streak avatar.
- Week strip with completion bars and rest-day moons.
- Hero card: week index, phase, volume lift, completion ring, minutes, streak, weekly totals.
- Body-today strip with steps, sleep, resting heart rate and active energy when Health is connected.
- Six time-region sections, each with icon, hint, minutes and completed count.
- Task rows with animated thumbnails, target, duration and a one-tap status toggle.
- Pull to refresh; date and week navigation; rest-day callout.

### Health

A dedicated tab with five views:

- **Overview** — connection state, nested move/exercise/stand rings, today's metric grid,
  seven-day steps, recent workouts, source chips and export card.
- **Trends** — range picker (1D/7D/30D/90D/1Y), metric picker across eleven metrics, summary card
  with total/average, best and latest, daily line or bar chart, average rule and workout mix
  donut.
- **Workouts** — range, activity-type and source filters; count/minutes/energy summary;
  workout-minutes chart; session list.
- **Routes** — imported workout GPS on an interactive map, range totals, a day-grouped route
  list and the opt-in local recorder. Explains the HealthKit limitation and never uploads.
- **Sources** — source rows with workout counts, a "What Fitr reads" grid and a Fitr-authored
  data audit.
- **Export** — manual or automatic write-back of a completed Fitr day as one workout.
- **Privacy** — all views carry the on-device privacy note.

### Player

A large sheet with the animated figure and the full coaching content. It includes a timer for
holds, a minute stepper for long cardio, load/reps steppers, set dots, effort selection and a
sticky complete/skip bar.

### Explore

Client-side search and faceted filters over the bundled catalogue, a two-column grid, and a
detail sheet with instructions, cues, benefits, breathing, equipment, regions and muscles.

### Progress

Period selector, range navigation, consistency hero, metric tiles, Swift Charts bar chart,
month heatmap, proof-of-progress rows, PRs, muscle balance and streak.

### You

Identity, focus, experience, weekly rhythm sliders, equipment, connection, program summary and
links. Profile edits are validated server-side and affect future weeks.

### Onboarding

Four steps: welcome and name, goal, rhythm (days/minutes), server connection with a live health
test. The chosen values are persisted to the server, then the main shell appears.

## Design system

`Theme` defines colors, gradients and typography factories. `Components` provides:

- `FitrBackground` — layered radial gradients.
- `ProgressRing` — animated angular-gradient trim.
- `FitrPill`, `DeltaBadge`, `MetricTile`.
- `SectionHeading`, `EmptyPanel`, `ErrorBanner`.
- `FlowLayout` — a custom `Layout` for wrapping chips.
- `FitrPrimaryButtonStyle`.
- Toast and floating tab bar.

No screenshot assets are used inside the app.

## Accessibility and platform behaviour

- Preferred color scheme is dark; Info.plist forces dark mode.
- The app supports iPhone and iPad layouts, portrait-first on iPhone.
- SF Symbols are used for all iconography.
- Haptics: soft impact for selection, light for sets, success/error notifications for network actions.
- Pull-to-refresh and context menus provide alternate interaction paths.
- VoiceOver labels exist for icon-only buttons; Canvas art is hidden.

## Debug screenshot hooks

For repeatable marketing screenshots, debug builds read environment variables:

| Variable | Effect |
| --- | --- |
| `FITR_TAB=today\|catalogue\|progress\|health\|profile` | Selects the initial tab |
| `FITR_HEALTH_SECTION=overview\|trends\|workouts\|routes\|sources` | Selects the initial Health section |
| `FITR_PLAYER=1` | Opens the first pending morning task |
| `FITR_EXERCISE=1` | Opens the barbell back squat detail |

```bash
SIMCTL_CHILD_FITR_TAB=progress \
SIMCTL_CHILD_FITR_PLAYER=1 \
xcrun simctl launch --terminate-running-process "iPhone 16 Pro" me.olimo.fitr
```

These hooks are wrapped in `#if DEBUG` and have no effect in release builds.

## Tests

`FitrTests` runs on the simulator and covers:

- date key round-trips and Monday week starts;
- duration, delta and weight formatting;
- decoding a bootstrap payload;
- merging overlapping sleep intervals without double counting;
- Health session MET mapping by exercise topic;
- Health trend summaries and workout/category/source filters;
- GPS route distance, duration and local-route mapping;
- every animation key has at least two poses and actual joint movement.

```bash
xcodebuild -project Fitr.xcodeproj -scheme Fitr \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  test CODE_SIGNING_ALLOWED=NO
```

## Known technical debt

- Fixed type sizes instead of Dynamic Type tokens.
- No SwiftData persistence for task mutations made offline.
- Catalogue and server must be re-synced manually after seed changes (`bun run export:catalog`).
- `Info.plist` is generated but committed; a regeneration can change it.
- No snapshot tests; the Canvas engine is tested structurally, not pixel-wise.
