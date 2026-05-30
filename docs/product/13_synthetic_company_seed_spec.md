# PR13.3 — Synthetic Company Seed Specification

V1 DB-backed synthetic company specification for packaging proof: a realistic **120-employee** Turkish SME demo tenant seeded into `puls_*` base tables — not embedded TypeScript fixtures.

**Documentation-only.** PR13.3 specifies the data model, volumes, personas, and acceptance gates. PR13.4 produces CSV/SQL artifacts; PR13.5 proves bootstrap, reset, and route smoke.

Production-facing product behavior must not depend on embedded TypeScript business fixtures.

The canonical V1 demo company is DB-backed, source-aware, resettable, and large enough to exercise real product workflows.

## Executive summary

| Attribute | Specification |
|-----------|---------------|
| Canonical tenant | **Puls Sanayi A.Ş.** — single demo company for V1 packaging proof |
| Employee count | Exactly **120 employees** |
| Data posture | **DB-backed**, **source-aware**, resettable |
| Proof gate | `VITE_PULS_DEMO_MODE=false` (or unset); `source: real` on core routes — **`source: demo is not packaging proof`** |
| Canias | Metadata seed only — **no Canias runtime** in PR13.3–13.5 |
| Embedded TS | Not packaging proof; may remain dev fallback until PR13.5 retires P0 paths |

PR13.3 **extends** PR13.1 inventory and PR13.2 retirement plan; it **does not replace** them.

### Historical legacy fixture name

**Mert Teknik** / **Mert Teknik A.Ş.** appears in pre-PR13.3 smoke SQL, [`../specs/07-supabase-demo-data-ihtiyaclari.md`](../specs/07-supabase-demo-data-ihtiyaclari.md), and embedded demo references. That name is a **historical legacy fixture name only** — not the canonical V1 demo tenant. PR13.4–13.5 artifacts seed **Puls Sanayi A.Ş.**; legacy Mert Teknik smoke is superseded in PR13.5.

## Company identity

| Field | Value |
|-------|-------|
| Legal / display name | **Puls Sanayi A.Ş.** |
| Sector | Industrial equipment manufacturing + field service |
| HQ | İstanbul (Genel Müdürlük, Finans, İK, Satış, Pazarlama, BT, Ar-Ge) |
| Production | Bursa (Operasyon / Üretim, Kalite / İSG, Satınalma) |
| Sales / service | İzmir (Satış field team subset, Müşteri Operasyonları, Lojistik hub) |
| ERP posture | Canias master-data **import candidate** — inactive connection + sample mappings (**metadata seed only**) |
| CRM | Future — not V1 |

These three sites are **required seeded proof**, not narrative-only: PR13.4 must seed **puls_core.locations** (3 rows), **puls_core.legal_entities** (1 row), and **puls_core.employee_location_assignments** (120 rows) per manifest.

## Employee scale

Exactly **120 employees** across 12 departments:

| Department | Count |
|------------|------:|
| Genel Müdürlük | 4 |
| İnsan Kaynakları | 6 |
| Finans & Muhasebe | 10 |
| Satış | 16 |
| Pazarlama | 6 |
| Operasyon / Üretim | 32 |
| Satınalma | 8 |
| Lojistik & Depo | 12 |
| Kalite / İSG | 8 |
| BT & Dijital | 7 |
| Ar-Ge / Proje | 7 |
| Müşteri Operasyonları | 4 |
| **Toplam** | **120** |

## Organization hierarchy

- **CEO / Genel Müdür** — apex of reporting tree (no manager)
- **5–7 director-level** roles (department heads + functional directors)
- **12–18 manager / team lead** roles across operations, sales, and support functions
- **Reporting depth ≥ 4 levels** from CEO to individual contributor
- **119+ reporting lines** in `puls_core.employee_reporting_lines` — every employee has a manager except CEO and explicitly exempted personas
- Span of control realistic for Turkish mid-market manufacturing (typical 5–12 ICs per manager in production; tighter in HQ)

## Position model

- **35–50 positions** in `puls_core.positions` with norm headcount metadata where schema supports it
- Every employee linked to exactly one **department** + one **position**
- Mix of **PULS-owned** positions (editable) and **imported/source-owned** examples (read-only in UI)
- Titles realistic for sector: Üretim Operatörü, Satış Mühendisi, İK Uzmanı, Finans Müdürü, Kalite Kontrol Uzmanı, vb.

## Persona accounts

Minimum auth-linked personas for packaging walkthrough (bootstrap runbook in PR13.5):

| Persona | Role | Purpose |
|---------|------|---------|
| Admin / owner | Tenant admin | Full setup, org CRUD, ERP metadata view |
| HR admin | İK yöneticisi | Leave types, policies, employee directory |
| Finance / admin | Finans | Expense categories, cost center readiness |
| Manager approver | Departman müdürü | Pending leave/expense approvals |
| Regular employee | IC | Leave/expense create, profile |
| Incomplete-setup edge (optional) | Auth user in tenant without employee link | Honest `tenant_without_employee` UX if tested |

**Persona ↔ employee mapping:** All linked personas **except** the optional incomplete-setup edge map to seeded `puls_core.employees` rows linked to auth via PR13.5 bootstrap — not embedded demo. The incomplete-setup edge is **`user_tenants` / auth membership without `employees.user_id`** and **does not count toward the 120 employees**.

## Source ownership

Demo tenant must prove **source-aware mixed CRUD**:

| Source class | Examples | UI behavior |
|--------------|----------|-------------|
| PULS-owned | Most departments, positions, cost centers, leave types, categories | Create/update allowed per adapter contracts |
| Canias / imported | Subset of departments, positions, cost centers | Read-only; identity via `puls_integration.entity_identity_map` |
| Mixed CRUD proof | `/departmanlar`, `/pozisyonlar`, `/masraf-kategorileri` cost-center panel | Editable PULS rows alongside imported rows |

**Canias boundary:** seed inactive `puls_integration.erp_connections` row + `erp_field_mappings` + `source_namespaces` + identity-map rows — **metadata seed only**. **No automatic destructive ERP writes.** Runtime connector is **PR13.7**.

## Data realism rules

- **Turkish synthetic names** — no real individuals
- Realistic job titles aligned to department and position
- Hire dates spread over **0–12 years** relative to seed anchor date
- Salaries optional/sensitive — **do not seed** unless schema requires for calc views
- **No real personal data**, credentials, or production UUIDs
- UUIDs **deterministic per runbook** (PR13.4) or generated at bootstrap — never copied from production
- Email domains use `@puls-sanayi.demo` or equivalent synthetic domain

## Data volume targets (baseline seed)

See [`13_seed_table_coverage_manifest.md`](./13_seed_table_coverage_manifest.md) for full object-level row targets. Summary minimums:

| Domain | Target |
|--------|--------|
| Tenants | 1 (`Puls Sanayi A.Ş.`) |
| Employees | 120 |
| Departments | 12 |
| Locations | 3 (İstanbul HQ, Bursa production, İzmir sales/service) |
| Employee–location assignments | 120 (every seeded employee assigned to one site) |
| Legal entity | 1 (Puls Sanayi A.Ş.) |
| Positions | 35–50 |
| Cost centers | 12–20 |
| Employee–cost-center assignments | 120 |
| Reporting lines | 119+ |
| Leave types | 6–10 |
| Leave balances | 120+ |
| ERP connection | 1 inactive Canias |
| ERP field mappings | 10–25 |

Workflow narrative rows (leave requests, expense claims, approval requests) are **required scenario-generated** — see [`13_seed_scenario_generation_spec.md`](./13_seed_scenario_generation_spec.md).

## Acceptance criteria

Packaging signoff (PR13.5) requires:

1. **`VITE_PULS_DEMO_MODE=false`** (or unset in proof environment)
2. DB seeded per this spec + PR13.4 artifacts
3. Every main route has **meaningful DB-backed data** or **honest empty-ok** state per completeness class
4. Core packaging walkthrough shows **`source: real`** — no demo pill on P0/P1 surfaces
5. **No Canias runtime** — ERP screen shows metadata/readiness only
6. Reset/bootstrap reproduces identical tenant state from artifacts

## PR13.4–13.5 handoff

| PR | Delivers |
|----|----------|
| **PR13.4** | Importable CSV/SQL pack implementing this spec against `puls_*` base tables |
| **PR13.5** | Bootstrap, reset, scenario scripts, route smoke with demo mode off |

## References

- [`13_feature_db_coverage_inventory.md`](./13_feature_db_coverage_inventory.md)
- [`13_db_table_completeness_classes.md`](./13_db_table_completeness_classes.md)
- [`13_embedded_demo_retirement_plan.md`](./13_embedded_demo_retirement_plan.md)
- [`13_packaging_proof_demo_guardrails.md`](./13_packaging_proof_demo_guardrails.md)
- [`13_seed_table_coverage_manifest.md`](./13_seed_table_coverage_manifest.md)
- [`13_seed_scenario_generation_spec.md`](./13_seed_scenario_generation_spec.md)
- [`13_seed_ai_context_manifest.md`](./13_seed_ai_context_manifest.md)
