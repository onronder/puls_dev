# PR11.5 — HR Growth & Performance Matrix

Reference: [11_sidebar_data_api_inventory.md](./11_sidebar_data_api_inventory.md)

## Executive summary

PR11.5 hardens **source honesty** on four HR growth routes and tightens the **only existing app-exposed mutation surface** — performance cycle create/update. It does not add schema, new HR CRUD, or make these modules fully production-real.

**Quality bar:** WithMeta + demo pills everywhere; client validation + tenant-scoped cycle updates where writes already exist.

**No migration in PR11.5.**

## Route status table

| Route | Inventory status | Real reads | Demo fallback | Mutations | PR11.5 |
|-------|------------------|------------|---------------|-----------|--------|
| `/performans` | `demo_fallback` / `mixed` | calc + performance + core | overview rich demo; cycles stub `[]` | cycle create/update | WithMeta + pills; cycle hardening |
| `/kariyer` | `demo_fallback` | employees, career_profiles, training_needs | demo fixture | none | WithMeta + pill; keep `common.soon` |
| `/egitim` | `demo_fallback` | training_needs | demo fixture | none | WithMeta + pill; keep school `common.soon` |
| `/is-degerleme` | `placeholder` | none (static empty shell) | demo fixture | none | WithMeta + demo/placeholder pills |

**Out of scope:** `/performans-parametreleri` (separate setup route).

## Adapter / table matrix

| Table | Schema | Adapter | Route usage | PR11.5 |
|-------|--------|---------|-------------|--------|
| `performance_cycles` | `puls_performance` | `fetchPerformanceCycles*`, create/update | `/performans` | read WithMeta; validate + tenant update |
| `competency_templates` | `puls_performance` | `fetchCompetencyTemplates` | `/performans` | preserve read-only |
| `competency_evaluations` | `puls_performance` | overview counts | `/performans` overview | preserve read-only |
| `career_profiles` | `puls_performance` | `fetchCareerOverview*` | `/kariyer` | WithMeta only |
| `training_needs` | `puls_performance` | `fetchTrainingOverview*`, career counts | `/egitim`, `/kariyer` | WithMeta only |

## Mutation inventory

| Operation | Adapter | App-exposed | PR11.5 |
|-----------|---------|-------------|--------|
| Create performance cycle | `createPerformanceCycle` | yes | validate input before insert |
| Update performance cycle | `updatePerformanceCycle` | yes | add `userId`, `.eq('tenant_id', …)` |
| Template CRUD | — | no | out of scope |
| Evaluation/score writes | — | no | out of scope |
| Career profile edits | — | no | out of scope |
| Training need edits | — | no | out of scope |
| Job evaluation CRUD | — | no | out of scope |

## Demo fallback inventory

| Adapter | Real empty behavior | Demo behavior | Honesty gap |
|---------|---------------------|---------------|-------------|
| `fetchPerformanceOverview` | empty metrics | rich demo overview | documented |
| `fetchPerformanceCycles` | `[]` | `[]` stub | overview may show demo while cycles empty |
| `fetchCareerOverview` | empty ladder/gaps | demo fixture | WithMeta pill |
| `fetchTrainingOverview` | empty trainings | demo fixture | WithMeta pill |
| `fetchJobEvaluationOverview` | static empty shell | demo fixture | placeholder pill when real |

## RLS / security notes

- `performance_cycles`: SELECT tenant-scoped; INSERT/UPDATE require admin + tenant match (`puls_core.is_admin()`).
- Adapters use `resolveTenantContext` + explicit `.eq('tenant_id', …)` on reads and updates.
- PR11.5 adds adapter-layer tenant filter on cycle UPDATE (defense in depth beyond RLS).
- Smoke uses service_role in rollback transaction; no permanent writes.

## Out-of-scope and follow-ups

- Performance template CRUD, KPI/evaluation/score writes
- Career profile edits, training need edits, job evaluation schema/UI
- Resolver/import/ERP, AI generation, document upload
- Align cycles demo fixture with overview demo (PR11.9 broader demo guard)
- Full performance module production-real (future PR)
- `/performans-parametreleri` WithMeta (PR11.9 or dedicated setup PR)

## Surface matrix (minimum)

| Surface | Source | Adapter | Demo | PR11.5 |
|---------|--------|---------|------|--------|
| Performance overview | calc + performance reads | `fetchPerformanceOverviewWithMeta` | fallback | WithMeta + pill |
| Performance cycles | `performance_cycles` | `fetchPerformanceCyclesWithMeta` | `[]` stub | WithMeta + validate/update |
| Career overview | core + performance joins | `fetchCareerOverviewWithMeta` | fallback | WithMeta + pill |
| Training overview | `training_needs` | `fetchTrainingOverviewWithMeta` | fallback | WithMeta + pill |
| Job evaluation | placeholder shell | `fetchJobEvaluationOverviewWithMeta` | fallback | WithMeta + pills |
