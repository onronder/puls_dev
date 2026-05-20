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

## Supabase

```bash
# Install CLI: https://supabase.com/docs/guides/cli
supabase start
supabase db reset            # migrations + seed
```

Migrations: `supabase/migrations/`. Seed includes Mert Teknik demo tenant + Canias mapping placeholders.

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
