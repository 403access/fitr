import { resolve } from 'node:path';
import { createDatabase } from '../src/db/database.ts';
import { seedDatabase } from '../src/db/seed.ts';
import { getFacets, listExercises } from '../src/domain/catalogue.ts';

/**
 * Mirrors the server catalogue into the iOS bundle so the app can browse
 * exercises before it has ever reached the API.
 */
const db = createDatabase(':memory:');
seedDatabase(db);

const payload = {
  generatedAt: new Date().toISOString(),
  facets: getFacets(db),
  exercises: listExercises(db),
};

const out = resolve(import.meta.dir, '../../../apps/ios/Fitr/Resources/catalog.json');
await Bun.write(out, `${JSON.stringify(payload, null, 2)}\n`);
console.log(`Exported ${payload.exercises.length} exercises to ${out}`);
db.close();
