# Copilot instructions for Monev

## Build, test, and lint commands

```bash
# Install dependencies first
npm install

# Development
npm run dev
npm run dev:clean
npm run dev:reset

# Production build/run
npm run build
npm run start

# Lint
npm run lint
npx eslint src\app\api\transactions\route.ts

# Unit tests (Vitest)
npm run test
npm run test -- src\lib\validations.test.ts
npx vitest run -t "formats IDR currency by default"

# E2E tests (Playwright, uses tests/ and baseURL http://localhost:3000 by default)
npx playwright test
npx playwright test tests\login.spec.ts
npx playwright test --project=chromium tests\transactions.spec.ts
```

## High-level architecture

- **App shape:** Next.js App Router app with protected UI routes in `src\app\(protected)\...` and API handlers in `src\app\api\**\route.ts`.
- **Auth and session:** `src\auth.ts` configures NextAuth v5 (Credentials + Google). API handlers and server code use `auth()` to get `session.user.id` (string), then convert to number for DB operations.
- **Data layer:** Drizzle + SQLite. Schema lives in `src\backend\db\schema.ts`; domain queries/mutations are split across `src\backend\db\operations\*.ts` and re-exported by `operations\index.ts`.
- **DB connection model:** `getDb()` in `src\backend\db\index.ts` is a singleton (cached on `globalThis`) and enables WAL mode. Local DB defaults to `./sqlite.db`; production config uses `/app/data/sqlite.db` (`drizzle.config.prod.ts`).
- **UI/provider stack:** Root layout (`src\app\layout.tsx`) injects session providers, then protected routes apply `SecurityProvider` + `OnboardingGuard` + `ClientLayout`. `ClientLayout` adds theme/currency/i18n/toast/error-boundary wrappers and native Capacitor runtime hooks.
- **Multi-target builds:** `next.config.ts` switches output mode by env:
  - `IS_APK=true` + production build => `output: "export"` (static export for Capacitor APK)
  - Docker/normal production => `output: "standalone"`

## Key conventions in this repository

- **Language/domain defaults:** Product copy is primarily Indonesian; money formatting is IDR-first. Keep user-facing strings and financial phrasing consistent with existing Indonesian tone.
- **API route behavior:** Most endpoints follow `auth()` guard first, then JSON responses shaped like `{ success: true, data }` or `{ success: false, error }`.
- **Tenant isolation:** Queries in operations are expected to scope by `userId` (see transactions/budgets/goals/etc. patterns). Preserve that in new DB reads/writes.
- **Use the shared API client in UI:** Client components generally call `apiFetch` from `src\frontend\lib\api-client.ts` (timeout handling + APK URL rewrite rules) instead of raw `fetch`.
- **Use shared DB operation modules from routes:** API handlers import from `@/backend/db/operations` rather than embedding large SQL/Drizzle logic directly in route files.
- **Path aliases:** Use `@/*` imports (`tsconfig.json`) instead of deep relative paths.
- **I18n access pattern:** Use `I18nProvider` / `useI18n` from `@/lib/i18n` (`src\lib\i18n\index.tsx`) for translatable UI strings.
- **Feature gating:** Tier limits and entitlement checks are centralized in `src\lib\tier-gate.ts`; prefer reusing these helpers when adding gated features.

## MCP server configured for this repo

- `.vscode\mcp.json` configures the **Playwright MCP server** via `npx -y @playwright/mcp@latest`.
- Use it for browser-driven debugging and E2E triage against this app's routes and flows.
- Start the app first (`npm run dev`) so Playwright MCP actions can target the running UI.
