# PR13.5 — Seed Bootstrap Proof Runbook

Workflow and performance **scenario proof** layer on top of the PR13.4 Puls Sanayi baseline seed pack. Packaging proof requires **`VITE_PULS_DEMO_MODE=false`** and **`source: real`** reads — **`source: demo is not packaging proof`**.

## Principles (mandatory)

> Scenario scripts must be idempotent per target table: use `external_source='pr13_scenario'` only where the column exists; otherwise delete by deterministic PR13.5 UUID prefix or explicit fixed UUID list.

> `03_generate_workflow_scenarios.sql` may insert lifecycle event rows as historical narrative proof, but must not toggle baseline setup state unless done inside the `06` ROLLBACK RPC smoke.

> `06` lifecycle RPC smoke targets setup rows reserved outside scenario usage (no open/pending requests), or asserts idempotent `already_inactive` / `already_active` on inactive baseline rows (`ESKI-TIP`, `ESKI-KAT`).

> `05` and `06` use **conditional** psql defaults (`\if :{?var}`) so `psql -v var=…` is never overwritten; normalize with `NULLIF(:'var', '')`; skip when unset, empty string, or zero UUID.

> Public bridge (`public.user_tenants` / `public.user_roles`) runs **only** when `puls_core.tenants.legacy_public_tenant_id` is non-null — never use `puls_core.tenants.id` as the public tenant id.

> `03` recomputes affected `leave_balances.pending_days` / `used_days` deterministically for PR13.5 scenario leave rows; `07` asserts no negative `remaining_days`.

Additional guardrails:

- Production-facing product behavior must not depend on embedded TypeScript business fixtures.
- Canias: **metadata seed only**; no runtime; no automatic destructive ERP writes.
- PR13.4 CSV/manifest baseline is **unchanged**; PR13.5 adds scenario + proof SQL only.
- SQL Editor cannot read local CSV paths — use psql from pack directory.

## Two-layer proof model

Two-layer proof separates narrative INSERT from RPC mutation proof (`two-layer proof` terminology).

| Layer | Scripts | Purpose |
|-------|---------|---------|
| Narrative / calc proof | `03`, `04` | Direct INSERT scenario rows for queues, KPIs, historical labels |
| Auth binding | `05` | Template: link Dashboard auth UUIDs → `puls_core.employees.user_id` |
| RPC proof | `06` | Transactional JWT smoke + lifecycle RPCs inside `BEGIN … ROLLBACK` |
| Packaging gate | `07` | Baseline + scenario + `puls_calc.*` + source-aware checks |

Scenario INSERTs are **not** mutation API proof. `06` proves RPCs when linked users exist; otherwise `RAISE NOTICE` and skip honestly.

## Load order

```
00_reset_puls_sanayi_seed.sql
01_load_puls_sanayi_seed.sql
02_validate_puls_sanayi_seed.sql
03_generate_workflow_scenarios.sql
04_generate_performance_scenarios.sql
07_validate_packaging_proof.sql

(optional, after Dashboard auth users)
05_link_auth_personas_template.sql
06_jwt_mutation_proof_smoke.sql
```

From pack root:

```bash
cd supabase/seed/puls-sanayi-v1
export DATABASE_URL='postgresql://...'
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/00_reset_puls_sanayi_seed.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/01_load_puls_sanayi_seed.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/03_generate_workflow_scenarios.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/04_generate_performance_scenarios.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/07_validate_packaging_proof.sql
```

Or use [`scripts/run-13-puls-sanayi-proof.sh`](../../scripts/run-13-puls-sanayi-proof.sh).

## Inspect-first reference (Puls Sanayi tenant)

**Tenant UUID:** `a0000001-0001-4001-8001-000000000001` (no `legacy_public_tenant_id` → public bridge skipped).

| Artifact | UUID / code |
|----------|-------------|
| CEO / superadmin (PS-001) | `a0000006-0006-4006-8006-000000000001` |
| hr_admin (PS-006) | `a0000006-0006-4006-8006-000000000006` |
| Manager Satış (PS-021) | `a0000006-0006-4006-8006-000000000021` |
| Employee IC (PS-023) | `a0000006-0006-4006-8006-000000000023` |
| Active cycle 2026 | `a0000020-0020-4020-8020-000000000002` |
| Leave policy LEAVE-STD | `a0000013-0013-4013-8013-000000000001` |
| Expense policy EXP-STD | `a0000013-0013-4013-8013-000000000002` |
| Leave type YILLIK | `a0000012-0012-4012-8012-000000000001` |
| Inactive ESKI-TIP | `a0000012-0012-4012-8012-000000000008` |
| Lifecycle-smoke-reserved UCRETSIZ | `a0000012-0012-4012-8012-000000000006` |
| Expense YEMEK | `a0000015-0015-4015-8015-000000000001` |
| Inactive ESKI-KAT | `a0000015-0015-4015-8015-000000000010` |
| Lifecycle-smoke-reserved HED | `a0000015-0015-4015-8015-000000000008` |
| Competency templates | `a0000021-0021-4021-8021-000000000001` … `010` |

**Scenario UUID blocks:** `b0000003-*` workflow, `b0000004-*` performance.

**Lifecycle RPC signatures (read migrations):**

- Final leave: `20260525181200_puls_workflow_leave_type_lifecycle_audit_timestamp_fix.sql`
- Expense category: `20260525174000_puls_workflow_expense_category_lifecycle_audit.sql`
- Create/decide: `20260524153000_puls_workflow_policy_engine.sql`

## Auth template (05 / 06)

1. Create auth users in Supabase Dashboard — **do not** store passwords in repo.
2. Run `05` with psql vars:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -v admin_user_id='<uuid>' \
  -v hr_admin_user_id='<uuid>' \
  -v manager_user_id='<uuid>' \
  -v employee_user_id='<uuid>' \
  -f sql/05_link_auth_personas_template.sql
```

3. Optional `06` JWT smoke (rolls back all mutations). Lifecycle RPC proof requires `admin_user_id` or `hr_admin_user_id` (manager JWT is insufficient):

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -v employee_user_id='<uuid>' \
  -v manager_user_id='<uuid>' \
  -v admin_user_id='<uuid>' \
  -v hr_admin_user_id='<uuid>' \
  -f sql/06_jwt_mutation_proof_smoke.sql
```

## Route packaging proof

See [`13_route_packaging_proof_matrix.md`](./13_route_packaging_proof_matrix.md) for all 20 PR12 routes, expected `source: real` posture, and honest gaps.

## Validation

```bash
./scripts/verify-13-seed-bootstrap-proof.sh HEAD
node scripts/check-sensitive-grep.mjs
pnpm check-i18n && pnpm test && pnpm build
```
