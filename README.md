# PULS AI Coach — puls_dev

Mobile-first Self-HR platform for Turkish SMBs. TanStack Start + Capacitor + Supabase + Railway.

## Stack

- **Frontend:** TanStack Start, React 19, Tailwind v4, shadcn-style UI
- **Mobile:** Capacitor v8 (iOS + Android + Web)
- **BaaS:** Supabase (Frankfurt) — auth, Postgres, RLS, storage, vault, audit
- **Services:** Railway — llm-gateway, erp-connector (Canias)
- **Deploy:** Vercel (app), Netlify (marketing site external)

## Quick start

```bash
pnpm install
cp .env.example .env.local   # fill Supabase keys locally — never commit
pnpm dev                     # http://localhost:3000
```

Run `cp .env.example .env.local` in the **project root** (same folder as `package.json`) — in Cursor’s integrated terminal or your Mac Terminal after cloning the repo.

If `pnpm install` fails with `ERR_PNPM_MINIMUM_RELEASE_AGE_VIOLATION` (pnpm 11 default), run `git pull` to get `pnpm-workspace.yaml`, or temporarily: `pnpm install --config.minimum-release-age=0`.

## Existing Supabase (Lovable auth)

If you already have a Lovable test project with `profiles`, `user_tenants`, `user_roles`, and `audit_log`:

1. Fill `.env.local` with that project’s URL + anon key (do **not** paste keys in chat).
2. Link CLI: `supabase link --project-ref <your-ref>`
3. Apply additive migration: `supabase db push` (only `20260520130000_puls_on_lovable_auth.sql`)
4. If a previous push failed on `foundation.sql`, either revert the phantom record or pull the stub:

```bash
# Option A — revert phantom applied record (simplest)
supabase migration repair 20260520120000 --status reverted
supabase db push

# Option B — after git pull, stub file 20260520120000_foundation_skipped.sql syncs history
supabase db push
```

5. Greenfield full SQL: `supabase/migrations-greenfield/20260520120000_foundation.sql`
6. Audit schema: `pnpm audit:supabase`

After migration, add `puls_vault` and `puls_audit` to **Supabase Dashboard → Project Settings → API → Exposed schemas** (in addition to `public`).

Existing `auth.users` + `profiles` + `user_tenants` continue to work. Login uses Supabase Auth; persona is resolved from `employees` or `user_roles`.

## Supabase

```bash
# Install CLI: https://supabase.com/docs/guides/cli
supabase start
supabase db reset            # Lovable compat migration only (see below)
```

| Scenario | Migrations folder | Notes |
|---|---|---|
| **Existing Lovable DB** | `supabase/migrations/` | `db push` — product tables on auth schema |
| **Greenfield local** | `migrations-greenfield/` + seed | Copy foundation SQL manually or use local reset workflow |

Migrations: `supabase/migrations/`. Greenfield-only: `supabase/migrations-greenfield/`. Seed includes Mert Teknik demo tenant + Canias mapping placeholders.

## Environment variables

| Variable | Where | Notes |
|---|---|---|
| `VITE_SUPABASE_URL` | `.env.local`, Vercel | Public |
| `VITE_SUPABASE_ANON_KEY` | `.env.local`, Vercel | Public anon key only |
| `SUPABASE_SERVICE_ROLE_KEY` | Railway, CI secrets | **Never** in frontend |
| `ANTHROPIC_API_KEY` | Railway llm-gateway | Server only |

**Do not paste production keys in chat or commit them.** Use Cursor/Vercel/Railway secret stores.

## Capacitor

```bash
pnpm build
pnpm exec cap sync ios
pnpm exec cap sync android
```

## Scripts

| Command | Description |
|---|---|
| `pnpm dev` | Dev server :3000 |
| `pnpm build` | Production build |
| `pnpm typecheck` | `tsc --noEmit` |
| `pnpm lint` | ESLint |
| `pnpm check-i18n` | tr/en key parity |
| `pnpm test:e2e` | Playwright smoke (375/768/1280) |

## Branch convention

`feature/{module}/{short-description}` — e.g. `feature/foundation/tanstack-scaffold`

## Docs

- `V1 Dökümanlar/` — Mimari v1.0, UX Audit, Veri Sözlüğü (source of truth)
- `Cursor_Composer_Baslangic_Prompt.md` — Sprint guide

## Sprint-1 scope

Foundation scaffold: auth skeleton, layout (header/sidebar/bottom tab/floating AI), design tokens, Supabase foundation migration, ERP mapping tables, Railway service skeletons, CI.
