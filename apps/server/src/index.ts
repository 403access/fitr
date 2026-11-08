import { createApp } from './app.ts';
import { createDatabase, databasePath } from './db/database.ts';
import { demoCounts, seedDatabase } from './db/seed.ts';

const port = Number(process.env.PORT ?? 8787);
const db = createDatabase();
seedDatabase(db);

const app = createApp(db);
const counts = demoCounts(db);

const server = Bun.serve({
  port,
  hostname: '0.0.0.0',
  fetch: app.fetch,
});

console.log(`\n  Fitr API  ▸  http://localhost:${server.port}`);
console.log(`  database  ▸  ${databasePath()}`);
console.log(`  catalogue ▸  ${counts.exercises} exercises · ${counts.tasks} seeded tasks\n`);

const shutdown = () => {
  server.stop();
  db.close();
  process.exit(0);
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
