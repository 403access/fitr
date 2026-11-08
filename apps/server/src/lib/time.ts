/** Date helpers. Fitr stores local calendar dates as YYYY-MM-DD strings. */

const DAY = 86_400_000;

export function toDateString(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function parseDate(value: string): Date {
  const [y, m, d] = value.split('-').map(Number);
  if (!y || !m || !d) throw new Error(`Invalid date: ${value}`);
  return new Date(y, m - 1, d, 12, 0, 0, 0);
}

export function isValidDate(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(parseDate(value).getTime());
}

export function addDays(value: string, days: number): string {
  const date = parseDate(value);
  date.setDate(date.getDate() + days);
  return toDateString(date);
}

export function todayString(now = new Date()): string {
  return toDateString(now);
}

/** Monday-based week start. */
export function startOfWeek(value: string): string {
  const date = parseDate(value);
  const day = date.getDay(); // 0 Sun … 6 Sat
  const diff = day === 0 ? -6 : 1 - day;
  date.setDate(date.getDate() + diff);
  return toDateString(date);
}

export function startOfMonth(value: string): string {
  const date = parseDate(value);
  date.setDate(1);
  return toDateString(date);
}

export function endOfMonth(value: string): string {
  const date = parseDate(value);
  date.setMonth(date.getMonth() + 1, 0);
  return toDateString(date);
}

export function startOfYear(value: string): string {
  return `${value.slice(0, 4)}-01-01`;
}

export function endOfYear(value: string): string {
  return `${value.slice(0, 4)}-12-31`;
}

export function daysBetween(from: string, to: string): number {
  return Math.round((parseDate(to).getTime() - parseDate(from).getTime()) / DAY);
}

export function eachDay(from: string, to: string): string[] {
  const out: string[] = [];
  let cursor = from;
  while (cursor <= to) {
    out.push(cursor);
    cursor = addDays(cursor, 1);
  }
  return out;
}

export function weekDates(weekStart: string): string[] {
  return Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));
}

export function weekIndexFor(programStart: string, weekStart: string): number {
  const days = Math.max(0, daysBetween(startOfWeek(programStart), startOfWeek(weekStart)));
  return Math.floor(days / 7) + 1;
}

export function formatDuration(minutes: number): string {
  const m = Math.round(minutes);
  if (m < 60) return `${m} min`;
  const h = Math.floor(m / 60);
  const rest = m % 60;
  return rest === 0 ? `${h} h` : `${h} h ${rest} min`;
}

export function isoNow(): string {
  return new Date().toISOString();
}
