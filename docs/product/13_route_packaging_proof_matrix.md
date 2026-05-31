# PR13.5 — Route Packaging Proof Matrix

Maps all **20 PR12 routes** for Puls Sanayi DB-backed packaging proof with **`VITE_PULS_DEMO_MODE=false`**. Expected adapter posture: **`source: real`**.

| Route | Adapter / view | Baseline proof (PR13.4) | Scenario proof (PR13.5) | Auth / persona | Source posture | Accepted gap |
|-------|----------------|-------------------------|-------------------------|----------------|----------------|--------------|
| `/dashboard` | `puls_calc.dashboard_overview` | 120 employees, org counts | Pending leave/expense from `03` | Any linked | `source: real` | — |
| `/sirket-kurulum` | setup adapters | Tenant, legal entity, locations | — | hr_admin | `source: real` | — |
| `/calisanlar` | `puls_calc.employee_list_overview` | 120 employees | — | hr_admin | `source: real` | — |
| `/departmanlar` | org setup CRUD | 12 departments, imported rows | PULS-owned CRUD via app | hr_admin | `source: real` | Imported read-only |
| `/pozisyonlar` | org setup CRUD | 36 positions | — | hr_admin | `source: real` | Imported read-only |
| `/izin-tanimlari` | leave types + lifecycle events | 8 leave types incl. ESKI-TIP | Historical lifecycle events in `03` | hr_admin | `source: real` | RPC toggle in `06` only |
| `/izin` | `puls_calc.leave_overview` | leave balances | 30 scenario leave_requests | employee + manager | `source: real` | — |
| `/masraf-kategorileri` | expense categories + lifecycle | 10 categories incl. ESKI-KAT | Historical lifecycle events in `03` | hr_admin | `source: real` | RPC toggle in `06` only |
| `/masraf` | `puls_calc.expense_overview` | categories + policies | 30 scenario expense_claims | employee + manager | `source: real` | — |
| `/performans` | `puls_calc.performance_overview` | cycles, templates | 45 scores + 45 evals in `04` | manager | `source: real` | — |
| `/performans-parametreleri` | performance params | templates, weights, bands | KPI rows in `04` | hr_admin | `source: real` | — |
| `/kariyer` | career profiles | 25 career_profiles baseline | — | hr_admin | `source: real` | — |
| `/egitim` | training needs | 30 training_needs baseline | — | hr_admin | `source: real` | — |
| `/is-degerleme` | placeholder | — | — | — | `source: real` | Placeholder / future |
| `/sozlesmeler` | `puls_calc.contracts_overview` | 15–30 contracts | risk variety baseline | hr_admin | `source: real` | — |
| `/profil` | account readiness | employee row | persona link via `05` | linked employee | `source: real` | incomplete-setup edge optional |
| `/ayarlar` | settings shell | tenant metadata | — | admin | `source: real` | — |
| `/erp` | ERP readiness | Canias inactive + mappings | source_namespaces proof in `07` | hr_admin | `source: real` | No Canias runtime |
| `/ai-koc` | AI coach context readiness | PR13.4–13.5A calc + workflow context | — | any | `source: real` | Teaser — DB context readiness (PR13.6); no live chat |
| `/menu` | `puls_calc.menu_overview` | menu shell | — | any | `source: real` | Shell exception (no demo pill) |

## Honest exceptions

- **`/ai-koc`** — DB context readiness (PR13.6); teaser with no live chat; no embedded TS business fixtures on real path.
- **`/is-degerleme`** — placeholder/future module.
- **`/menu`** — shell exception; no demo pill when demo mode off.
- **CRM / SDK / real-time sync** — future; out of PR13.5 scope.

## North star checklist

- [ ] `00_reset → 01_load → 03 → 04 → 07` passes on target DB
- [ ] `VITE_PULS_DEMO_MODE=false` for manual route walkthrough
- [ ] No `source: demo` in assignment tables (`07` guard)
- [ ] Optional: `05` + `06` with Dashboard auth UUIDs for RPC proof
