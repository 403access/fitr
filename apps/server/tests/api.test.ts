import { beforeEach, describe, expect, test } from 'bun:test';
import type { Database } from 'bun:sqlite';
import { createDatabase } from '../src/db/database.ts';
import { seedDatabase } from '../src/db/seed.ts';
import { createApp } from '../src/app.ts';
import { getPlanDTO, ensurePlan, getPlanRow } from '../src/domain/plans.ts';
import { getUser } from '../src/domain/users.ts';
import { addDays, startOfWeek, todayString } from '../src/lib/time.ts';

let db: Database;
let app: ReturnType<typeof createApp>;

beforeEach(() => {
  db = createDatabase(':memory:');
  seedDatabase(db);
  app = createApp(db);
});

async function json(path: string, init?: RequestInit) {
  const response = await app.request(path, init);
  return { status: response.status, body: (await response.json()) as any };
}

describe('catalogue', () => {
  test('seeds exercises with facets and muscle relationships', () => {
    const exercises = db.query<{ count: number }, []>('SELECT COUNT(*) AS count FROM exercises').get();
    expect(exercises?.count).toBeGreaterThan(40);

    const links = db.query<{ count: number }, []>('SELECT COUNT(*) AS count FROM exercise_muscles').get();
    expect(links?.count).toBeGreaterThan(100);
  });

  test('filters exercises by topic, region, muscle and search', async () => {
    const yoga = await json('/api/exercises?topic=yoga');
    expect(yoga.status).toBe(200);
    expect(yoga.body.exercises.length).toBeGreaterThan(5);
    expect(yoga.body.exercises.every((exercise: any) => exercise.topic.id === 'yoga')).toBe(true);

    const quads = await json('/api/exercises?muscle=quads');
    expect(quads.body.exercises.some((exercise: any) => exercise.slug === 'barbell-back-squat')).toBe(true);

    const search = await json('/api/exercises?q=squat');
    expect(search.body.exercises.length).toBeGreaterThan(1);
  });

  test('returns full exercise detail with primary and secondary muscles', async () => {
    const response = await json('/api/exercises/barbell-back-squat');
    expect(response.status).toBe(200);
    expect(response.body.primaryMuscles.map((muscle: any) => muscle.id)).toContain('quads');
    expect(response.body.secondaryMuscles.length).toBeGreaterThan(0);
    expect(response.body.instructions.length).toBeGreaterThan(2);
  });
});

describe('plans', () => {
  test('bootstrap creates a six-region day plan', async () => {
    const reference = startOfWeek(todayString());
    const thursday = addDays(reference, 3);
    const response = await json(`/api/bootstrap?date=${thursday}`);
    expect(response.status).toBe(200);
    expect(response.body.today.timeRegions.length).toBe(6);
    expect(response.body.plan.weekIndex).toBe(4);
    expect(response.body.today.totalTasks).toBeGreaterThan(3);
  });

  test('every week increases volume and intensity', () => {
    const user = getUser(db, 'me')!;
    const currentWeek = startOfWeek(todayString());
    const thisWeek = ensurePlan(db, user, currentWeek);
    const nextWeek = ensurePlan(db, user, addDays(currentWeek, 7));
    expect(nextWeek.week_index).toBe(thisWeek.week_index + 1);
    expect(nextWeek.volume_multiplier).toBeGreaterThan(thisWeek.volume_multiplier);
    expect(nextWeek.intensity_multiplier).toBeGreaterThan(thisWeek.intensity_multiplier);
    expect(nextWeek.focus).toBeTruthy();
  });

  test('plan persists and is idempotent', async () => {
    const first = await json('/api/plans/current');
    const second = await json('/api/plans/current');
    expect(first.body.id).toBe(second.body.id);
    expect(first.body.days.length).toBe(7);
  });

  test('completing a task updates the plan and streak', async () => {
    const bootstrap = await json('/api/bootstrap');
    const pending = bootstrap.body.today.timeRegions
      .flatMap((region: any) => region.tasks)
      .find((task: any) => task.status === 'pending');
    expect(pending).toBeTruthy();

    const complete = await json(`/api/tasks/${pending.id}/complete`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ effort: 7, actualReps: pending.reps ?? undefined }),
    });
    expect(complete.status).toBe(200);
    expect(complete.body.task.status).toBe('done');
    expect(complete.body.streak.current).toBeGreaterThanOrEqual(1);

    const reset = await json(`/api/tasks/${pending.id}/reset`, { method: 'POST' });
    expect(reset.body.task.status).toBe('pending');
  });
});

describe('progress', () => {
  test('returns totals, day series, streak and muscle balance', async () => {
    const lastWeek = addDays(todayString(), -7);
    const summary = await json(`/api/progress?period=week&anchor=${lastWeek}`);
    expect(summary.status).toBe(200);
    expect(summary.body.days.length).toBe(7);
    expect(summary.body.totals.scheduled).toBeGreaterThan(0);
    expect(summary.body.totals.completed).toBeGreaterThan(0);
    expect(summary.body.muscles.length).toBeGreaterThan(0);
    expect(summary.body.streak.best).toBeGreaterThan(0);
  });

  test('supports day, month and year periods', async () => {
    for (const period of ['day', 'month', 'year']) {
      const response = await json(`/api/progress?period=${period}`);
      expect(response.status).toBe(200);
      expect(response.body.period).toBe(period);
    }
    const year = await json('/api/progress?period=year');
    expect(year.body.series.length).toBe(12);
  });

  test('rejects invalid period and date input', async () => {
    expect((await json('/api/progress?period=decade')).status).toBe(400);
    expect((await json('/api/progress?anchor=08-11-2026')).status).toBe(400);
  });
});

describe('profile', () => {
  test('updates settings and validates bounds', async () => {
    const patch = await json('/api/profile', {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ name: 'Sam', daysPerWeek: 6, goal: 'strength' }),
    });
    expect(patch.status).toBe(200);
    expect(patch.body.name).toBe('Sam');
    expect(patch.body.daysPerWeek).toBe(6);

    const invalid = await json('/api/profile', {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ daysPerWeek: 12 }),
    });
    expect(invalid.status).toBe(400);
  });
});
