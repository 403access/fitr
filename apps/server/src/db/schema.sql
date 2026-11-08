PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
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

CREATE TABLE IF NOT EXISTS topics (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  accent TEXT NOT NULL,
  icon TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS exercise_types (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS regions (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS muscles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  region_id TEXT NOT NULL REFERENCES regions(id),
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS exercises (
  id TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  summary TEXT NOT NULL,
  topic_id TEXT NOT NULL REFERENCES topics(id),
  type_id TEXT NOT NULL REFERENCES exercise_types(id),
  difficulty INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL,
  animation TEXT NOT NULL,
  equipment TEXT NOT NULL DEFAULT '[]',
  instructions TEXT NOT NULL DEFAULT '[]',
  cues TEXT NOT NULL DEFAULT '[]',
  benefits TEXT NOT NULL DEFAULT '[]',
  breathing TEXT NOT NULL,
  default_sets INTEGER NOT NULL DEFAULT 2,
  default_reps INTEGER,
  default_hold_seconds INTEGER,
  default_load_kg REAL,
  rest_seconds INTEGER NOT NULL DEFAULT 45,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS exercise_regions (
  exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  region_id TEXT NOT NULL REFERENCES regions(id),
  PRIMARY KEY (exercise_id, region_id)
);

CREATE TABLE IF NOT EXISTS exercise_muscles (
  exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  muscle_id TEXT NOT NULL REFERENCES muscles(id),
  role TEXT NOT NULL CHECK (role IN ('primary', 'secondary')),
  PRIMARY KEY (exercise_id, muscle_id, role)
);

CREATE TABLE IF NOT EXISTS plans (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  week_start TEXT NOT NULL,
  week_index INTEGER NOT NULL,
  focus TEXT NOT NULL,
  volume_multiplier REAL NOT NULL,
  intensity_multiplier REAL NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE (user_id, week_start)
);

CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  plan_id TEXT NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id),
  date TEXT NOT NULL,
  time_region TEXT NOT NULL,
  order_index INTEGER NOT NULL,
  exercise_id TEXT NOT NULL REFERENCES exercises(id),
  sets INTEGER NOT NULL,
  reps INTEGER,
  hold_seconds INTEGER,
  rest_seconds INTEGER NOT NULL,
  load_kg REAL,
  duration_minutes REAL NOT NULL,
  target_note TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'done', 'skipped')),
  completed_at TEXT,
  actual_reps INTEGER,
  actual_hold_seconds INTEGER,
  actual_load_kg REAL,
  effort INTEGER,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tasks_date ON tasks (user_id, date);
CREATE INDEX IF NOT EXISTS idx_tasks_plan ON tasks (plan_id);
CREATE INDEX IF NOT EXISTS idx_tasks_exercise ON tasks (user_id, exercise_id);
CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks (user_id, completed_at);
