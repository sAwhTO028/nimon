// Loads `.env` for Prisma CLI (`migrate`, `generate`, etc.). Nest runtime still uses ConfigModule.
import { existsSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { join } from "node:path";
import { defineConfig } from "prisma/config";

function loadEnvFallback(envPath: string): void {
  if (!existsSync(envPath)) return;
  let raw = readFileSync(envPath, "utf8");
  if (raw.charCodeAt(0) === 0xfeff) {
    raw = raw.slice(1);
  }
  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq).trim();
    let val = trimmed.slice(eq + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    if (process.env[key] === undefined) {
      process.env[key] = val;
    }
  }
}

/** Resolves `dotenv` from this package after install; falls back if the module is missing (e.g. before first install). */
function loadEnvForPrismaCli(): void {
  const require = createRequire(join(process.cwd(), "package.json"));
  try {
    require("dotenv/config");
  } catch {
    loadEnvFallback(join(process.cwd(), ".env"));
  }
}

loadEnvForPrismaCli();

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
  },
  datasource: {
    url: process.env["DATABASE_URL"],
  },
});
