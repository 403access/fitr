import type { Database } from 'bun:sqlite';
import { getExerciseById, type ExerciseDTO } from './catalogue.ts';
import type { UserDTO } from './users.ts';
import { addDays, isoNow, startOfWeek, weekDates, weekIndexFor } from '../lib/time.ts';
import { timeRegions, type TimeRegionId } from '../db/seed-data.ts';

export type PlanRow = {
  id: string;
  user_id: string;
  week_start: string;
  week_index: number;
  focus: string;
  volume_multiplier: number;
  intensity_multiplier: number;
  created_at: string;
};

export type TaskRow = {
  id: string;
  plan_id: string;
  user_id: string;
  date: string;
  time_region: TimeRegionId;
  order_index: number;
  exercise_id: string;
  sets: number;
  reps: number | null;
  hold_seconds: number | null;
  rest_seconds: number;
  load_kg: number | null;
  duration_minutes: number;
  target_note: string;
  status: 'pending' | 'done' | 'skipped';
  completed_at: string | null;
  actual_reps: number | null;
  actual_hold_seconds: number | null;
  actual_load_kg: number | null;
  effort: number | null;
  created_at: string;
};

export type TaskDTO = {
  id: string;
  date: string;
  timeRegion: { id: TimeRegionId; name: string; hint: string; icon: string };
  orderIndex: number;
  status: 'pending' | 'done' | 'skipped';
  sets: number;
  reps: number | null;
  holdSeconds: number | null;
  restSeconds: number;
  loadKg: number | null;
  durationMinutes: number;
  targetNote: string;
  completedAt: string | null;
  actualReps: number | null;
  actualHoldSeconds: number | null;
  actualLoadKg: number | null;
  effort: number | null;
  exercise: ExerciseDTO;
};

export type TaskFilters = { timeRegion?: string; status?: string };

type ExerciseMeta = {
  id: string;
  slug: string;
  topic: string;
  type: string;
  difficulty: number;
  equipment: string;
  duration: number;
  sets: number;
  reps: number | null;
  hold: number | null;
  load: number | null;
  rest: number;
  animation: string;
};

const REGION_LOOKUP = new Map(timeRegions.map((region) => [region.id, region]));

export function timeRegionDTO(id: string) {
  const region = REGION_LOOKUP.get(id as TimeRegionId) ?? timeRegions[0];
  return { id: region.id, name: region.name, hint: region.hint, icon: region.icon };
}

export function getPlanRow(db: Database, userId: string, weekStart: string): PlanRow | null {
  return db
    .query<PlanRow, [string, string]>('SELECT * FROM plans WHERE user_id = ? AND week_start = ?')
    .get(userId, weekStart);
}

export function getPlanRowsForDate(db: Database, userId: string, date: string): TaskRow[] {
  return db
    .query<TaskRow, [string, string]>(
      'SELECT * FROM tasks WHERE user_id = ? AND date = ? ORDER BY time_region, order_index',
    )
    .all(userId, date);
}

export function getTaskRow(db: Database, userId: string, taskId: string): TaskRow | null {
  return db
    .query<TaskRow, [string, string]>('SELECT * FROM tasks WHERE id = ? AND user_id = ?')
    .get(taskId, userId);
}

export function serializeTask(db: Database, row: TaskRow, cache?: Map<string, ExerciseDTO>): TaskDTO {
  let exercise = cache?.get(row.exercise_id);
  if (!exercise) {
    exercise = getExerciseById(db, row.exercise_id) ?? undefined;
    if (exercise) cache?.set(row.exercise_id, exercise);
  }
  if (!exercise) throw new Error(`Exercise missing for task ${row.id}`);

  return {
    id: row.id,
    date: row.date,
    timeRegion: timeRegionDTO(row.time_region),
    orderIndex: row.order_index,
    status: row.status,
    sets: row.sets,
    reps: row.reps,
    holdSeconds: row.hold_seconds,
    restSeconds: row.rest_seconds,
    loadKg: row.load_kg,
    durationMinutes: row.duration_minutes,
    targetNote: row.target_note,
    completedAt: row.completed_at,
    actualReps: row.actual_reps,
    actualHoldSeconds: row.actual_hold_seconds,
    actualLoadKg: row.actual_load_kg,
    effort: row.effort,
    exercise,
  };
}

export type PlanDTO = {
  id: string;
  weekStart: string;
  weekIndex: number;
  focus: string;
  volumeMultiplier: number;
  intensityMultiplier: number;
  days: Array<{
    date: string;
    isRestDay: boolean;
    totalMinutes: number;
    completedTasks: number;
    totalTasks: number;
    tasks: TaskDTO[];
  }>;
  summary: {
    totalTasks: number;
    completedTasks: number;
    totalMinutes: number;
  };
};

export function serializePlan(db: Database, plan: PlanRow): PlanDTO {
  const tasks = db
    .query<TaskRow, [string]>('SELECT * FROM tasks WHERE plan_id = ? ORDER BY date, time_region, order_index')
    .all(plan.id);
  const cache = new Map<string, ExerciseDTO>();
  const rows = tasks.map((task) => serializeTask(db, task, cache));
  const days = weekDates(plan.week_start).map((date) => {
    const dayTasks = rows.filter((task) => task.date === date);
    const recoveryOnly =
      dayTasks.length > 0 &&
      dayTasks.every((task) => ['wake', 'midday', 'pre_sleep'].includes(task.timeRegion.id));
    return {
      date,
      isRestDay: recoveryOnly,
      totalMinutes: Math.round(dayTasks.reduce((sum, task) => sum + task.durationMinutes, 0) * 10) / 10,
      completedTasks: dayTasks.filter((task) => task.status === 'done').length,
      totalTasks: dayTasks.length,
      tasks: dayTasks,
    };
  });
  return {
    id: plan.id,
    weekStart: plan.week_start,
    weekIndex: plan.week_index,
    focus: plan.focus,
    volumeMultiplier: plan.volume_multiplier,
    intensityMultiplier: plan.intensity_multiplier,
    days,
    summary: {
      totalTasks: rows.length,
      completedTasks: rows.filter((task) => task.status === 'done').length,
      totalMinutes: Math.round(rows.reduce((sum, task) => sum + task.durationMinutes, 0) * 10) / 10,
    },
  };
}

export function getPlanDTO(db: Database, userId: string, weekStart: string): PlanDTO | null {
  const plan = getPlanRow(db, userId, weekStart);
  return plan ? serializePlan(db, plan) : null;
}

const REST_DAY_ORDER = [2, 5, 6, 0, 1, 3, 4] as const;
const FOCUS_BY_PHASE = ['Foundation', 'Foundation', 'Foundation', 'Foundation', 'Build', 'Build', 'Build', 'Build', 'Capacity', 'Capacity', 'Capacity', 'Capacity'];

function focusFor(weekIndex: number): string {
  const phase = FOCUS_BY_PHASE[Math.min(weekIndex - 1, FOCUS_BY_PHASE.length - 1)] ?? 'Peak';
  return weekIndex > 12 ? 'Peak' : phase;
}

function hashString(input: string): number {
  let hash = 2166136261;
  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function roundTo2_5(value: number): number {
  return Math.round(value / 2.5) * 2.5;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function loadMeta(db: Database): ExerciseMeta[] {
  return db
    .query<
      {
        id: string;
        slug: string;
        topic_id: string;
        type_id: string;
        difficulty: number;
        equipment: string;
        duration_seconds: number;
        default_sets: number;
        default_reps: number | null;
        default_hold_seconds: number | null;
        default_load_kg: number | null;
        rest_seconds: number;
        animation: string;
      },
      []
    >('SELECT * FROM exercises')
    .all()
    .map((row) => ({
      id: row.id,
      slug: row.slug,
      topic: row.topic_id,
      type: row.type_id,
      difficulty: row.difficulty,
      equipment: row.equipment,
      duration: row.duration_seconds,
      sets: row.default_sets,
      reps: row.default_reps,
      hold: row.default_hold_seconds,
      load: row.default_load_kg,
      rest: row.rest_seconds,
      animation: row.animation,
    }));
}

type Slot = {
  region: TimeRegionId;
  pools: string[];
  order: number;
  recovery?: boolean;
};

function slotsForDay(user: UserDTO, rest: boolean): Slot[] {
  if (rest) {
    return [
      { region: 'wake', pools: ['mobility'], order: 0, recovery: true },
      { region: 'midday', pools: ['recovery'], order: 0, recovery: true },
      { region: 'pre_sleep', pools: ['recovery'], order: 0, recovery: true },
    ];
  }

  const morning: string[] =
    user.goal === 'strength' || user.goal === 'balanced'
      ? ['compound']
      : user.goal === 'endurance'
        ? ['cardio']
        : user.goal === 'mobility'
          ? ['mobility']
          : ['yoga'];

  const afternoon: string[] =
    user.goal === 'strength'
      ? ['accessory']
      : user.goal === 'endurance'
        ? ['bodyweight']
        : user.goal === 'mobility'
          ? ['yoga']
          : user.goal === 'recovery'
            ? ['mobility']
            : ['bodyweight'];

  const midday: string[] = user.goal === 'recovery' ? ['recovery'] : ['mobility'];
  const evening: string[] = user.goal === 'endurance' ? ['cardio'] : ['yoga'];
  const preSleep: string[] = user.goal === 'recovery' ? ['recovery'] : ['recovery'];

  const slots: Slot[] = [
    { region: 'wake', pools: ['mobility'], order: 0, recovery: true },
    { region: 'morning', pools: morning, order: 0 },
  ];

  if (user.sessionMinutes >= 40) {
    slots.push({
      region: 'morning',
      pools: user.goal === 'strength' || user.goal === 'balanced' ? ['accessory'] : ['bodyweight'],
      order: 1,
    });
  }

  slots.push(
    { region: 'midday', pools: midday, order: 0, recovery: true },
    { region: 'afternoon', pools: afternoon, order: 0 },
    { region: 'evening', pools: evening, order: 0 },
    { region: 'pre_sleep', pools: preSleep, order: 0, recovery: true },
  );
  return slots;
}

function poolFor(meta: ExerciseMeta[], pool: string): ExerciseMeta[] {
  switch (pool) {
    case 'mobility':
      return meta.filter((ex) => ex.topic === 'mobility' || (ex.topic === 'yoga' && ex.type === 'mobility'));
    case 'strength':
      return meta.filter((ex) => ex.topic === 'strength' && ex.type === 'strength');
    case 'compound':
      return meta.filter((ex) => ex.topic === 'strength' && ex.type === 'strength' && ex.difficulty >= 3);
    case 'accessory':
      return meta.filter(
        (ex) =>
          (ex.topic === 'strength' && ex.type === 'strength') ||
          (ex.topic === 'calisthenics' && (ex.type === 'strength' || ex.type === 'isometric')),
      );
    case 'bodyweight':
      return meta.filter((ex) => ex.topic === 'calisthenics' || (ex.topic === 'strength' && ex.load === null));
    case 'cardio':
      return meta.filter((ex) => ex.topic === 'cardio' || ex.type === 'cardio' || ex.type === 'plyometric');
    case 'yoga':
      return meta.filter((ex) => ex.topic === 'yoga');
    case 'recovery':
      return meta.filter((ex) => ex.topic === 'recovery' || ex.type === 'breathwork');
    default:
      return meta;
  }
}

function maxDifficulty(user: UserDTO): number {
  if (user.experience === 'beginner') return 2;
  if (user.experience === 'intermediate') return 4;
  return 5;
}

function equipmentAllowed(meta: ExerciseMeta, user: UserDTO): boolean {
  if (user.equipment.length === 0) return true;
  const required = JSON.parse(meta.equipment) as string[];
  return required.every((item) => user.equipment.includes(item));
}

function progressionBump(db: Database, userId: string, exerciseId: string, day: string): number {
  const row = db
    .query<{ count: number; avg_effort: number | null; reps: number | null; load: number | null }, [string, string, string, string]>(
      `SELECT COUNT(*) AS count, AVG(effort) AS avg_effort, MAX(actual_reps) AS reps, MAX(actual_load_kg) AS load
       FROM tasks
       WHERE user_id = ? AND exercise_id = ? AND status = 'done' AND date >= ? AND date < ?`,
    )
    .get(userId, exerciseId, addDays(day, -7), day);
  return row && row.count > 0 && (row.avg_effort ?? 10) <= 7 ? 1 : 0;
}

function prescribe(
  db: Database,
  user: UserDTO,
  meta: ExerciseMeta,
  weekIndex: number,
  volumeMultiplier: number,
  intensityMultiplier: number,
  day: string,
  recovery: boolean,
) {
  const bump = recovery ? 0 : progressionBump(db, user.id, meta.id, day);
  const sets = recovery ? meta.sets : clamp(meta.sets + Math.floor((weekIndex - 1) / 8), 1, 6);
  const reps = meta.reps
    ? Math.round(meta.reps * (recovery ? 1 : volumeMultiplier)) + (bump && meta.load === null ? 2 : 0)
    : null;
  let hold = meta.hold;
  if (hold !== null && !recovery && ['stretch', 'mobility', 'isometric', 'balance'].includes(meta.type) && hold <= 90) {
    hold = Math.round(hold * clamp(1 + (weekIndex - 1) * 0.025, 1, 1.6));
  }
  const load =
    meta.load !== null
      ? roundTo2_5(meta.load * (recovery ? 1 : intensityMultiplier) + (bump ? 2.5 : 0))
      : null;

  const rest = meta.rest;
  const workSeconds = reps ? reps * 3 : (hold ?? 30);
  const durationMinutes = Math.max(
    1,
    Math.round(((sets * (workSeconds + rest) + 30) / 60) * 10) / 10,
  );

  let targetNote: string;
  if (load !== null && reps) targetNote = `${sets} × ${reps} @ ${load} kg`;
  else if (hold !== null && meta.type === 'breathwork') targetNote = `${sets} × ${Math.max(1, Math.round(hold / 60))} min breath`;
  else if (hold !== null && meta.type === 'cardio') targetNote = `${sets} × ${Math.max(1, Math.round(hold / 60))} min`;
  else if (hold !== null) targetNote = `${sets} × ${hold}s hold`;
  else targetNote = `${sets} × ${reps ?? 10} reps`;

  return { sets, reps, hold, load, rest, durationMinutes, targetNote };
}

function choose(
  meta: ExerciseMeta[],
  pools: string[],
  user: UserDTO,
  used: Set<string>,
  seed: string,
): ExerciseMeta | null {
  const rank = (candidates: ExerciseMeta[]) =>
    candidates
      .map((ex) => ({ ex, score: hashString(`${seed}:${ex.slug}`) }))
      .sort((a, b) => a.score - b.score)[0]?.ex ?? null;

  const eligible = (candidates: ExerciseMeta[]) =>
    candidates.filter(
      (ex) => ex.difficulty <= maxDifficulty(user) && equipmentAllowed(ex, user) && !used.has(ex.id),
    );

  for (const pool of pools) {
    const candidates = eligible(poolFor(meta, pool));
    if (candidates.length) return rank(candidates);
  }

  return rank(eligible(meta));
}

function createPlanRecord(
  db: Database,
  user: UserDTO,
  weekStart: string,
  weekIndex: number,
): PlanRow {
  const volumeMultiplier = Math.round(Math.min(1 + 0.06 * (weekIndex - 1), 1.8) * 100) / 100;
  const intensityMultiplier = Math.round(Math.min(1 + 0.04 * (weekIndex - 1), 1.5) * 100) / 100;
  const plan: PlanRow = {
    id: `plan-${user.id}-${weekStart}`,
    user_id: user.id,
    week_start: weekStart,
    week_index: weekIndex,
    focus: focusFor(weekIndex),
    volume_multiplier: volumeMultiplier,
    intensity_multiplier: intensityMultiplier,
    created_at: isoNow(),
  };
  db.run(
    `INSERT INTO plans (id, user_id, week_start, week_index, focus, volume_multiplier, intensity_multiplier, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      plan.id,
      plan.user_id,
      plan.week_start,
      plan.week_index,
      plan.focus,
      plan.volume_multiplier,
      plan.intensity_multiplier,
      plan.created_at,
    ],
  );

  const meta = loadMeta(db);
  const restCount = clamp(7 - user.daysPerWeek, 0, 7);
  const restDays = new Set(REST_DAY_ORDER.slice(0, restCount));
  const dates = weekDates(weekStart);

  const insert = db.prepare(
    `INSERT INTO tasks (id, plan_id, user_id, date, time_region, order_index, exercise_id, sets, reps,
      hold_seconds, rest_seconds, load_kg, duration_minutes, target_note, status, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)`,
  );

  dates.forEach((date, dayIndex) => {
    const rest = restDays.has(dayIndex as (typeof REST_DAY_ORDER)[number]);
    const used = new Set<string>();
    slotsForDay(user, rest).forEach((slot, slotIndex) => {
      const seed = `${user.id}:${date}:${slot.region}:${slotIndex}:${weekIndex}`;
      const chosen = choose(meta, slot.pools, user, used, seed);
      if (!chosen) return;
      used.add(chosen.id);
      const rx = prescribe(
        db,
        user,
        chosen,
        weekIndex,
        volumeMultiplier,
        intensityMultiplier,
        date,
        Boolean(slot.recovery),
      );
      insert.run(
        crypto.randomUUID(),
        plan.id,
        user.id,
        date,
        slot.region,
        slot.order,
        chosen.id,
        rx.sets,
        rx.reps,
        rx.hold,
        rx.rest,
        rx.load,
        rx.durationMinutes,
        rx.targetNote,
        isoNow(),
      );
    });
  });

  return plan;
}

export function ensurePlan(db: Database, user: UserDTO, weekStart = startOfWeek(new Date().toISOString().slice(0, 10))): PlanRow {
  const existing = getPlanRow(db, user.id, weekStart);
  if (existing) return existing;
  const index = weekIndexFor(user.programStart, weekStart);
  return createPlanRecord(db, user, weekStart, Math.max(1, index));
}

export function tasksForDate(db: Database, userId: string, date: string, filters: TaskFilters = {}): TaskDTO[] {
  const clauses = ['user_id = ?', 'date = ?'];
  const params: string[] = [userId, date];
  if (filters.timeRegion) {
    clauses.push('time_region = ?');
    params.push(filters.timeRegion);
  }
  if (filters.status) {
    clauses.push('status = ?');
    params.push(filters.status);
  }
  const rows = db
    .query<TaskRow, string[]>(
      `SELECT * FROM tasks WHERE ${clauses.join(' AND ')} ORDER BY time_region, order_index`,
    )
    .all(...params);
  const cache = new Map<string, ExerciseDTO>();
  return rows.map((row) => serializeTask(db, row, cache));
}

export type CompletionInput = {
  actualReps?: number;
  actualHoldSeconds?: number;
  actualLoadKg?: number;
  effort?: number;
};

export function completeTask(db: Database, userId: string, taskId: string, input: CompletionInput): TaskDTO | null {
  const task = getTaskRow(db, userId, taskId);
  if (!task) return null;
  const effort = input.effort === undefined ? null : clamp(Math.round(input.effort), 1, 10);
  db.run(
    `UPDATE tasks SET status = 'done', completed_at = ?, actual_reps = ?, actual_hold_seconds = ?,
       actual_load_kg = ?, effort = ? WHERE id = ? AND user_id = ?`,
    [
      isoNow(),
      input.actualReps ?? task.reps,
      input.actualHoldSeconds ?? task.hold_seconds,
      input.actualLoadKg ?? task.load_kg,
      effort,
      taskId,
      userId,
    ],
  );
  return serializeTask(db, getTaskRow(db, userId, taskId)!);
}

export function skipTask(db: Database, userId: string, taskId: string): TaskDTO | null {
  const task = getTaskRow(db, userId, taskId);
  if (!task) return null;
  db.run(`UPDATE tasks SET status = 'skipped', completed_at = NULL WHERE id = ? AND user_id = ?`, [taskId, userId]);
  return serializeTask(db, getTaskRow(db, userId, taskId)!);
}

export function resetTask(db: Database, userId: string, taskId: string): TaskDTO | null {
  const task = getTaskRow(db, userId, taskId);
  if (!task) return null;
  db.run(
    `UPDATE tasks SET status = 'pending', completed_at = NULL, actual_reps = NULL,
       actual_hold_seconds = NULL, actual_load_kg = NULL, effort = NULL WHERE id = ? AND user_id = ?`,
    [taskId, userId],
  );
  return serializeTask(db, getTaskRow(db, userId, taskId)!);
}

export function tasksForRange(db: Database, userId: string, from: string, to: string): TaskRow[] {
  return db
    .query<TaskRow, [string, string, string]>(
      `SELECT * FROM tasks WHERE user_id = ? AND date >= ? AND date <= ? ORDER BY date, time_region, order_index`,
    )
    .all(userId, from, to);
}
