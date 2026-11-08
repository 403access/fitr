import { Database } from 'bun:sqlite';
import { mkdirSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const DEFAULT_DB = resolve(import.meta.dir, '../../data/fitr.sqlite');
const SCHEMA_PATH = resolve(import.meta.dir, 'schema.sql');

export function databasePath(): string {
  return process.env.FITR_DB ?? DEFAULT_DB;
}

export function createDatabase(path = databasePath()): Database {
  if (path !== ':memory:') {
    mkdirSync(dirname(path), { recursive: true });
  }
  const db = new Database(path, { create: true });
  db.exec('PRAGMA foreign_keys = ON;');
  db.exec(readFileSync(SCHEMA_PATH, 'utf8'));
  return db;
}
