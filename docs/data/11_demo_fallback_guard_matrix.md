# PR11.9 — Demo Fallback Guard Matrix

Reference: [11_sidebar_data_api_inventory.md](./11_sidebar_data_api_inventory.md)

## Executive summary

PR11.9 closes the PR11 demo-masking risk: demo fallback is allowed only when explicitly enabled and never silently presents demo data as production completeness in production builds.

**Quality bar:** bounded demo via `source: 'demo'` + optional `fallbackReason`; production-safe env guard.

**No migration in PR11.9. No SQL smoke.**

## Demo-mode rules

| Condition | Demo fallback |
|-----------|---------------|
| `VITE_PULS_DEMO_MODE` false/missing | Off |
| Dev/test + demo flag truthy | On when real empty/error |
| Production build (`PROD === true`) + demo flag truthy | **Blocked** by default |
| Production + `VITE_PULS_ALLOW_DEMO_FALLBACK_IN_PROD=true` | Explicit override only |

Production detection uses **strict** `env.PROD === true` (Vite parity). String `"true"` is not treated as production.

## resolveAdapterData* behavior

| Outcome | source | status | fallbackReason |
|---------|--------|--------|----------------|
| Real success | `real` | `success` | — |
| Real empty, demo off | `real` | `empty` | — |
| Real empty, demo on | `demo` | `success` | `empty` |
| Real error, demo off | `real` | `error` | — |
| Real error, demo on | `demo` | `success` | `error` |

`fallbackReason` is additive metadata; routes are not required to display it.

## PR11.8 preservation

`isProfileOverviewEmpty` returns true only for `accountLinkStatus === 'no_tenant'`. `tenant_without_employee` stays real and must not demo-mask when production guard is active.

## Route coverage

| Route | PR11.9 |
|-------|--------|
| PR11.1–11.8 (dashboard, profil, contracts, leave, HR growth, employees, etc.) | Already has WithMeta + demo pill |
| `/masraf` | `fetchExpenseOverviewWithMeta` + `DemoSourcePill` |
| `/masraf-kategorileri` | categories + cost-center WithMeta + pill |
| `/departmanlar`, `/pozisyonlar` | existing org WithMeta + page pill |
| `/erp`, `/ayarlar`, `/ai-koc`, `/performans-parametreleri` | new WithMeta + pill |
| `/sirket-kurulum` | company WithMeta + pill (**company source only**) |
| `/menu` | **Exception** — mobile shell; no WithMeta/pill |

### `/sirket-kurulum` pill semantics

Demo pill reflects **company overview** WithMeta source only. The setup readiness dashboard composite may remain real/unknown — the pill is not a source indicator for that section.

## Inline demo notes (documented, not fixed)

- Performance cycles demo returns `[]` while overview may show rich demo metrics (PR11.5)
- Request creation readiness uses internal demo composer; explicit via existing WithMeta

## Mutation inventory

PR11.9 adds read-path guards only. No new CRUD, ERP sync, or resolver/import writes.

## Follow-ups

- PR12 Swagger/OpenAPI inventory
- Optional UI surfacing of `fallbackReason` for diagnostics
