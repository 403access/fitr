# Fitr

**Train on your rhythm.** Fitr is a personal fitness operating system: a curated exercise
catalogue, a day plan that adapts to your energy across six time regions, and progress
tracking that proves you are getting better — week after week.

```
apps/
  ios/      SwiftUI app (iOS 18+)
  server/   Bun + TypeScript API, SQLite storage
  docs/     Docusaurus product, technology and roadmap documentation
  web/      Marketing website (deployed with the docs on GitHub Pages)
```

## Quick start

```bash
# 1. API + database (seeds ~50 exercises on first run)
bun install
bun run dev:server          # http://localhost:8787

# 2. iOS app
cd apps/ios
xcodegen generate
open Fitr.xcodeproj         # run on any iPhone simulator

# 3. Documentation
bun run dev:docs            # http://localhost:3000/fitr/

# 4. Marketing site (static)
cd apps/web && bun run serve
```

The iOS app defaults to `http://localhost:8787`. Change the server URL at any time in
**You → Connection** — including on a physical device, where you should use your Mac's
LAN IP.

## What is implemented

- **Catalogue** of exercises with topic, type, body region, primary and auxiliary muscles,
  difficulty, equipment, coaching cues, breathing and a hand-authored vector animation
  for every exercise.
- **Today plan** grouped by time region: wake, morning, midday, afternoon, evening and
  before sleep. Each week is generated from your goal and your previous performance.
- **Progressive overload**: volume and load targets rise week over week, with automatic
  load bumps when you finish all prescribed reps at a sustainable effort.
- **Tracker** with day, week, month and year views; calendar heatmap, adherence, volume,
  time, muscle balance, streaks, personal records and improvement deltas against the
  previous period.
- **Beautiful motion** — no video assets, just a Canvas-rendered body figure with eased
  keyframe poses, gradients and motion trails. Works offline and at any size.
- Bun API with SQLite, deterministic plan generation, tests and OpenAPI-ish documentation.

## Documentation

- Live docs (after GitHub Pages deploy): `https://<owner>.github.io/fitr/docs/`
- Live site: `https://<owner>.github.io/fitr/`
- Source: [`apps/docs`](apps/docs), [`apps/web`](apps/web)

## Deployment

Both the marketing site and docs deploy together through GitHub Pages:
`.github/workflows/deploy-pages.yml` builds Docusaurus into `/docs` and publishes the
static marketing site at the root.

## License

Private project. All rights reserved.
