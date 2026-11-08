import type { Database } from 'bun:sqlite';
import {
  exerciseTypes,
  exercises,
  muscles,
  regions,
  topics,
} from './seed-data.ts';
import { ensureUser, getUser } from '../domain/users.ts';
import { completeTask, ensurePlan, skipTask } from '../domain/plans.ts';
import { addDays, isoNow, startOfWeek, todayString } from '../lib/time.ts';

const TOPIC_IDS = new Set(topics.map((topic) => topic.id));
const TYPE_IDS = new Set(exerciseTypes.map((type) => type.id));
const REGION_IDS = new Set(regions.map((region) => region.id));
const MUSCLE_IDS = new Set(muscles.map((muscle) => muscle.id));

function hash(input: string): number {
  let value = 2166136261;
  for (let i = 0; i < input.length; i++) {
    value ^= input.charCodeAt(i);
    value = Math.imul(value, 16777619);
  }
  return value >>> 0;
}

function seedCatalogue(db: Database): void {
  const insertTopic = db.prepare(
    'INSERT OR IGNORE INTO topics (id, name, description, accent, icon) VALUES (?, ?, ?, ?, ?)',
  );
  for (const topic of topics) {
    insertTopic.run(topic.id, topic.name, topic.description, topic.accent, topic.icon);
  }

  const insertType = db.prepare(
    'INSERT OR IGNORE INTO exercise_types (id, name, description) VALUES (?, ?, ?)',
  );
  for (const type of exerciseTypes) {
    insertType.run(type.id, type.name, type.description);
  }

  const insertRegion = db.prepare('INSERT OR IGNORE INTO regions (id, name, sort_order) VALUES (?, ?, ?)');
  regions.forEach((region, index) => insertRegion.run(region.id, region.name, index));

  const insertMuscle = db.prepare(
    'INSERT OR IGNORE INTO muscles (id, name, region_id, sort_order) VALUES (?, ?, ?, ?)',
  );
  muscles.forEach((muscle, index) => {
    if (!REGION_IDS.has(muscle.region)) throw new Error(`Unknown region ${muscle.region} for muscle ${muscle.id}`);
    insertMuscle.run(muscle.id, muscle.name, muscle.region, index);
  });

  const insertExercise = db.prepare(
    `INSERT OR IGNORE INTO exercises
      (id, slug, name, summary, topic_id, type_id, difficulty, duration_seconds, animation,
       equipment, instructions, cues, benefits, breathing, default_sets, default_reps,
       default_hold_seconds, default_load_kg, rest_seconds, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  );
  const insertRegionLink = db.prepare(
    'INSERT OR IGNORE INTO exercise_regions (exercise_id, region_id) VALUES (?, ?)',
  );
  const insertMuscleLink = db.prepare(
    'INSERT OR IGNORE INTO exercise_muscles (exercise_id, muscle_id, role) VALUES (?, ?, ?)',
  );

  for (const exercise of exercises) {
    if (!TOPIC_IDS.has(exercise.topic)) throw new Error(`Unknown topic ${exercise.topic} in ${exercise.slug}`);
    if (!TYPE_IDS.has(exercise.type)) throw new Error(`Unknown type ${exercise.type} in ${exercise.slug}`);
    for (const region of exercise.regions) {
      if (!REGION_IDS.has(region)) throw new Error(`Unknown region ${region} in ${exercise.slug}`);
    }
    for (const muscle of [...exercise.primary, ...exercise.secondary]) {
      if (!MUSCLE_IDS.has(muscle)) throw new Error(`Unknown muscle ${muscle} in ${exercise.slug}`);
    }

    const id = `ex-${exercise.slug}`;
    insertExercise.run(
      id,
      exercise.slug,
      exercise.name,
      exercise.summary,
      exercise.topic,
      exercise.type,
      exercise.difficulty,
      exercise.durationSeconds,
      exercise.animation,
      JSON.stringify(exercise.equipment),
      JSON.stringify(exercise.instructions),
      JSON.stringify(exercise.cues),
      JSON.stringify(exercise.benefits),
      exercise.breathing,
      exercise.prescription.sets,
      exercise.prescription.reps ?? null,
      exercise.prescription.holdSeconds ?? null,
      exercise.prescription.loadKg ?? null,
      exercise.prescription.restSeconds,
      isoNow(),
    );
    for (const region of exercise.regions) insertRegionLink.run(id, region);
    for (const muscle of exercise.primary) insertMuscleLink.run(id, muscle, 'primary');
    for (const muscle of exercise.secondary) insertMuscleLink.run(id, muscle, 'secondary');
  }
}

const COMPLETION_HOUR: Record<string, string> = {
  wake: '06:45:00',
  morning: '08:15:00',
  midday: '12:30:00',
  afternoon: '16:00:00',
  evening: '19:00:00',
  pre_sleep: '22:00:00',
};

/**
 * Generates three completed weeks of history so the tracker has meaningful
 * baselines on a fresh install. `bun run db:reset` starts from scratch again.
 */
function seedHistory(db: Database, userId: string): void {
  const currentWeek = startOfWeek(todayString());
  const startWeek = addDays(currentWeek, -21);
  const today = todayString();
  const user = getUser(db, userId);
  if (!user) return;

  for (let offset = 0; offset < 4; offset++) {
    const weekStart = addDays(startWeek, offset * 7);
    const plan = ensurePlan(db, user, weekStart);

    const tasks = db
      .query<{ id: string; date: string; time_region: string; load_kg: number | null; reps: number | null; hold_seconds: number | null }, [string]>(
        'SELECT id, date, time_region, load_kg, reps, hold_seconds FROM tasks WHERE plan_id = ? ORDER BY date, order_index',
      )
      .all(plan.id);

    for (const task of tasks) {
      if (task.date >= today) continue; // today and the rest of the current week stay open
      const roll = hash(`${task.id}:completion`) % 100;
      if (roll < 7) {
        skipTask(db, userId, task.id);
        continue;
      }
      if (roll > 92) continue; // leave a few genuinely missed sessions

      const effort = 5 + (hash(`${task.id}:effort`) % 4);
      const load = task.load_kg === null ? null : task.load_kg + (hash(`${task.id}:load`) % 3 === 0 ? 2.5 : 0);
      const reps = task.reps === null ? null : task.reps + (hash(`${task.id}:reps`) % 4 === 0 ? 1 : 0);
      completeTask(db, userId, task.id, {
        actualReps: reps ?? undefined,
        actualHoldSeconds: task.hold_seconds ?? undefined,
        actualLoadKg: load ?? undefined,
        effort,
      });
      db.run('UPDATE tasks SET completed_at = ? WHERE id = ?', [
        `${task.date}T${COMPLETION_HOUR[task.time_region] ?? '12:00:00'}Z`,
        task.id,
      ]);
    }
  }
}

export function seedDatabase(db: Database): void {
  const count = db.query<{ count: number }, []>('SELECT COUNT(*) AS count FROM exercises').get()?.count ?? 0;
  if (count > 0) return;

  seedCatalogue(db);
  const user = ensureUser(db, 'me');
  const currentWeek = startOfWeek(todayString());
  const programStart = addDays(currentWeek, -21);
  db.run('UPDATE users SET program_start = ? WHERE id = ?', [programStart, user.id]);
  seedHistory(db, user.id);
}

export function demoCounts(db: Database): { exercises: number; plans: number; tasks: number } {
  return {
    exercises: db.query<{ count: number }, []>('SELECT COUNT(*) AS count FROM exercises').get()?.count ?? 0,
    plans: db.query<{ count: number }, []>('SELECT COUNT(*) AS count FROM plans').get()?.count ?? 0,
    tasks: db.query<{ count: number }, []>('SELECT COUNT(*) AS count FROM tasks').get()?.count ?? 0,
  };
}
