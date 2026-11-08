---
sidebar_position: 6
title: Development
---

# Development

## Prerequisites

| Tool | Version | Why |
| --- | --- | --- |
| macOS | 15+ | iOS development |
| Xcode | 16+ (tested on 27.2) | Swift 5.9+ toolchain, iOS 18 SDK |
| XcodeGen | 2.40+ | Generates the Xcode project |
| Bun | 1.2+ | Server runtime, package manager, tests |
| Node | 20+ | Docusaurus build (optional if you only run the app) |

Install XcodeGen with Homebrew:

```bash
brew install xcodegen
```

## First run

```bash
git clone <repository-url> fitr
cd fitr
bun install
bun run dev:server
```

The server prints:

```text
  Fitr API  ▸  http://localhost:8787
  database  ▸  /…/apps/server/data/fitr.sqlite
  catalogue ▸  60 exercises · 164 seeded tasks
```

In a second terminal:

```bash
cd apps/ios
xcodegen generate
open Fitr.xcodeproj
```

Choose any iPhone simulator and run. The app defaults to `http://localhost:8787`; the
simulator shares the host network, so no changes are needed.

### Physical device

1. Put the iPhone and Mac on the same Wi-Fi network.
2. Find the Mac's LAN IP: `ipconfig getifaddr en0`.
3. In Fitr, open **You → Connection**, set `http://192.168.x.x:8787`, and tap **Reconnect**.
4. Accept the local-network prompt on first launch.
5. Open **Health → Connect Apple Health** to grant HealthKit access. The simulator supports
   HealthKit too, but a physical iPhone is the useful source of Watch and third-party data.

The Info.plist allows cleartext local networking for development. Do not ship that
configuration to production without TLS.

## Commands

| Command | Where | Effect |
| --- | --- | --- |
| `bun run dev:server` | root | Start Bun with file watching |
| `bun run test` | root | Server test suite |
| `bun run typecheck` | `apps/server` | TypeScript check |
| `bun run db:reset` | root | Delete DB; reseeds on next start |
| `bun run export:catalog` | root | Regenerate `apps/ios/Fitr/Resources/catalog.json` |
| `bun run dev:docs` | root | Docusaurus dev server at `/fitr/docs/` |
| `bun run --cwd apps/docs build` | root | Production docs build |
| `xcodegen generate` | `apps/ios` | Regenerate the Xcode project |
| `xcodebuild … test` | `apps/ios` | Run iOS unit tests |

## Testing

### Server

```bash
cd apps/server
NODE_ENV=test bun test
```

The suite uses an in-memory SQLite database and creates a fresh seeded app per test. Coverage:

- catalogue seeding, filters and detail;
- bootstrap shape, six time regions and week index;
- idempotent plans and increasing weekly multipliers;
- completion/reset and streak updates;
- progress periods, series, muscles and validation;
- profile updates and bounds checking.

### iOS

```bash
cd apps/ios
xcodegen generate
xcodebuild -project Fitr.xcodeproj -scheme Fitr \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  test CODE_SIGNING_ALLOWED=NO
```

If the named simulator is unavailable, list devices with `xcrun simctl list devices available`
and change the destination.

### TypeScript

```bash
cd apps/server && bun run typecheck
```

Docusaurus config is type-checked during `bun run build`.

## Environment variables

| Variable | Default | Used by |
| --- | --- | --- |
| `PORT` | `8787` | Server |
| `FITR_DB` | `apps/server/data/fitr.sqlite` | Server |
| `NODE_ENV` | — | Suppresses request logging when `test` |
| `GITHUB_REPOSITORY` | — | Docusaurus owner/project detection |
| `DOCUSAURUS_URL` | derived | Override site URL |
| `DOCUSAURUS_BASE_URL` | derived | Override base path |

No secrets are required for local development.

## Working with the catalogue

The seed file is the single source of truth:

```text
apps/server/src/db/seed-data.ts
```

After editing it:

```bash
bun run db:reset
bun run export:catalog
bun run test
```

Then rebuild the app. The export command creates a temporary database, serializes the full
catalogue exactly as the API would, and writes it to the iOS bundle. This guarantees the
offline catalogue and the API response are structurally identical.

### Adding an exercise

1. Add a `SeedExercise` to the appropriate array in `seed-data.ts`.
2. Reference existing topic, type, region and muscle IDs (the seeder throws on unknown IDs).
3. Choose an existing animation key or implement a new one (see [Animations](animations)).
4. Reset the database, export the catalogue and add a test assertion if the exercise is a new
   archetype.

## Working on the plan engine

`apps/server/src/domain/plans.ts` contains selection, prescriptions and autoregulation.
`progress.ts` contains aggregation and records. When changing either:

- update [Progression model](../product/progression);
- add a test that asserts the new invariant;
- reset the database so seeded history reflects the new rules;
- verify a full week in the app, not just the API.

## Debugging tips

### The app shows “Can’t reach your training server”

```bash
curl -s localhost:8787/api/health
```

- If curl fails, start the server.
- If curl works in the simulator but not on a device, use the LAN IP.
- Check macOS firewall prompts.
- Remember that `localhost` inside a physical iPhone means the phone itself.

### The catalogue is empty

The bundled `catalog.json` is missing or stale. Run:

```bash
bun run export:catalog
```

then rebuild the app (resources are copied at build time, not live-reloaded).

### Seed changes are not visible

`seedDatabase` only runs when the exercises table is empty. Run `bun run db:reset`. This
deletes history.

### The simulator keeps old data

The app caches the last bootstrap. The store refreshes on launch, but you can also delete the
app from the simulator or use **Device → Erase All Content and Settings**.

### Xcode does not see new files

XcodeGen adds files by directory. Run `xcodegen generate` after adding a source file if the
project was generated before the file existed.

## Code style

- TypeScript: strict mode, explicit return types on exported functions, no ORM.
- Swift: one type per file where practical, `@MainActor` on UI state, actors for I/O.
- SQL: uppercase keywords, explicit column lists, snake_case.
- Commits: Conventional Commits (`feat`, `fix`, `docs`, `chore`, `test`), one logical change.
- Docs: update the relevant page in the same commit as the behaviour change.

## Repository hygiene

- `apps/ios/Fitr.xcodeproj` is ignored; regenerate it.
- `apps/server/data/` is ignored; never commit a database.
- `catalog.json` is generated but committed, because the app must build without running the exporter.
- Screenshots are real simulator captures, compressed for the web.

## Continuous integration

`.github/workflows/ci.yml` runs three jobs:

1. **Server** — install, typecheck, test on Ubuntu with Bun.
2. **iOS** — generate project, build and test on the latest macOS runner with a simulator.
3. **Docs** — build Docusaurus to catch broken links and type errors.

Deployment is separate; see [Deployment](deployment).
