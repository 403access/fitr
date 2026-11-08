import type { Database } from 'bun:sqlite';

export type Goal = 'balanced' | 'strength' | 'endurance' | 'mobility' | 'recovery';
export type Experience = 'beginner' | 'intermediate' | 'advanced';

export type UserRow = {
  id: string;
  name: string;
  goal: Goal;
  experience: Experience;
  days_per_week: number;
  session_minutes: number;
  equipment: string;
  program_start: string;
  created_at: string;
};

export type UserDTO = {
  id: string;
  name: string;
  goal: Goal;
  experience: Experience;
  daysPerWeek: number;
  sessionMinutes: number;
  equipment: string[];
  programStart: string;
};

export function toUserDTO(row: UserRow): UserDTO {
  return {
    id: row.id,
    name: row.name,
    goal: row.goal,
    experience: row.experience,
    daysPerWeek: row.days_per_week,
    sessionMinutes: row.session_minutes,
    equipment: JSON.parse(row.equipment) as string[],
    programStart: row.program_start,
  };
}

export function getUser(db: Database, id: string): UserDTO | null {
  const row = db.query<UserRow, [string]>('SELECT * FROM users WHERE id = ?').get(id);
  return row ? toUserDTO(row) : null;
}

export function ensureUser(db: Database, id = 'me'): UserDTO {
  const existing = getUser(db, id);
  if (existing) return existing;
  const start = new Date();
  start.setDate(start.getDate() - 21);
  const date = start.toISOString().slice(0, 10);
  db.run(
    `INSERT INTO users (id, name, goal, experience, days_per_week, session_minutes, equipment, program_start, created_at)
     VALUES (?, 'Alex', 'balanced', 'intermediate', 5, 45, '[]', ?, ?)`,
    [id, date, new Date().toISOString()],
  );
  return getUser(db, id)!;
}

export type ProfilePatch = {
  name?: string;
  goal?: Goal;
  experience?: Experience;
  daysPerWeek?: number;
  sessionMinutes?: number;
  equipment?: string[];
};

export function updateUser(db: Database, id: string, patch: ProfilePatch): UserDTO {
  const current = getUser(db, id);
  if (!current) throw new Error('User not found');
  db.run(
    `UPDATE users SET name = ?, goal = ?, experience = ?, days_per_week = ?, session_minutes = ?, equipment = ?
     WHERE id = ?`,
    [
      patch.name ?? current.name,
      patch.goal ?? current.goal,
      patch.experience ?? current.experience,
      patch.daysPerWeek ?? current.daysPerWeek,
      patch.sessionMinutes ?? current.sessionMinutes,
      JSON.stringify(patch.equipment ?? current.equipment),
      id,
    ],
  );
  return getUser(db, id)!;
}
