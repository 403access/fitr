import { rmSync } from 'node:fs';
import { databasePath } from '../src/db/database.ts';

const path = databasePath();
for (const suffix of ['', '-shm', '-wal']) {
  rmSync(`${path}${suffix}`, { force: true });
}
console.log(`Removed ${path}. It will be recreated and seeded on the next start.`);
