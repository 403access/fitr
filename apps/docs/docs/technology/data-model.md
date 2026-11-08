---
sidebar_position: 2
title: Data model
---

# Data model

Fitr’s database is a single SQLite file. The schema is in
`apps/server/src/db/schema.sql` and is applied idempotently at startup. Foreign keys are on and
the journal mode is WAL.

## Entity relationships

```text
users ──< plans ──< tasks >── exercises >── topics
  │                              │  │
  │                              │  └──< exercise_types
  │                              ├──< exercise_regions >── regions
  │                              └──< exercise_muscles >── muscles >── regions
  │
  └── (program_start drives week index)

tasks >── exercises
tasks ──< nothing; progress is derived
```

- A **plan** belongs to one user and one Monday-based week.
- A **task** belongs to a plan, a user and an exercise; it stores the prescription as a snapshot.
- An **exercise** has one topic, one type, many regions and many muscle links with a role.
- **Progress** is never stored; it is derived from tasks.

## Users

```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  goal TEXT NOT NULL DEFAULT 'balanced',
  experience TEXT NOT NULL DEFAULT 'intermediate',
  days_per_week INTEGER NOT NULL DEFAULT 5,
  session_minutes INTEGER NOT NULL DEFAULT 45,
  equipment TEXT NOT NULL DEFAULT '[]',
  program_start TEXT NOT NULL,
  created_at TEXT NOT NULL
);
```

`equipment` is a JSON array of equipment names. An empty array means “unrestricted” (a fully
equipped gym); otherwise every required item must be present for an exercise to be selected.

## Catalogue

| Table | Purpose | Key columns |
| --- | --- | --- |
| `topics` | Disciplines | `id`, `name`, `accent`, `icon`, `description` |
| `exercise_types` | Movement types | `id`, `name`, `description` |
| `regions` | Body regions with display order | `id`, `name`, `sort_order` |
| `muscles` | Muscles, linked to a region | `id`, `name`, `region_id`, `sort_order` |
| `exercises` | Movement definitions and defaults | `slug`, `topic_id`, `type_id`, `difficulty`, `animation`, JSON arrays, default prescription |
| `exercise_regions` | Many-to-many regions | `(exercise_id, region_id)` |
| `exercise_muscles` | Many-to-many muscles with role | `(exercise_id, muscle_id, role)` |

### Exercise defaults

```sql
default_sets INTEGER NOT NULL DEFAULT 2,
default_reps INTEGER,
default_hold_seconds INTEGER,
default_load_kg REAL,
rest_seconds INTEGER NOT NULL DEFAULT 45
```

These are **catalogue baselines**, not prescriptions. The planner applies the week multipliers
and autoregulation to produce the task-level prescription.

### Muscle roles

The `exercise_muscles.role` column is constrained to `primary` or `secondary`, and is part of
the primary key. This allows the same muscle to appear once in each role for an exercise, and
makes “show primary muscles only” a cheap join.

### Identity

- Exercise primary key: `ex-<slug>`.
- Public identifier: `slug` (used by API routes, docs, tests and the animation mapping).
- A stable slug is a compatibility contract. Renaming a slug requires a data migration.

## Plans and tasks

```sql
CREATE TABLE plans (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  week_start TEXT NOT NULL,          -- Monday, YYYY-MM-DD
  week_index INTEGER NOT NULL,
  focus TEXT NOT NULL,               -- Foundation / Build / Capacity / Peak
  volume_multiplier REAL NOT NULL,
  intensity_multiplier REAL NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE (user_id, week_start)
);
```

A plan ID is deterministic: `plan-<userId>-<weekStart>`. The unique constraint plus
`ensurePlan` makes bootstrap idempotent.

```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  plan_id TEXT NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id),
  date TEXT NOT NULL,                -- YYYY-MM-DD
  time_region TEXT NOT NULL,         -- wake | morning | midday | afternoon | evening | pre_sleep
  order_index INTEGER NOT NULL,
  exercise_id TEXT NOT NULL REFERENCES exercises(id),
  sets INTEGER NOT NULL,
  reps INTEGER,
  hold_seconds INTEGER,
  rest_seconds INTEGER NOT NULL,
  load_kg REAL,
  duration_minutes REAL NOT NULL,
  target_note TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',  -- pending | done | skipped
  completed_at TEXT,
  actual_reps INTEGER,
  actual_hold_seconds INTEGER,
  actual_load_kg REAL,
  effort INTEGER,                    -- 1–10
  created_at TEXT NOT NULL
);
```

### Why snapshot the prescription?

If the catalogue defaults or progression constants change, historical tasks must not be
rewritten. Storing `sets`, `reps`, `hold_seconds`, `load_kg`, `rest_seconds` and
`target_note` per task preserves the exact prescription the user saw. Actuals are separate,
so adherence and performance can be compared precisely.

### Indexes

```sql
CREATE INDEX idx_tasks_date ON tasks (user_id, date);
CREATE INDEX idx_tasks_plan ON tasks (plan_id);
CREATE INDEX idx_tasks_exercise ON tasks (user_id, exercise_id);
CREATE INDEX idx_tasks_completed ON tasks (user_id, completed_at);
```

The progress engine filters by `user_id` + date range and by `user_id` + exercise, so these
cover the hot paths.

## Time regions

The set is fixed in `seed-data.ts` and exposed through the API:

| ID | Label | Intent |
| --- | --- | --- |
| `wake` | After wake | Mobility before the day starts |
| `morning` | Morning | Main quality block |
| `midday` | Midday | Reset posture and focus |
| `afternoon` | Afternoon | Second quality block |
| `evening` | Evening | Flow, cardio, decompress |
| `pre_sleep` | Before sleep | Downshift and recover |

## Dates and time zones

- All calendar dates are stored as `YYYY-MM-DD` in the server’s local time zone.
- The client sends the date it is displaying; the server does not infer time zones.
- `startOfWeek` is Monday-based.
- Timestamps (`created_at`, `completed_at`) are ISO 8601 UTC strings.
- The demo seed uses plausible local completion times (06:45, 08:15, …) for chart realism.

For a multi-time-zone future, the user should store an IANA time zone and dates should be
computed per user.

## Seeding

`seedDatabase` runs only when the `exercises` table is empty. It:

1. Inserts topics, types, regions and muscles.
2. Inserts the 60 exercises and their region/muscle links, validating every reference.
3. Ensures the `me` user with a program start three weeks ago.
4. Generates three completed weeks plus the current week.
5. Marks past tasks done or skipped deterministically; leaves today and future pending.

The result is a realistic progress baseline without external fixtures.

## Resetting

```bash
bun run db:reset   # removes .sqlite, -wal and -shm
bun run dev:server # recreates and reseeds
```

The database lives at `apps/server/data/fitr.sqlite` by default. Override with `FITR_DB`.

## Production considerations

- SQLite is ideal for one user or a small household. For multi-user SaaS, move to Postgres
  or use a hosted SQLite with a single writer.
- Back up by checkpointing WAL and copying the file, or use `sqlite3 .backup`.
- Consider a migration tool (e.g. `drizzle-kit` or `node-pg-migrate`-style) once schema changes
  must preserve real history. Today the schema is created idempotently for a fresh database.
- Add `updated_at` and soft deletes when multi-device sync is introduced.
