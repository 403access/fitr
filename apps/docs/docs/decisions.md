---
sidebar_position: 3
title: Decisions
---

# Decision log

Lightweight architecture decision records. New decisions append; superseded decisions keep
their history.

## ADR-001 — SQLite as the only datastore

**Status:** accepted (v0.1)

**Context.** Fitr is personal software. The data volume is tiny (one user, hundreds of tasks
per year). The deployment target is a single Bun process on a laptop, VPS or home server.

**Decision.** Use SQLite via `bun:sqlite`, with WAL mode, foreign keys and an idempotent schema
applied at startup. No ORM.

**Consequences.** Zero operational overhead, trivial backup, excellent read performance and
portable tests with `:memory:`. The model does not scale horizontally and requires care for
multi-user writes. A future Postgres adapter is possible because all access is behind domain
functions.

## ADR-002 — Bun + Hono instead of Node + Express

**Status:** accepted (v0.1)

**Context.** The server is small, TypeScript-first and must be easy to run and test.

**Decision.** Bun as runtime and package manager; Hono as the router; zod for validation.

**Consequences.** Fast startup, native SQLite, built-in test runner, and a tiny API surface.
The ecosystem is younger than Node’s, and some hosting platforms assume Node. The Docker
image and platform guides cover Bun explicitly.

## ADR-003 — Server-authoritative plan generation

**Status:** accepted (v0.1)

**Context.** Plans must be consistent across devices and the progression rules must be
auditable and testable.

**Decision.** The server generates and stores plans. The client renders them and submits
actuals. The client never generates a plan, including in demo mode.

**Consequences.** One source of truth and easy testing of progression. Logging requires
connectivity. Future offline writes will need an outbox with idempotency keys.

## ADR-004 — Bundled catalogue for offline browsing

**Status:** accepted (v0.1)

**Context.** Exercise browsing and animations should work before the first successful request,
and the catalogue changes rarely compared with plans.

**Decision.** Export the seeded catalogue to `catalog.json` at build time and bundle it in the
iOS app. The server remains the source of truth; the export is a build artifact.

**Consequences.** Instant Explore, offline detail, and identical animation keys. Catalogue
changes require a re-export and app rebuild. A stale bundle can diverge from the server, which
is acceptable for read-only reference data.

## ADR-005 — Procedural Canvas animations

**Status:** accepted (v0.1)

**Context.** The brief requires every exercise to be visualized and animated beautifully, with
no budget for filming 60 movements.

**Decision.** Represent each exercise as keyframed normalized joint positions and render with
SwiftUI Canvas. 41 sequence keys cover 60 exercises through reuse.

**Consequences.** Zero asset weight, infinite resolution and topic tinting. The motion is
stylized rather than photorealistic, and new archetypes require hand-authored poses. The
skeleton also enables future form annotations.

## ADR-006 — Single-user header identity for v0.1

**Status:** accepted, temporary

**Context.** Building auth, sessions, invites and account recovery would delay validating the
training loop.

**Decision.** Default to user `me`; allow `x-user-id` to select another demo user; auto-create
unknown users.

**Consequences.** No security boundary. The server must not be exposed publicly without auth.
Documented in the roadmap as production hardening.

## ADR-007 — Combined GitHub Pages deployment

**Status:** accepted (v0.1)

**Context.** The marketing site and docs are separate builds, but GitHub Pages provides one
site per repository (or one custom domain).

**Decision.** Assemble a single artifact: marketing at `/`, docs at `/docs/`. One workflow,
one deployment.

**Consequences.** Atomic releases and one URL to share. Docusaurus must be built with the
correct `baseUrl`; the config derives it from `GITHUB_REPOSITORY`. A custom domain can be added
with a CNAME and two environment overrides.

## ADR-008 — No automatic deload in the first release

**Status:** accepted, revisit in Phase 10

**Context.** The product brief says tasks every week must get harder. Conventional training
theory recommends periodic deloads.

**Decision.** Progress every week, with autoregulation preventing extra load when effort is
high. No automatic deload yet.

**Consequences.** Strictly satisfies the brief and remains safe for intermediate users because
load only increases in 2.5 kg steps and holds cap at 1.6× baseline. A configurable deload will
be added as an explicit opt-in, never silently.

## ADR-009 — Screenshots from the simulator, not mockups

**Status:** accepted (v0.1)

**Context.** Marketing and docs need authentic product imagery.

**Decision.** Capture real iPhone 16 Pro simulator screenshots using debug-only launch hooks,
then compress them for the web. No fabricated UI.

**Consequences.** The site always reflects the real app. Screenshots must be regenerated when
the UI changes; the debug hooks are documented and compiled out of release builds.

## ADR-010 — Health data stays on the device

**Status:** accepted (v0.2)

**Context.** Fitr can show activity, sleep, heart and workout data from Apple Health, including
third-party apps. Health data is highly sensitive and already synced by Apple.

**Decision.** Integrate through HealthKit on the iPhone only. Normalize samples into a local
snapshot, never upload them to the Fitr API, and keep the server authoritative only for plans,
tasks and training progress. Write-back is limited to completed sessions as workouts.

**Consequences.** Strong privacy and no new server storage or migration. Cross-device health
history is not available in Fitr itself, and readiness-based coaching needs the phone to read
Health first. Clinical records and direct third-party APIs are deliberately out of scope.
