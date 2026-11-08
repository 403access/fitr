---
sidebar_position: 3
title: API reference
---

# API reference

Base URL in development: `http://localhost:8787`.

The API is JSON-only. Requests with a body must send `Content-Type: application/json`.
User selection uses `x-user-id` (optional; defaults to `me`). A missing user is created
automatically in the current single-user mode.

## Conventions

### Success responses

Resources are returned directly, not wrapped in an envelope. Lists include `count` where useful.

### Errors

```json
{
  "error": {
    "code": "invalid_date",
    "message": "Use YYYY-MM-DD."
  }
}
```

| Status | When |
| --- | --- |
| 400 | Invalid query or body validation |
| 404 | Unknown route, task, exercise or plan |
| 500 | Unhandled server error |

### Dates

All dates are `YYYY-MM-DD`. Weeks start on Monday.

## Health

### `GET /api/health`

```json
{
  "status": "ok",
  "version": "0.1.0",
  "time": "2026-11-08T10:34:28.160Z",
  "database": { "exercises": 60, "plans": 4, "tasks": 164 }
}
```

## Bootstrap

### `GET /api/bootstrap?date=YYYY-MM-DD`

Returns everything the app needs for a full first paint:

```json
{
  "user": {
    "id": "me",
    "name": "Alex",
    "goal": "balanced",
    "experience": "intermediate",
    "daysPerWeek": 5,
    "sessionMinutes": 45,
    "equipment": [],
    "programStart": "2026-10-12"
  },
  "date": "2026-11-08",
  "weekStart": "2026-11-02",
  "plan": {
    "id": "plan-me-2026-11-02",
    "weekIndex": 4,
    "focus": "Foundation",
    "volumeMultiplier": 1.18,
    "intensityMultiplier": 1.12,
    "days": [
      {
        "date": "2026-11-08",
        "isRestDay": false,
        "totalMinutes": 30,
        "completedTasks": 0,
        "totalTasks": 7,
        "tasks": [
          {
            "id": "…",
            "date": "2026-11-08",
            "timeRegion": {
              "id": "wake",
              "name": "After wake",
              "hint": "Wake the body before the day starts.",
              "icon": "sunrise.fill"
            },
            "status": "pending",
            "sets": 2,
            "reps": null,
            "holdSeconds": 45,
            "restSeconds": 15,
            "loadKg": null,
            "durationMinutes": 2.5,
            "targetNote": "2 × 45s hold",
            "exercise": { "…": "full Exercise object" }
          }
        ]
      }
    ],
    "summary": { "totalTasks": 41, "completedTasks": 31, "totalMinutes": 149.5 }
  },
  "today": {
    "date": "2026-11-08",
    "totalTasks": 7,
    "completedTasks": 0,
    "skippedTasks": 0,
    "totalMinutes": 30,
    "completedMinutes": 0,
    "adherence": 0,
    "timeRegions": [
      {
        "id": "wake",
        "name": "After wake",
        "hint": "Wake the body before the day starts.",
        "icon": "sunrise.fill",
        "tasks": [],
        "completed": 0,
        "totalMinutes": 3
      }
    ]
  },
  "streak": { "current": 27, "best": 27, "lastActive": "2026-11-07" },
  "facets": { "topics": [], "types": [], "regions": [], "muscles": [], "timeRegions": [] },
  "serverTime": "2026-11-08T10:00:00.000Z"
}
```

If no plan exists for the week containing `date`, it is generated before serialization.
The payload includes the full week; `today` is a pre-grouped view of the selected date.

## Catalogue

### `GET /api/facets`

Returns topics, types, regions, muscles (with counts) and time regions. Used by filter sheets.

### `GET /api/exercises`

| Query | Type | Example |
| --- | --- | --- |
| `topic` | string | `strength` |
| `type` | string | `stretch` |
| `region` | string | `hips` |
| `muscle` | string | `quads` |
| `q` | string | `squat` |
| `difficulty` | 1–5 | `3` |

```json
{ "exercises": [ { "id": "ex-barbell-back-squat", "slug": "barbell-back-squat", "…": "…" } ], "count": 3 }
```

Filters combine with AND. Search is case-insensitive across name and summary.

### `GET /api/exercises/:slug`

Returns one full exercise:

```json
{
  "id": "ex-barbell-back-squat",
  "slug": "barbell-back-squat",
  "name": "Barbell back squat",
  "summary": "The cornerstone lower-body lift…",
  "topic": { "id": "strength", "name": "Strength", "accent": "#C8FF4D", "icon": "dumbbell.fill" },
  "type": { "id": "strength", "name": "Strength" },
  "difficulty": 4,
  "durationSeconds": 45,
  "animation": "squat",
  "equipment": ["Barbell", "Rack"],
  "instructions": ["…"],
  "cues": ["…"],
  "benefits": ["…"],
  "breathing": "Inhale at the top…",
  "regions": [{ "id": "lower-body", "name": "Lower body" }],
  "primaryMuscles": [{ "id": "quads", "name": "Quadriceps" }],
  "secondaryMuscles": [{ "id": "hamstrings", "name": "Hamstrings" }],
  "prescription": { "sets": 4, "reps": 8, "holdSeconds": null, "loadKg": 50, "restSeconds": 120 }
}
```

### `GET /api/exercise-by-id/:id`

Convenience lookup for deep links when only the stable ID is known.

## Tasks

### `GET /api/tasks?date=YYYY-MM-DD&timeRegion=&status=`

Returns tasks for a date, optionally filtered. Ensures the week's plan exists first.

### `GET /api/tasks/:id`

Returns one serialized task.

### `POST /api/tasks/:id/complete`

```json
{
  "actualReps": 9,
  "actualHoldSeconds": null,
  "actualLoadKg": 55,
  "effort": 7
}
```

All fields are optional; omitted actuals fall back to the prescription. `effort` is clamped to
1–10. Response:

```json
{
  "task": { "…": "updated task" },
  "plan": { "…": "serialized week" },
  "streak": { "current": 28, "best": 28, "lastActive": "2026-11-08" }
}
```

### `POST /api/tasks/:id/skip`

Marks the task skipped and clears completion. Returns the same shape.

### `POST /api/tasks/:id/reset`

Returns a task to `pending` and clears all actuals and effort.

## Plans

### `GET /api/plans/current?date=YYYY-MM-DD`

Ensures and returns the plan for the week containing `date`.

### `GET /api/plans/:weekStart`

Returns an existing plan for that Monday, or 404.

## Progress

### `GET /api/progress?period=week&anchor=2026-11-08`

`period` is one of `day`, `week`, `month`, `year`. `anchor` defaults to today.

```json
{
  "period": "week",
  "anchor": "2026-11-08",
  "range": { "start": "2026-11-02", "end": "2026-11-08" },
  "previousRange": { "start": "2026-10-26", "end": "2026-11-01" },
  "totals": {
    "scheduled": 41,
    "completed": 33,
    "skipped": 2,
    "pending": 6,
    "minutes": 128.4,
    "volumeKg": 7620,
    "reps": 445,
    "holdSeconds": 1868,
    "sessions": 6,
    "adherence": 80
  },
  "previousTotals": { "…": "same shape" },
  "deltas": {
    "minutesPct": -12.4,
    "volumePct": 18.0,
    "adherencePct": -5,
    "completedPct": -13.2,
    "sessionsPct": 0
  },
  "streak": { "current": 27, "best": 27, "lastActive": "2026-11-07" },
  "days": [
    {
      "date": "2026-11-02",
      "scheduled": 7,
      "completed": 7,
      "minutes": 28.5,
      "volumeKg": 440,
      "status": "done"
    }
  ],
  "series": ["same as days for day/week/month, monthly buckets for year"],
  "muscles": [{ "id": "quads", "name": "Quadriceps", "minutes": 32.5, "share": 18.4 }],
  "prs": [
    {
      "exerciseId": "ex-barbell-back-squat",
      "name": "Barbell back squat",
      "kind": "load",
      "value": 70.5,
      "unit": "kg e1RM",
      "previous": 66.2,
      "deltaPct": 6.5,
      "achievedAt": "2026-11-06"
    }
  ],
  "improvements": [
    {
      "exerciseId": "ex-barbell-back-squat",
      "name": "Barbell back squat",
      "kind": "load",
      "current": 70.5,
      "previous": 66.2,
      "deltaPct": 6.5,
      "unit": "kg e1RM"
    }
  ],
  "generatedAt": "2026-11-08T10:00:00.000Z"
}
```

Day status is one of `done`, `partial`, `missed`, `rest`, `future`. Scheduled counts only
include tasks on or before today, so future tasks do not punish adherence.

### `GET /api/progress/exercises/:id`

Returns every completed data point for one exercise:

```json
{
  "exercise": { "id": "ex-barbell-back-squat", "name": "Barbell back squat" },
  "kind": "load",
  "unit": "kg e1RM",
  "points": [
    { "date": "2026-10-14", "value": 62.4, "minutes": 10.1 },
    { "date": "2026-11-04", "value": 70.5, "minutes": 10.1 }
  ],
  "best": 70.5,
  "deltaPct": 13.0,
  "sessions": 6
}
```

## Profile

### `GET /api/profile`

Returns the user profile.

### `PATCH /api/profile`

```json
{
  "name": "Sam",
  "goal": "strength",
  "experience": "intermediate",
  "daysPerWeek": 6,
  "sessionMinutes": 50,
  "equipment": ["Barbell", "Rack", "Bench"]
}
```

All fields optional. Validated:

- `goal`: balanced | strength | endurance | mobility | recovery
- `experience`: beginner | intermediate | advanced
- `daysPerWeek`: 1–7
- `sessionMinutes`: 10–120
- `equipment`: ≤ 20 strings

Changes apply to future plans; the current week is intentionally left intact.

## Example workflow

```bash
# Is the server alive?
curl -s localhost:8787/api/health

# What does today look like?
curl -s "localhost:8787/api/bootstrap?date=$(date +%F)" | jq '.today.timeRegions[] | {name, tasks: [.tasks[].exercise.name]}'

# Complete the first task
TASK=$(curl -s "localhost:8787/api/bootstrap?date=$(date +%F)" | jq -r '.today.timeRegions[].tasks[] | select(.status=="pending") | .id' | head -1)
curl -s -X POST "localhost:8787/api/tasks/$TASK/complete" \
  -H 'content-type: application/json' \
  -d '{"effort":7}' | jq '.task.status'

# Compare this week with last week
curl -s "localhost:8787/api/progress?period=week" | jq '{totals, deltas, prs: [.prs[] | {name, deltaPct}]}'
```

## Versioning

The API is currently unversioned (`/api/...`) and ships with the app from the same repository.
Breaking changes should either preserve old fields for one release or add `/api/v2`; the iOS
decoder ignores unknown fields, which allows additive evolution.
