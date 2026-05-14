/**
 * Parse a Postgres connection URL for **host + database name only** (no credentials).
 * Used at startup to confirm which DB instance the API is using (M17E-9).
 */
export function parseDatabaseUrlForM17e9Log(databaseUrl: string): {
  host: string;
  database: string;
} {
  const raw = databaseUrl.trim();
  if (!raw) {
    return { host: '(empty)', database: '(empty)' };
  }
  try {
    const normalized = raw
      .replace(/^postgresql:/i, 'http:')
      .replace(/^postgres:/i, 'http:');
    const u = new URL(normalized);
    const host = u.hostname || '(unknown-host)';
    let database = (u.pathname || '/').replace(/^\//, '') || '(unknown-db)';
    const q = database.indexOf('?');
    if (q >= 0) {
      database = database.slice(0, q);
    }
    return { host, database };
  } catch {
    return { host: '(unparsed)', database: '(unparsed)' };
  }
}
