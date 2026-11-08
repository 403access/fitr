import type { Database } from 'bun:sqlite';
import { getFacets } from './catalogue.ts';
import { timeRegions as TIME_REGIONS } from '../db/seed-data.ts';
import { ensurePlan, serializePlan, tasksForDate, type TaskDTO, type PlanDTO } from './plans.ts';
import { getUser, ensureUser, type UserDTO } from './users.ts';
import { streakInfo } from './progress.ts';
import { startOfWeek, todayString, isValidDate } from '../lib/time.ts';

export type TodayState = {
  user: UserDTO;
  date: string;
  weekStart: string;
  plan: PlanDTO;
  today: {
    date: string;
    totalTasks: number;
    completedTasks: number;
    skippedTasks: number;
    totalMinutes: number;
    completedMinutes: number;
    adherence: number;
    timeRegions: Array<{
      id: string;
      name: string;
      hint: string;
      icon: string;
      tasks: TaskDTO[];
      completed: number;
      totalMinutes: number;
    }>;
  };
  streak: { current: number; best: number; lastActive: string | null };
};

export function buildTodayState(db: Database, userId: string, requestedDate?: string): TodayState | null {
  const user = getUser(db, userId) ?? ensureUser(db, userId);
  const date = requestedDate && isValidDate(requestedDate) ? requestedDate : todayString();
  const weekStart = startOfWeek(date);
  const planRow = ensurePlan(db, user, weekStart);
  const plan = serializePlan(db, planRow);
  const day = plan.days.find((entry) => entry.date === date);
  const tasks = day?.tasks ?? tasksForDate(db, user.id, date);

  const timeRegions = TIME_REGIONS.map((region) => {
    const regionTasks = tasks.filter((task) => task.timeRegion.id === region.id);
    return {
      id: region.id,
      name: region.name,
      hint: region.hint,
      icon: region.icon,
      tasks: regionTasks,
      completed: regionTasks.filter((task) => task.status === 'done').length,
      totalMinutes: Math.round(regionTasks.reduce((sum, task) => sum + task.durationMinutes, 0) * 10) / 10,
    };
  });

  const totalTasks = tasks.length;
  const completedTasks = tasks.filter((task) => task.status === 'done').length;
  const skippedTasks = tasks.filter((task) => task.status === 'skipped').length;
  const scheduledTasks = tasks.filter((task) => task.status !== 'skipped').length || totalTasks;

  return {
    user,
    date,
    weekStart,
    plan,
    today: {
      date,
      totalTasks,
      completedTasks,
      skippedTasks,
      totalMinutes: Math.round(tasks.reduce((sum, task) => sum + task.durationMinutes, 0) * 10) / 10,
      completedMinutes:
        Math.round(
          tasks.filter((task) => task.status === 'done').reduce((sum, task) => sum + task.durationMinutes, 0) * 10,
        ) / 10,
      adherence: scheduledTasks === 0 ? 0 : Math.round((completedTasks / scheduledTasks) * 100),
      timeRegions,
    },
    streak: streakInfo(db, user.id),
  };
}

export function buildBootstrap(db: Database, userId: string, date?: string) {
  const state = buildTodayState(db, userId, date);
  if (!state) return null;
  return {
    ...state,
    facets: getFacets(db),
    serverTime: new Date().toISOString(),
  };
}
