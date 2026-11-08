import type { Database } from 'bun:sqlite';
import {
  addDays,
  eachDay,
  endOfMonth,
  endOfYear,
  parseDate,
  startOfMonth,
  startOfWeek,
  startOfYear,
  toDateString,
  todayString,
} from '../lib/time.ts';

export type Period = 'day' | 'week' | 'month' | 'year';

export type Range = { start: string; end: string };

type Totals = {
  scheduled: number;
  completed: number;
  skipped: number;
  pending: number;
  minutes: number;
  volumeKg: number;
  reps: number;
  holdSeconds: number;
  sessions: number;
  adherence: number;
};

type AggregateRow = {
  scheduled: number;
  completed: number;
  skipped: number;
  minutes: number;
  volume_kg: number;
  reps: number;
  hold_seconds: number;
  sessions: number;
};

function resolveRange(period: Period, anchor: string): { current: Range; previous: Range } {
  if (period === 'day') {
    const previous = addDays(anchor, -1);
    return { current: { start: anchor, end: anchor }, previous: { start: previous, end: previous } };
  }
  if (period === 'week') {
    const start = startOfWeek(anchor);
    const end = addDays(start, 6);
    return {
      current: { start, end },
      previous: { start: addDays(start, -7), end: addDays(start, -1) },
    };
  }
  if (period === 'month') {
    const start = startOfMonth(anchor);
    const end = endOfMonth(anchor);
    const prevEnd = addDays(start, -1);
    return {
      current: { start, end },
      previous: { start: startOfMonth(prevEnd), end: prevEnd },
    };
  }
  const start = startOfYear(anchor);
  const end = endOfYear(anchor);
  const prevEnd = addDays(start, -1);
  return {
    current: { start, end },
    previous: { start: startOfYear(prevEnd), end: prevEnd },
  };
}

function cutoffFor(range: Range, today: string): string {
  return range.end > today ? today : range.end;
}

function aggregate(db: Database, userId: string, range: Range, today: string): Totals {
  const cutoff = cutoffFor(range, today);
  const row = db
    .query<AggregateRow, [string, string, string, string]>(
      `SELECT
        COALESCE(SUM(CASE WHEN date <= ? THEN 1 ELSE 0 END), 0) AS scheduled,
        COALESCE(SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END), 0) AS completed,
        COALESCE(SUM(CASE WHEN status = 'skipped' THEN 1 ELSE 0 END), 0) AS skipped,
        COALESCE(SUM(CASE WHEN status = 'done' THEN duration_minutes ELSE 0 END), 0) AS minutes,
        COALESCE(SUM(CASE WHEN status = 'done' AND reps IS NOT NULL
          THEN COALESCE(actual_reps, reps) * sets * COALESCE(actual_load_kg, load_kg, 0) ELSE 0 END), 0) AS volume_kg,
        COALESCE(SUM(CASE WHEN status = 'done' THEN COALESCE(actual_reps, reps, 0) * sets ELSE 0 END), 0) AS reps,
        COALESCE(SUM(CASE WHEN status = 'done' THEN COALESCE(actual_hold_seconds, hold_seconds, 0) * sets ELSE 0 END), 0) AS hold_seconds,
        COUNT(DISTINCT CASE WHEN status = 'done' THEN date END) AS sessions
       FROM tasks WHERE user_id = ? AND date >= ? AND date <= ?`,
    )
    .get(cutoff, userId, range.start, range.end);

  const scheduled = row?.scheduled ?? 0;
  const completed = row?.completed ?? 0;
  return {
    scheduled,
    completed,
    skipped: row?.skipped ?? 0,
    pending: Math.max(0, scheduled - completed - (row?.skipped ?? 0)),
    minutes: Math.round((row?.minutes ?? 0) * 10) / 10,
    volumeKg: Math.round(row?.volume_kg ?? 0),
    reps: row?.reps ?? 0,
    holdSeconds: row?.hold_seconds ?? 0,
    sessions: row?.sessions ?? 0,
    adherence: scheduled === 0 ? 0 : Math.round((completed / scheduled) * 100),
  };
}

function pctDelta(current: number, previous: number): number | null {
  if (previous === 0) return current === 0 ? 0 : null;
  return Math.round(((current - previous) / previous) * 1000) / 10;
}

type DayRow = {
  date: string;
  scheduled: number;
  completed: number;
  minutes: number;
  volume: number;
};

function daySeries(db: Database, userId: string, range: Range, today: string): Array<{
  date: string;
  scheduled: number;
  completed: number;
  minutes: number;
  volumeKg: number;
  status: 'done' | 'partial' | 'missed' | 'rest' | 'future';
}> {
  const rows = db
    .query<DayRow, [string, string, string]>(
      `SELECT date,
        COUNT(*) AS scheduled,
        COALESCE(SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END), 0) AS completed,
        COALESCE(SUM(CASE WHEN status = 'done' THEN duration_minutes ELSE 0 END), 0) AS minutes,
        COALESCE(SUM(CASE WHEN status = 'done' AND reps IS NOT NULL
          THEN COALESCE(actual_reps, reps) * sets * COALESCE(actual_load_kg, load_kg, 0) ELSE 0 END), 0) AS volume
       FROM tasks WHERE user_id = ? AND date >= ? AND date <= ?
       GROUP BY date ORDER BY date`,
    )
    .all(userId, range.start, range.end);
  const map = new Map(rows.map((row) => [row.date, row]));

  return eachDay(range.start, range.end).map((date) => {
    const row = map.get(date);
    const scheduled = row?.scheduled ?? 0;
    const completed = row?.completed ?? 0;
    let status: 'done' | 'partial' | 'missed' | 'rest' | 'future';
    if (date > today) status = 'future';
    else if (scheduled === 0) status = 'rest';
    else if (completed >= scheduled) status = 'done';
    else if (completed > 0) status = 'partial';
    else status = 'missed';

    return {
      date,
      scheduled,
      completed,
      minutes: Math.round((row?.minutes ?? 0) * 10) / 10,
      volumeKg: Math.round(row?.volume ?? 0),
      status,
    };
  });
}

function monthSeries(
  db: Database,
  userId: string,
  range: Range,
  today: string,
): Array<{ label: string; start: string; minutes: number; volumeKg: number; completed: number; scheduled: number }> {
  const months: Array<{ label: string; start: string; end: string }> = [];
  for (let month = 0; month < 12; month++) {
    const start = `${range.start.slice(0, 4)}-${String(month + 1).padStart(2, '0')}-01`;
    const end = endOfMonth(start);
    const label = new Date(parseDate(start)).toLocaleDateString('en-US', { month: 'short' });
    months.push({ label, start, end });
  }
  const rows = db
    .query<{ month: string; minutes: number; volume: number; completed: number; scheduled: number }, [string, string, string, string]>(
      `SELECT substr(date, 1, 7) AS month,
        COALESCE(SUM(CASE WHEN status = 'done' THEN duration_minutes ELSE 0 END), 0) AS minutes,
        COALESCE(SUM(CASE WHEN status = 'done' AND reps IS NOT NULL
          THEN COALESCE(actual_reps, reps) * sets * COALESCE(actual_load_kg, load_kg, 0) ELSE 0 END), 0) AS volume,
        COALESCE(SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END), 0) AS completed,
        COALESCE(SUM(CASE WHEN date <= ? THEN 1 ELSE 0 END), 0) AS scheduled
       FROM tasks WHERE user_id = ? AND date >= ? AND date <= ?
       GROUP BY month`,
    )
    .all(today, userId, range.start, range.end);
  const map = new Map(rows.map((row) => [row.month, row]));
  return months.map((month) => {
    const row = map.get(month.start.slice(0, 7));
    return {
      label: month.label,
      start: month.start,
      minutes: Math.round((row?.minutes ?? 0) * 10) / 10,
      volumeKg: Math.round(row?.volume ?? 0),
      completed: row?.completed ?? 0,
      scheduled: row?.scheduled ?? 0,
    };
  });
}

export function streakInfo(db: Database, userId: string, today = todayString()): { current: number; best: number; lastActive: string | null } {
  const dates = db
    .query<{ date: string }, [string]>(
      `SELECT DISTINCT date FROM tasks WHERE user_id = ? AND status = 'done' ORDER BY date ASC`,
    )
    .all(userId)
    .map((row) => row.date);

  let best = 0;
  let run = 0;
  let previous: string | null = null;
  for (const date of dates) {
    run = previous && addDays(previous, 1) === date ? run + 1 : 1;
    best = Math.max(best, run);
    previous = date;
  }

  let current = 0;
  let cursor = dates.includes(today) ? today : addDays(today, -1);
  while (dates.includes(cursor)) {
    current += 1;
    cursor = addDays(cursor, -1);
  }
  return { current, best, lastActive: dates.at(-1) ?? null };
}

type MuscleRow = { id: string; name: string; minutes: number };

function muscleBalance(db: Database, userId: string, range: Range): Array<{ id: string; name: string; minutes: number; share: number }> {
  const rows = db
    .query<MuscleRow, [string, string, string]>(
      `SELECT m.id, m.name, COALESCE(SUM(t.duration_minutes), 0) AS minutes
       FROM tasks t
       JOIN exercise_muscles em ON em.exercise_id = t.exercise_id AND em.role = 'primary'
       JOIN muscles m ON m.id = em.muscle_id
       WHERE t.user_id = ? AND t.status = 'done' AND t.date >= ? AND t.date <= ?
       GROUP BY m.id ORDER BY minutes DESC`,
    )
    .all(userId, range.start, range.end);
  const total = rows.reduce((sum, row) => sum + row.minutes, 0);
  return rows
    .map((row) => ({
      id: row.id,
      name: row.name,
      minutes: Math.round(row.minutes * 10) / 10,
      share: total === 0 ? 0 : Math.round((row.minutes / total) * 1000) / 10,
    }))
    .slice(0, 10);
}

type DoneTaskRow = {
  exercise_id: string;
  name: string;
  type_id: string;
  default_load_kg: number | null;
  date: string;
  reps: number | null;
  load: number | null;
  hold: number | null;
  sets: number;
  duration_minutes: number;
};

type ExerciseHistory = {
  exerciseId: string;
  name: string;
  kind: 'load' | 'reps' | 'hold';
  best: number;
  unit: string;
  date: string;
};

function historyRows(db: Database, userId: string, range: Range): DoneTaskRow[] {
  return db
    .query<DoneTaskRow, [string, string, string]>(
      `SELECT t.exercise_id, e.name, e.type_id, e.default_load_kg, t.date,
        COALESCE(t.actual_reps, t.reps) AS reps,
        COALESCE(t.actual_load_kg, t.load_kg) AS load,
        COALESCE(t.actual_hold_seconds, t.hold_seconds) AS hold,
        t.sets, t.duration_minutes
       FROM tasks t JOIN exercises e ON e.id = t.exercise_id
       WHERE t.user_id = ? AND t.status = 'done' AND t.date >= ? AND t.date <= ?
         AND e.type_id IN ('strength', 'isometric')`,
    )
    .all(userId, range.start, range.end);
}

function bestByExercise(rows: DoneTaskRow[]): Map<string, ExerciseHistory> {
  const out = new Map<string, ExerciseHistory>();
  for (const row of rows) {
    const weighted = row.load !== null && row.load > 0;
    const kind: ExerciseHistory['kind'] = weighted ? 'load' : row.hold !== null && row.hold > 0 ? 'hold' : 'reps';
    let value: number;
    let unit: string;
    if (kind === 'load') {
      value = Math.round((row.load ?? 0) * (1 + (row.reps ?? 0) / 30) * 10) / 10;
      unit = 'kg e1RM';
    } else if (kind === 'hold') {
      value = (row.hold ?? 0) * row.sets;
      unit = 's';
    } else {
      value = (row.reps ?? 0) * row.sets;
      unit = 'reps';
    }
    const existing = out.get(row.exercise_id);
    if (!existing || value > existing.best) {
      out.set(row.exercise_id, {
        exerciseId: row.exercise_id,
        name: row.name,
        kind,
        best: value,
        unit,
        date: row.date,
      });
    }
  }
  return out;
}

function personalRecords(
  db: Database,
  userId: string,
  current: Range,
  previous: Range,
): Array<{
  exerciseId: string;
  name: string;
  kind: 'load' | 'reps' | 'hold';
  value: number;
  unit: string;
  previous: number | null;
  deltaPct: number | null;
  achievedAt: string;
}> {
  const currentBest = bestByExercise(historyRows(db, userId, current));
  const previousBest = bestByExercise(historyRows(db, userId, previous));
  return [...currentBest.values()]
    .map((record) => {
      const prior = previousBest.get(record.exerciseId)?.best ?? null;
      return {
        exerciseId: record.exerciseId,
        name: record.name,
        kind: record.kind,
        value: record.best,
        unit: record.unit,
        previous: prior,
        deltaPct: prior === null ? null : pctDelta(record.best, prior),
        achievedAt: record.date,
      };
    })
    .sort((a, b) => (b.deltaPct ?? 0) - (a.deltaPct ?? 0))
    .slice(0, 6);
}

function improvements(
  db: Database,
  userId: string,
  current: Range,
  previous: Range,
): Array<{
  exerciseId: string;
  name: string;
  kind: 'load' | 'reps' | 'hold';
  current: number;
  previous: number | null;
  deltaPct: number | null;
  unit: string;
}> {
  const currentBest = bestByExercise(historyRows(db, userId, current));
  const previousBest = bestByExercise(historyRows(db, userId, previous));
  return [...currentBest.values()]
    .map((record) => {
      const prior = previousBest.get(record.exerciseId)?.best ?? null;
      return {
        exerciseId: record.exerciseId,
        name: record.name,
        kind: record.kind,
        current: record.best,
        previous: prior,
        deltaPct: prior === null ? null : pctDelta(record.best, prior),
        unit: record.unit,
      };
    })
    .sort((a, b) => (b.deltaPct ?? -Infinity) - (a.deltaPct ?? -Infinity))
    .slice(0, 6);
}

export function progressSummary(db: Database, userId: string, period: Period, anchor: string) {
  const today = todayString();
  const { current, previous } = resolveRange(period, anchor);
  const totals = aggregate(db, userId, current, today);
  const previousTotals = aggregate(db, userId, previous, today);
  const days = daySeries(db, userId, current, today);
  const series = period === 'year' ? monthSeries(db, userId, current, today) : days;

  return {
    period,
    anchor,
    range: current,
    previousRange: previous,
    totals,
    previousTotals,
    deltas: {
      minutesPct: pctDelta(totals.minutes, previousTotals.minutes),
      volumePct: pctDelta(totals.volumeKg, previousTotals.volumeKg),
      adherencePct: totals.adherence - previousTotals.adherence,
      completedPct: pctDelta(totals.completed, previousTotals.completed),
      sessionsPct: pctDelta(totals.sessions, previousTotals.sessions),
    },
    streak: streakInfo(db, userId, today),
    days,
    series,
    muscles: muscleBalance(db, userId, current),
    prs: personalRecords(db, userId, current, previous),
    improvements: improvements(db, userId, current, previous),
    generatedAt: new Date().toISOString(),
  };
}

export function exerciseProgress(db: Database, userId: string, exerciseId: string) {
  const exercise = db
    .query<{ id: string; name: string; type_id: string; default_load_kg: number | null }, [string]>(
      'SELECT id, name, type_id, default_load_kg FROM exercises WHERE id = ?',
    )
    .get(exerciseId);
  if (!exercise) return null;

  const rows = db
    .query<DoneTaskRow, [string, string]>(
      `SELECT t.exercise_id, e.name, e.type_id, e.default_load_kg, t.date,
        COALESCE(t.actual_reps, t.reps) AS reps,
        COALESCE(t.actual_load_kg, t.load_kg) AS load,
        COALESCE(t.actual_hold_seconds, t.hold_seconds) AS hold,
        t.sets, t.duration_minutes
       FROM tasks t JOIN exercises e ON e.id = t.exercise_id
       WHERE t.user_id = ? AND t.exercise_id = ? AND t.status = 'done'
       ORDER BY t.date ASC`,
    )
    .all(userId, exerciseId);

  const weighted = rows.some((row) => row.load !== null && row.load > 0);
  const holds = rows.some((row) => row.hold !== null && row.hold > 0);
  const kind: 'load' | 'reps' | 'hold' = weighted ? 'load' : holds ? 'hold' : 'reps';

  const points = rows.map((row) => {
    const value =
      kind === 'load'
        ? Math.round((row.load ?? 0) * (1 + (row.reps ?? 0) / 30) * 10) / 10
        : kind === 'hold'
          ? (row.hold ?? 0) * row.sets
          : (row.reps ?? 0) * row.sets;
    return { date: row.date, value, minutes: row.duration_minutes };
  });

  const first = points[0]?.value ?? 0;
  const last = points.at(-1)?.value ?? 0;
  return {
    exercise,
    kind,
    unit: kind === 'load' ? 'kg e1RM' : kind === 'hold' ? 's' : 'reps',
    points,
    best: points.reduce((max, point) => Math.max(max, point.value), 0),
    deltaPct: first === 0 ? null : pctDelta(last, first),
    sessions: rows.length,
  };
}
