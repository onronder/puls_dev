# PR14.6 — Authenticated E2E Gate

PR14.6 turns authenticated browser stabilization into an explicit quality gate. It does not change product behavior or connector runtime; it makes live login coverage available when CI has the required repository secrets.

## Product Claim

Authenticated e2e is the next quality gate before connector setup persistence.

Connector setup persistence stays future until connector runtime and credential boundaries are explicit.

E2E credentials must come from GitHub repository secrets, never from repo files.

E2E_BASE_URL points to live Vercel for remote auth smoke.

E2E_REQUIRE_AUTH=true makes authenticated specs fail instead of skip.

No runtime sync, no credentials, and no ERP writes are introduced in PR14.6.

## Why Not Connector Persistence Yet

Persisting a selected provider before a real connector boundary exists would create product ambiguity:

| Question | Current answer |
|----------|----------------|
| Does selecting Canias create connector metadata? | No; it is local preview only |
| Are credential capture and storage designed? | Not yet; future connector boundary |
| Can PULS sync or write to ERP? | No; runtime and writeback remain closed |
| What should be proven now? | Login, redirect, role mode, route stability, and no-connector/seeded tenant posture |

## E2E Modes

| Mode | Command | Server target | Auth behavior |
|------|---------|---------------|---------------|
| Anonymous smoke | `pnpm run test:e2e` | Local dev server | Authenticated tests skip when secrets are absent |
| Required authenticated smoke | `pnpm run test:e2e:auth` | Uses `E2E_BASE_URL` when provided | Authenticated tests fail if `E2E_EMAIL` or `E2E_PASSWORD` is absent |
| CI live auth smoke | `playwright-authenticated` job | `https://puls-dev.vercel.app` | Runs only when repository secrets are configured; otherwise emits notice |

## Required Repository Secrets

| Secret | Purpose |
|--------|---------|
| `E2E_EMAIL` | Authenticated smoke user |
| `E2E_PASSWORD` | Authenticated smoke user secret |
| `E2E_EMPLOYEE_EMAIL` | Optional employee-only route guard user |
| `E2E_EMPLOYEE_PASSWORD` | Optional employee-only route guard secret |

Recommended first user: a stable seeded Puls Teknik admin or HR persona. Connector Lab can be added later as a second authenticated project once route expectations are split by tenant posture.

The default authenticated user may be an admin, HR, manager, or connector operator. Route checks that depend on an employee-only persona must use the optional employee secrets; otherwise they skip instead of treating admin setup access as a failure.

## Acceptance

- Local anonymous e2e continues to run without repository secrets.
- CI can run authenticated e2e against the live Vercel deployment when secrets are configured.
- Authenticated specs no longer silently skip when `E2E_REQUIRE_AUTH=true`.
- The Playwright config supports an external `E2E_BASE_URL` without starting the local dev server.
- The CI job does not expose secret values in logs.
- No migrations, seed CSV/manifest, connector runtime, credential storage flow, or ERP write path is added.
