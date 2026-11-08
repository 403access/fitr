import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { z } from 'zod';
import type { Database } from 'bun:sqlite';
import { demoCounts } from './db/seed.ts';
import { listExercises, getExerciseBySlug, getFacets, getExerciseById } from './domain/catalogue.ts';
import {
  buildBootstrap,
  buildTodayState,
} from './domain/bootstrap.ts';
import {
  completeTask,
  ensurePlan,
  getPlanDTO,
  getPlanRow,
  getTaskRow,
  serializePlan,
  serializeTask,
  skipTask,
  resetTask,
  tasksForDate,
} from './domain/plans.ts';
import { exerciseProgress, progressSummary, type Period } from './domain/progress.ts';
import { getUser, ensureUser, updateUser } from './domain/users.ts';
import { isValidDate, startOfWeek, todayString } from './lib/time.ts';

type Env = { Variables: { userId: string } };

const completionSchema = z.object({
  actualReps: z.number().int().min(0).max(500).optional(),
  actualHoldSeconds: z.number().int().min(0).max(3600).optional(),
  actualLoadKg: z.number().min(0).max(500).optional(),
  effort: z.number().int().min(1).max(10).optional(),
});

const profileSchema = z.object({
  name: z.string().trim().min(1).max(60).optional(),
  goal: z.enum(['balanced', 'strength', 'endurance', 'mobility', 'recovery']).optional(),
  experience: z.enum(['beginner', 'intermediate', 'advanced']).optional(),
  daysPerWeek: z.number().int().min(1).max(7).optional(),
  sessionMinutes: z.number().int().min(10).max(120).optional(),
  equipment: z.array(z.string().max(40)).max(20).optional(),
});

const periodSchema = z.enum(['day', 'week', 'month', 'year']);

function errorBody(code: string, message: string) {
  return { error: { code, message } };
}

async function parseBody(request: Request): Promise<unknown> {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

export function createApp(db: Database) {
  const app = new Hono<Env>();

  app.use('*', cors({ origin: '*', allowHeaders: ['Content-Type', 'X-User-Id'] }));
  if (process.env.NODE_ENV !== 'test') {
    app.use('*', logger());
  }

  app.use('*', async (c, next) => {
    const userId = c.req.header('x-user-id')?.trim() || c.req.query('userId')?.trim() || 'me';
    if (!getUser(db, userId)) ensureUser(db, userId);
    c.set('userId', userId);
    await next();
  });

  app.get('/', (c) =>
    c.json({
      name: 'Fitr API',
      version: '0.1.0',
      docs: '/api',
      endpoints: [
        'GET /api/health',
        'GET /api/bootstrap?date=YYYY-MM-DD',
        'GET /api/facets',
        'GET /api/exercises?topic=&type=&region=&muscle=&q=',
        'GET /api/exercises/:slug',
        'GET /api/tasks?date=YYYY-MM-DD',
        'POST /api/tasks/:id/complete',
        'POST /api/tasks/:id/skip',
        'POST /api/tasks/:id/reset',
        'GET /api/plans/current?date=YYYY-MM-DD',
        'GET /api/plans/:weekStart',
        'GET /api/progress?period=day|week|month|year&anchor=YYYY-MM-DD',
        'GET /api/progress/exercises/:id',
        'GET /api/profile',
        'PATCH /api/profile',
      ],
    }),
  );

  app.get('/api/health', (c) => {
    const counts = demoCounts(db);
    return c.json({
      status: 'ok',
      version: '0.1.0',
      time: new Date().toISOString(),
      database: counts,
    });
  });

  app.get('/api/bootstrap', (c) => {
    const date = c.req.query('date');
    if (date && !isValidDate(date)) return c.json(errorBody('invalid_date', 'Use YYYY-MM-DD.'), 400);
    const payload = buildBootstrap(db, c.get('userId'), date);
    if (!payload) return c.json(errorBody('not_found', 'User not found.'), 404);
    return c.json(payload);
  });

  app.get('/api/facets', (c) => c.json(getFacets(db)));

  app.get('/api/exercises', (c) => {
    const difficulty = c.req.query('difficulty');
    const parsedDifficulty = difficulty ? Number(difficulty) : undefined;
    const exercises = listExercises(db, {
      topic: c.req.query('topic') || undefined,
      type: c.req.query('type') || undefined,
      region: c.req.query('region') || undefined,
      muscle: c.req.query('muscle') || undefined,
      q: c.req.query('q') || undefined,
      difficulty:
        parsedDifficulty && Number.isFinite(parsedDifficulty) ? Math.min(5, Math.max(1, Math.round(parsedDifficulty))) : undefined,
    });
    return c.json({ exercises, count: exercises.length });
  });

  app.get('/api/exercises/:slug', (c) => {
    const exercise = getExerciseBySlug(db, c.req.param('slug'));
    if (!exercise) return c.json(errorBody('not_found', 'Exercise not found.'), 404);
    return c.json(exercise);
  });

  app.get('/api/tasks', (c) => {
    const date = c.req.query('date');
    if (date && !isValidDate(date)) return c.json(errorBody('invalid_date', 'Use YYYY-MM-DD.'), 400);
    const userId = c.get('userId');
    const user = getUser(db, userId) ?? ensureUser(db, userId);
    const target = date ?? todayString();
    const weekStart = startOfWeek(target);
    ensurePlan(db, user, weekStart);
    const tasks = tasksForDate(db, userId, target, {
      timeRegion: c.req.query('timeRegion') || undefined,
      status: c.req.query('status') || undefined,
    });
    return c.json({ date: target, tasks, count: tasks.length });
  });

  app.get('/api/tasks/:id', (c) => {
    const row = getTaskRow(db, c.get('userId'), c.req.param('id'));
    if (!row) return c.json(errorBody('not_found', 'Task not found.'), 404);
    return c.json(serializeTask(db, row));
  });

  app.post('/api/tasks/:id/complete', async (c) => {
    const body = completionSchema.safeParse(await parseBody(c.req.raw));
    if (!body.success) {
      return c.json(errorBody('invalid_body', body.error.issues.map((issue) => issue.message).join(', ')), 400);
    }
    const userId = c.get('userId');
    const task = completeTask(db, userId, c.req.param('id'), body.data);
    if (!task) return c.json(errorBody('not_found', 'Task not found.'), 404);
    const state = buildTodayState(db, userId, task.date);
    return c.json({ task, plan: state?.plan, streak: state?.streak });
  });

  app.post('/api/tasks/:id/skip', (c) => {
    const userId = c.get('userId');
    const task = skipTask(db, userId, c.req.param('id'));
    if (!task) return c.json(errorBody('not_found', 'Task not found.'), 404);
    const state = buildTodayState(db, userId, task.date);
    return c.json({ task, plan: state?.plan, streak: state?.streak });
  });

  app.post('/api/tasks/:id/reset', (c) => {
    const userId = c.get('userId');
    const task = resetTask(db, userId, c.req.param('id'));
    if (!task) return c.json(errorBody('not_found', 'Task not found.'), 404);
    const state = buildTodayState(db, userId, task.date);
    return c.json({ task, plan: state?.plan, streak: state?.streak });
  });

  app.get('/api/plans/current', (c) => {
    const date = c.req.query('date');
    if (date && !isValidDate(date)) return c.json(errorBody('invalid_date', 'Use YYYY-MM-DD.'), 400);
    const userId = c.get('userId');
    const user = getUser(db, userId) ?? ensureUser(db, userId);
    const weekStart = startOfWeek(date ?? todayString());
    const plan = ensurePlan(db, user, weekStart);
    return c.json(serializePlan(db, plan));
  });

  app.get('/api/plans/:weekStart', (c) => {
    const weekStart = c.req.param('weekStart');
    if (!isValidDate(weekStart)) return c.json(errorBody('invalid_date', 'Use YYYY-MM-DD.'), 400);
    const plan = getPlanDTO(db, c.get('userId'), weekStart);
    if (!plan) return c.json(errorBody('not_found', 'No plan for this week.'), 404);
    return c.json(plan);
  });

  app.get('/api/progress', (c) => {
    const period = periodSchema.safeParse(c.req.query('period') ?? 'week');
    if (!period.success) return c.json(errorBody('invalid_period', 'Use day, week, month or year.'), 400);
    const anchor = c.req.query('anchor') ?? todayString();
    if (!isValidDate(anchor)) return c.json(errorBody('invalid_date', 'Use YYYY-MM-DD.'), 400);
    const userId = c.get('userId');
    const user = getUser(db, userId) ?? ensureUser(db, userId);
    const weekStart = startOfWeek(anchor);
    if (weekStart >= startOfWeek(todayString())) {
      ensurePlan(db, user, weekStart);
    }
    return c.json(progressSummary(db, userId, period.data as Period, anchor));
  });

  app.get('/api/progress/exercises/:id', (c) => {
    const result = exerciseProgress(db, c.get('userId'), c.req.param('id'));
    if (!result) return c.json(errorBody('not_found', 'Exercise not found.'), 404);
    return c.json(result);
  });

  app.get('/api/profile', (c) => {
    const user = getUser(db, c.get('userId')) ?? ensureUser(db, c.get('userId'));
    return c.json(user);
  });

  app.patch('/api/profile', async (c) => {
    const body = profileSchema.safeParse(await parseBody(c.req.raw));
    if (!body.success) {
      return c.json(errorBody('invalid_body', body.error.issues.map((issue) => issue.message).join(', ')), 400);
    }
    const user = updateUser(db, c.get('userId'), body.data);
    return c.json(user);
  });

  // Convenient lookup used by the app when deep-linking an exercise by id.
  app.get('/api/exercise-by-id/:id', (c) => {
    const exercise = getExerciseById(db, c.req.param('id'));
    if (!exercise) return c.json(errorBody('not_found', 'Exercise not found.'), 404);
    return c.json(exercise);
  });

  app.notFound((c) => c.json(errorBody('not_found', 'Route not found.'), 404));

  app.onError((error, c) => {
    console.error(error);
    return c.json(errorBody('internal', 'Something went wrong.'), 500);
  });

  return app;
}
