# Routes

- `/` → `apps/web/app/page.tsx`: login state, school dashboard and role-oriented collections.
- `/api/[...path]` → `apps/web/app/api/[...path]/route.ts`: authenticated proxy to FastAPI at `API_URL`.
