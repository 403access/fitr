---
sidebar_position: 2
title: Roadmap
---

# Roadmap

Fitr is developed as a sequence of small, shippable tasks. Each task ends with a green build,
updated documentation and a dedicated commit. This page is the live plan and the audit trail.

## Working agreement

1. **One task, one commit.** The commit message names the user-visible outcome.
2. **Tests before the next task.** Server tests and iOS build/tests must pass.
3. **Docs travel with behaviour.** No feature is “done” until its page is updated.
4. **Screenshots are re-captured** when the UI changes.
5. **Demo data stays realistic.** Every plan-affecting change is verified against a reset seed.

```bash
# the loop
bun run test
bun run --cwd apps/server typecheck
bun run export:catalog
cd apps/ios && xcodegen generate && xcodebuild … test
```

## Phase 0 — Foundation ✅

- [x] Initialise the git repository and monorepo layout.
- [x] Add root scripts, ignore rules and a product README.
- [x] Define the domain language: topics, types, regions, muscles, exercises, time regions.
- [x] Document the working agreement, product pillars and architecture direction.

**Commit:** repository initialisation (local)

## Phase 1 — Server and catalogue ✅

- [x] SQLite schema with catalogue, plans, tasks and users.
- [x] Seed 60 exercises with full anatomical metadata and coaching content.
- [x] Deterministic weekly plan generator across six time regions.
- [x] Weekly volume/intensity progression and effort-driven autoregulation.
- [x] Progress engine: totals, adherence, streaks, muscle balance, PRs and improvements.
- [x] Hono REST API with validation and JSON errors.
- [x] Demo history seeding and database reset workflow.
- [x] Tests for catalogue, plans, completion, progress and profile.

**Commit:** `1abc85f` — feat(server): Bun API with SQLite catalogue, adaptive plans and progress engine

**Verified by:** 11 passing server tests; curl smoke test of bootstrap and progress.

## Phase 2 — iOS shell and design system ✅

- [x] XcodeGen project with app and unit-test targets.
- [x] Brand palette, typography, cards, pills, rings and buttons.
- [x] Four-step onboarding with server connection test.
- [x] Floating tab bar, toast system and offline/error states.
- [x] API client actor, observable store, settings and caches.
- [x] Bundled catalogue loading.

**Commit:** included in `0114335` — feat(ios): SwiftUI app with animated figure engine, daily rhythm, catalogue and progress tracker

## Phase 3 — Motion engine ✅

- [x] Normalized 14-joint body model.
- [x] Pose library covering 41 movement keys.
- [x] Ping-pong and loop sequences with smoothstep easing.
- [x] Canvas renderer with aura, floor, ghost trail, glow, joints and sparks.
- [x] Topic tinting and arbitrary-size rendering.
- [x] Structural tests for every animation key.

**Commit:** included in `0114335`.

## Phase 4 — Daily rhythm and catalogue UI ✅

- [x] Week strip with completion bars and rest-day markers.
- [x] Hero card with week phase, ring, minutes, streak and volume lift.
- [x] Six time-region sections with task rows and one-tap status.
- [x] Exercise player with timer, steppers, set dots and effort.
- [x] Catalogue search, topic chips and faceted filter sheet.
- [x] Exercise detail with instructions, cues, benefits, muscles and equipment.

**Commit:** included in `0114335`.

## Phase 5 — Progress UI ✅

- [x] Day/week/month/year selector with range navigation.
- [x] Swift Charts training-load chart.
- [x] Month calendar heatmap with done/partial/missed/rest/future.
- [x] Improvement rows, personal records and muscle balance.
- [x] Streak card and period-over-period deltas.

**Commit:** included in `0114335`.

## Phase 6 — Documentation ✅

- [x] Docusaurus 3 site with branded theme and dark mode.
- [x] Product vision, features, progression model and design language.
- [x] Architecture, data model, API reference, iOS internals, animations and development guide.
- [x] Deployment guide for GitHub Pages and the API server.
- [x] This roadmap, decision log and changelog.

**Commit:** `d3014b3` — docs: add Docusaurus product, technology and roadmap documentation

## Phase 7 — Marketing website ✅

- [x] Responsive dark landing page with real simulator screenshots.
- [x] Feature story, day timeline, progress proof, self-hosting section and FAQ.
- [x] Accessible navigation, reduced-motion support and no tracking.
- [x] Screenshot carousel with keyboard and touch controls.

**Commit:** `2ae4103` — feat(web): add marketing site with real app screenshots

## Phase 8 — CI and deployment ✅

- [x] Server test + typecheck workflow.
- [x] iOS build + test workflow on macOS.
- [x] Docs build workflow.
- [x] Combined GitHub Pages deployment of marketing site and docs.
- [x] Deployment documentation and release checklist.

**Commit:** `abe6d28` — ci: test server, iOS and docs, then deploy both sites to GitHub Pages

## Phase 9 — Apple Health integration ✅

- [x] HealthKit entitlement, usage strings and XcodeGen configuration.
- [x] Explicit read/write permission flow with on-device privacy.
- [x] Today snapshot: steps, energy, exercise, stand, distance, flights, mindful, sleep, heart, HRV and weight.
- [x] Seven-day step series and recent workouts from every Health source.
- [x] Source-app discovery so third-party data is visible.
- [x] Overview, Trends, Workouts and Sources views.
- [x] Range filters (1D/7D/30D/90D/1Y), metric filters and workout type/source filters.
- [x] Trend charts, summaries, workout mix and Fitr-authored audit.
- [x] Export completed Fitr sessions as idempotent Health workouts.
- [x] Opt-in automatic export when a training day is complete.
- [x] Body-today strip on the Today screen.

**Commit:** local — `feat(ios): native Apple Health integration`

## Phase 10 — Next: production hardening ⏳

- [ ] Bearer-token auth with per-user data scoping.
- [ ] TLS-only configuration and removal of the ATS exception.
- [ ] SQLite backup and restore script.
- [ ] Rate limiting and request IDs.
- [ ] Environment-gated demo seeding.
- [ ] Rename or version the demo user flow.
- [ ] Structured logging and an uptime check.

## Phase 11 — Adaptive coaching ⏳

- [ ] Opt-in deload every 4–8 weeks with a visible recovery week.
- [ ] Readiness check-in using Health sleep, HRV and resting heart rate.
- [ ] Missed-session redistribution instead of permanent loss.
- [ ] Exercise substitution when equipment is unavailable.
- [ ] Per-exercise preferences (favourites, avoid, cues).
- [ ] Distance/pace targets for cardio, not only duration.
- [ ] Bodyweight-normalised volume and relative strength.

## Phase 12 — Deeper tracking ⏳

- [ ] Session grouping (“workout” entity) instead of day-level sessions.
- [ ] Per-set logging with rest timers.
- [ ] Export to CSV and JSON.
- [ ] Lock Screen Live Activity for holds.
- [ ] Shareable progress card (image export).

## Phase 13 — Catalogue and motion ⏳

- [ ] Body map that highlights primary and auxiliary muscles spatially.
- [ ] More movement archetypes: Turkish get-up, snatch, muscle-up, clean.
- [ ] Reduced-motion static poses.
- [ ] Form annotations over the animated figure.
- [ ] Localisation (EN/DE) and unit preferences (kg/lb).
- [ ] Dynamic Type tokens across all screens.

## Phase 14 — Platform ⏳

- [ ] Multi-user accounts and device sync.
- [ ] Server-side migrations with versioned history.
- [ ] PostgreSQL option for multi-user deployments.
- [ ] TestFlight distribution and App Store assets.
- [ ] Widgets: today ring and next task.
- [ ] Apple Watch companion for timers and set logging.

## Completed commit trail

| Commit | Outcome |
| --- | --- |
| `1abc85f` | Server, catalogue, plans, progress engine and tests |
| `0114335` | SwiftUI app, animations, daily rhythm, catalogue and tracker |
| `d3014b3` | Docusaurus product, technology and roadmap documentation |
| `2ae4103` | Marketing website with real simulator screenshots |
| `abe6d28` | CI for server, iOS and docs plus combined GitHub Pages deployment |

This table is updated as each phase lands. The git history is the authoritative log; this page
is the human-readable plan behind it.
