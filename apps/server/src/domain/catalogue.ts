import type { Database } from 'bun:sqlite';
import { timeRegions } from '../db/seed-data.ts';

export type ExerciseRow = {
  id: string;
  slug: string;
  name: string;
  summary: string;
  topic_id: string;
  type_id: string;
  difficulty: number;
  duration_seconds: number;
  animation: string;
  equipment: string;
  instructions: string;
  cues: string;
  benefits: string;
  breathing: string;
  default_sets: number;
  default_reps: number | null;
  default_hold_seconds: number | null;
  default_load_kg: number | null;
  rest_seconds: number;
};

type Ref = { id: string; name: string };

export type ExerciseDTO = {
  id: string;
  slug: string;
  name: string;
  summary: string;
  topic: Ref & { accent: string; icon: string };
  type: Ref;
  difficulty: number;
  durationSeconds: number;
  animation: string;
  equipment: string[];
  instructions: string[];
  cues: string[];
  benefits: string[];
  breathing: string;
  regions: Ref[];
  primaryMuscles: Ref[];
  secondaryMuscles: Ref[];
  prescription: {
    sets: number;
    reps: number | null;
    holdSeconds: number | null;
    loadKg: number | null;
    restSeconds: number;
  };
};

const EXERCISE_SELECT = `
  SELECT e.*, t.name AS topic_name, t.accent AS topic_accent, t.icon AS topic_icon,
         ty.name AS type_name
  FROM exercises e
  JOIN topics t ON t.id = e.topic_id
  JOIN exercise_types ty ON ty.id = e.type_id
`;

type JoinedExerciseRow = ExerciseRow & {
  topic_name: string;
  topic_accent: string;
  topic_icon: string;
  type_name: string;
};

function refsForExercise(db: Database, exerciseId: string): { regions: Ref[]; primary: Ref[]; secondary: Ref[] } {
  const regions = db
    .query<{ id: string; name: string }, [string]>(
      `SELECT r.id, r.name FROM exercise_regions er JOIN regions r ON r.id = er.region_id
       WHERE er.exercise_id = ? ORDER BY r.sort_order`,
    )
    .all(exerciseId);
  const muscles = db
    .query<{ id: string; name: string; role: 'primary' | 'secondary' }, [string]>(
      `SELECT m.id, m.name, em.role FROM exercise_muscles em JOIN muscles m ON m.id = em.muscle_id
       WHERE em.exercise_id = ? ORDER BY m.sort_order`,
    )
    .all(exerciseId);
  return {
    regions,
    primary: muscles.filter((m) => m.role === 'primary').map(({ id, name }) => ({ id, name })),
    secondary: muscles.filter((m) => m.role === 'secondary').map(({ id, name }) => ({ id, name })),
  };
}

export function serializeExercise(db: Database, row: JoinedExerciseRow): ExerciseDTO {
  const refs = refsForExercise(db, row.id);
  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    summary: row.summary,
    topic: {
      id: row.topic_id,
      name: row.topic_name,
      accent: row.topic_accent,
      icon: row.topic_icon,
    },
    type: { id: row.type_id, name: row.type_name },
    difficulty: row.difficulty,
    durationSeconds: row.duration_seconds,
    animation: row.animation,
    equipment: JSON.parse(row.equipment) as string[],
    instructions: JSON.parse(row.instructions) as string[],
    cues: JSON.parse(row.cues) as string[],
    benefits: JSON.parse(row.benefits) as string[],
    breathing: row.breathing,
    regions: refs.regions,
    primaryMuscles: refs.primary,
    secondaryMuscles: refs.secondary,
    prescription: {
      sets: row.default_sets,
      reps: row.default_reps,
      holdSeconds: row.default_hold_seconds,
      loadKg: row.default_load_kg,
      restSeconds: row.rest_seconds,
    },
  };
}

export type ExerciseFilters = {
  topic?: string;
  type?: string;
  region?: string;
  muscle?: string;
  q?: string;
  difficulty?: number;
};

export function listExercises(db: Database, filters: ExerciseFilters = {}): ExerciseDTO[] {
  const clauses: string[] = [];
  const params: (string | number)[] = [];

  if (filters.topic) {
    clauses.push('e.topic_id = ?');
    params.push(filters.topic);
  }
  if (filters.type) {
    clauses.push('e.type_id = ?');
    params.push(filters.type);
  }
  if (filters.region) {
    clauses.push('EXISTS (SELECT 1 FROM exercise_regions er WHERE er.exercise_id = e.id AND er.region_id = ?)');
    params.push(filters.region);
  }
  if (filters.muscle) {
    clauses.push('EXISTS (SELECT 1 FROM exercise_muscles em WHERE em.exercise_id = e.id AND em.muscle_id = ?)');
    params.push(filters.muscle);
  }
  if (filters.q) {
    clauses.push('(LOWER(e.name) LIKE ? OR LOWER(e.summary) LIKE ?)');
    const needle = `%${filters.q.toLowerCase()}%`;
    params.push(needle, needle);
  }
  if (filters.difficulty) {
    clauses.push('e.difficulty = ?');
    params.push(filters.difficulty);
  }

  const where = clauses.length ? ` WHERE ${clauses.join(' AND ')}` : '';
  const rows = db
    .query<JoinedExerciseRow, (string | number)[]>(
      `${EXERCISE_SELECT}${where} ORDER BY t.rowid, e.name`,
    )
    .all(...params);
  return rows.map((row) => serializeExercise(db, row));
}

export function getExerciseBySlug(db: Database, slug: string): ExerciseDTO | null {
  const row = db
    .query<JoinedExerciseRow, [string]>(`${EXERCISE_SELECT} WHERE e.slug = ?`)
    .get(slug);
  return row ? serializeExercise(db, row) : null;
}

export function getExerciseById(db: Database, id: string): ExerciseDTO | null {
  const row = db.query<JoinedExerciseRow, [string]>(`${EXERCISE_SELECT} WHERE e.id = ?`).get(id);
  return row ? serializeExercise(db, row) : null;
}

export function getFacets(db: Database) {
  const topics = db
    .query<{ id: string; name: string; description: string; accent: string; icon: string; count: number }, []>(
      `SELECT t.*, COUNT(e.id) AS count FROM topics t
       LEFT JOIN exercises e ON e.topic_id = t.id GROUP BY t.id ORDER BY t.rowid`,
    )
    .all();
  const types = db
    .query<{ id: string; name: string; description: string; count: number }, []>(
      `SELECT ty.*, COUNT(e.id) AS count FROM exercise_types ty
       LEFT JOIN exercises e ON e.type_id = ty.id GROUP BY ty.id ORDER BY ty.rowid`,
    )
    .all();
  const regionList = db
    .query<{ id: string; name: string; count: number }, []>(
      `SELECT r.id, r.name, COUNT(er.exercise_id) AS count FROM regions r
       LEFT JOIN exercise_regions er ON er.region_id = r.id
       GROUP BY r.id ORDER BY r.sort_order`,
    )
    .all();
  const muscleList = db
    .query<{ id: string; name: string; regionId: string; count: number }, []>(
      `SELECT m.id, m.name, m.region_id AS regionId, COUNT(em.exercise_id) AS count FROM muscles m
       LEFT JOIN exercise_muscles em ON em.muscle_id = m.id
       GROUP BY m.id ORDER BY m.sort_order`,
    )
    .all();

  return {
    topics,
    types,
    regions: regionList,
    muscles: muscleList,
    timeRegions: timeRegions.map((region) => ({ ...region })),
  };
}
