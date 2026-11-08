---
sidebar_position: 1
title: Architecture
---

# Architecture

Fitr is a small, legible system: one native client, one API, one database, two static sites.
There is no message bus, no container orchestration and no third-party backend.

## System overview

```text
┌─────────────────────────────────────────────────────────────────────┐
│                            iOS app (SwiftUI)                        │
│                                                                     │
│  AppStore (@Observable, @MainActor)                                 │
│    ├── APIClient (actor)  ── URLSession ──▶ Bun API                 │
│    ├── BootstrapCache     ── Application Support JSON               │
│    ├── CatalogStore       ── bundled catalog.json                   │
│    ├── HealthStore        ── HealthKit (on-device only)             │
│    ├── RouteRecorder      ── Core Location + local route archive    │
│    └── Views / Canvas animation engine                              │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                    HTTP + JSON (localhost or LAN)
                                  │
┌─────────────────────────────────────────────────────────────────────┐
│                         Bun server (TypeScript)                     │
│                                                                     │
│  Hono app                                                           │
│    ├── routes: bootstrap, catalogue, tasks, plans, progress, profile│
│    ├── domain: planner, progress engine, catalogue serializers       │
│    ├── validation: zod                                               │
│    └── SQLite (bun:sqlite, WAL)                                     │
└─────────────────────────────────────────────────────────────────────┘

On-device only:
┌────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│ HealthKit      │◀────▶│ HealthStore      │◀────▶│ RouteRecorder    │
│ Apple Health   │      │ read/write       │      │ Core Location    │
└────────────────┘      └──────────────────┘      └──────────────────┘
                                                          │
                                                  routes.json (local)

Static delivery:
┌───────────────┐      ┌────────────────────┐      ┌──────────────────┐
│ marketing web │      │ Docusaurus docs    │      │ GitHub Pages     │
│ apps/web      │─────▶│ apps/docs          │─────▶│ /fitr/ + /docs/  │
└───────────────┘      └────────────────────┘      └──────────────────┘
```

## Responsibilities

### iOS app

- Renders the catalogue, daily rhythm, player, progress and health views.
- Owns interaction state, haptics and navigation.
- Caches the last bootstrap for instant launch and offline reads.
- Bundles the catalogue snapshot so Explore and animations work without a server.
- Reads and writes HealthKit data locally; samples never pass through the API.
- Imports workout GPS routes and, when opted in, records a local movement trail with Core
  Location. Route points stay in the app's archive and never reach the API.
- Does **not** compute the plan or authoritative progress. Those live on the server.

### Bun API

- Generates deterministic weekly plans from the user profile, catalogue and previous effort.
- Persists completions, skips and actuals.
- Computes adherence, streaks, volume, muscle balance, PRs and improvements.
- Serializes the catalogue with its relational metadata.
- Seeds demo history on a fresh database.

### SQLite

- Single-file database in WAL mode with foreign keys enabled.
- Schema is applied idempotently at startup from `src/db/schema.sql`.
- No ORM. Queries are explicit SQL with typed row shapes; this keeps performance predictable
  and makes the data model readable.

### Static sites

- Marketing site is hand-authored HTML/CSS/JS, no build step.
- Docusaurus builds the documentation.
- One GitHub Actions workflow assembles both into a single Pages artifact.

## Request lifecycle

### Launch

1. `AppStore.init` loads the bundled catalogue and the last cached bootstrap.
2. The root view renders immediately with cached data if present.
3. `AppStore.start()` fetches `GET /api/bootstrap` for today.
4. On success, the cache is replaced and the UI animates to fresh data.
5. On failure, the cached payload remains and an inline connection banner appears.

### Completing a task

```text
Player
  → POST /api/tasks/:id/complete { actualReps, actualLoadKg, effort }
    → completeTask() updates the row
    → buildTodayState() recomputes the day, plan and streak
  → AppStore refreshes bootstrap (silent)
  → progress cache invalidated and active period refetched
  → if the day is complete and auto-export is on, HealthStore writes one workout
  → toast + success haptic + sheet dismiss
```

The server response includes the updated task, plan and streak so the client could update
optimistically in a future iteration; today the client re-fetches the bootstrap for consistency.

### Plan generation

```text
GET /api/bootstrap?date=2026-11-05
  → validate date
  → ensurePlan(user, startOfWeek(date))
      → if absent: hash-ranked selection per slot
      → compute prescriptions with week multipliers + autoregulation
      → insert plan + tasks
  → serialize plan with exercise metadata (cached per request)
  → compute today's grouped snapshot and streak
```

## Key design decisions

| Decision | Reason | Trade-off |
| --- | --- | --- |
| SQLite via `bun:sqlite` | Zero-ops, fast, portable, perfect for single-user | Not suitable for horizontal scaling |
| Hono | Tiny, typed, works natively on Bun, standard middleware | Smaller ecosystem than Express |
| Explicit SQL | Transparent queries and schema, no ORM magic | More handwritten mapping |
| SwiftUI Canvas | Infinite resolution, tintable, no video assets | Hand-authored motion library |
| Bundled catalogue | Offline-first browsing and instant launch | Regenerate on catalogue changes |
| Server-authoritative plans | Consistent progression across devices | Requires connectivity to log |
| HealthKit on-device only | Health data is sensitive and already synced by Apple | No server-side readiness model yet |
| Local GPS archive | iOS has no all-day location history; HealthKit exposes per-workout routes only | Per-device data, extra battery when enabled |
| Single-user header | Fast MVP without auth complexity | Not multi-tenant yet |

## Data flow boundaries

- **Catalogue is duplicated deliberately:** server table → JSON export → iOS bundle. The server
  remains the source of truth; the bundle is a build artifact.
- **Plans are never generated on the client.** This prevents drift between devices and keeps
  the improvement maths verifiable.
- **Progress is derived, never stored.** There is no analytics table to go stale. Every metric is
  computed from tasks at read time. At personal scale (tens of thousands of rows) this is fast.
- **Exercise identity is stable.** IDs are `ex-<slug>` and slugs are the public contract used by
  the app and docs.
- **Health and location data do not cross the API boundary.** The iPhone reads and writes
  HealthKit locally and archives recorded routes on-device; only training plans, tasks and
  progress are server-authoritative.

## Security and operations

Current assumptions:

- Runs on localhost or a trusted LAN.
- CORS is open for local development.
- `x-user-id` selects a user; it defaults to `me` and auto-creates a demo user.
- HTTP is allowed in the app for local development.

Before exposing the API to the internet:

1. Terminate TLS (reverse proxy or platform ingress).
2. Add authentication (token or OIDC) and scope every query by the authenticated user.
3. Restrict CORS to the deployed origins.
4. Back up the SQLite file (WAL checkpoint + snapshot).
5. Disable demo seeding or gate it behind an environment flag.

These are tracked in the [roadmap](/roadmap) as the “production hardening” phase.

## Performance notes

- Bootstrap payload includes a week of tasks with full exercise metadata; the app caches it.
- Catalogue queries use `EXISTS` subqueries for region/muscle filters with indexes on the join keys.
- SQLite is opened once per process; prepared statements are reused for task inserts.
- Canvas animations pause when their task is complete and when the view is not visible.
- Progress history is small per user; day series and muscle aggregates are computed in a handful
  of grouped queries rather than N+1 calls.

## Repository layout

```text
fitr/
  apps/
    ios/       SwiftUI app, XcodeGen spec, unit tests, generated catalogue
    server/    Bun API, SQLite schema, seed, domain logic, tests
    docs/      Docusaurus site and all product/technology documentation
    web/       Marketing site and real app screenshots
  .github/workflows/
    ci.yml            server tests, iOS build/test, docs build
    deploy-pages.yml  combined marketing + docs deployment
```
