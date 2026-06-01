# PR13.9 — Remote Puls Teknik Tenant Proof

PR13.9 is the remote development proof after PR13.8 local signoff. It repeats the merged PR13.4-PR13.8 proof stack against the remote Supabase/Postgres project using a separate Puls Teknik A.S. demo tenant posture.

## Scope

In scope:

- Remote development Supabase/Postgres proof using `psql`.
- PR13 fixed proof tenant labeled as Puls Teknik A.S. through a SQL overlay.
- Mandatory remote auth persona binding and JWT/RPC smoke via `05` and `06`.
- Sanitized remote proof results.

Out of scope:

- Production customer data.
- Canias runtime, ERP writes, Railway deployment, live AI, LLM calls, or connector execution.
- `src/**`, migrations, seed CSV, `manifest.json`, package or OpenAPI changes.
- Committing `.env*`, passwords, service-role keys, auth UUID values, or raw secret-bearing logs.

## Assumptions And Tradeoffs

The PR13.4 seed pack is deterministic and tenant-scoped to `a0000001-0001-4001-8001-000000000001`. PR13.9 does not rewrite seed CSVs or generate a second cloned UUID space. Instead, the remote proof loads that fixed proof tenant and applies `10_apply_puls_teknik_remote_posture.sql` to label it as Puls Teknik A.S.

This is the simplest honest proof for the current stage:

- Existing remote tenants, such as Mert Teknik, must not be modified.
- Puls Teknik A.S. is a synthetic remote development tenant, not live customer data.
- The business dataset remains the PR13 proof dataset; only the tenant identity posture is overlaid.
- A future customer import or true multi-tenant clone can be designed after real customer model inputs exist.

## Remote Inspect Snapshot

Initial read-only inspect on 2026-06-01 found:

| Check | Result |
|-------|--------|
| Remote Postgres connection | Passed |
| Server version | PostgreSQL 17.6 |
| PULS schemas | Present: `puls_core`, `puls_workflow`, `puls_performance`, `puls_integration`, `puls_calc`, `puls_vault` |
| Migration table | Present, 31 migrations |
| Existing remote tenant count | 1 |
| Existing tenant | Mert Teknik |
| PR13 fixed proof tenant | Absent |
| Target demo auth users | Not present at inspect time |

## Required Auth Personas

Create remote Supabase Auth users before running the full proof:

| Env var | Suggested email | Purpose |
|---------|-----------------|---------|
| `admin_user_id` | `admin@puls.demo` | Admin/settings and lifecycle smoke |
| `hr_admin_user_id` | `ik@puls.demo` | HR admin fallback for lifecycle smoke |
| `manager_user_id` | `yonetici@puls.demo` | Manager approval proof |
| `employee_user_id` | `calisan@puls.demo` | Leave/expense/profile proof |
| `incomplete_setup_user_id` | `eksik-kurulum@puls.demo` | Optional incomplete setup edge |

Do not paste passwords or UUID values into committed docs. Export UUIDs only in the local shell.

## Required Runner

From the repo root:

```bash
export ENV_FILE='/Users/onuronder/Documents/puls_dev/.env.local'
export REMOTE_PROOF_CONFIRM='PULS_TEKNIK_REMOTE_PROOF'
export admin_user_id='...'
export hr_admin_user_id='...'
export manager_user_id='...'
export employee_user_id='...'
# optional:
# export incomplete_setup_user_id='...'

./scripts/run-13-remote-puls-teknik-proof.sh
```

If `DATABASE_URL` contains raw special characters in the password, either URL-encode the password or provide `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`, and `PGSSLMODE=require`. The runner also includes a best-effort parser for the Supabase direct URL form so secrets are not printed.

## Proof Order

The runner executes:

1. Remote preflight: connection, non-fixed tenant count, fixed PR13 tenant guard.
2. `00_reset_puls_sanayi_seed.sql`
3. `01_load_puls_sanayi_seed.sql`
4. `10_apply_puls_teknik_remote_posture.sql`
5. `02_validate_puls_sanayi_seed.sql`
6. `03_generate_workflow_scenarios.sql`
7. `04_generate_performance_scenarios.sql`
8. `07_validate_packaging_proof.sql`
9. `08_validate_ai_context_readiness.sql`
10. `09_validate_canias_connector_readiness.sql`
11. `05_link_auth_personas_template.sql`
12. `06_jwt_mutation_proof_smoke.sql`
13. Remote postflight summary.

Auth persona proof is mandatory for PR13.9 signoff. If any of `admin_user_id`, `hr_admin_user_id`, `manager_user_id`, or `employee_user_id` is missing, the runner fails before seed writes.

## Stop Conditions

Stop and do not run the remote proof when:

- PR13.8 local proof is not green.
- Remote connection cannot be inspected read-only first.
- The fixed PR13 proof tenant already exists and `ALLOW_RESEED_FIXED_TENANT=1` was not intentionally set.
- Remote demo auth users do not exist.
- Any required persona UUID is missing.
- Any step would require migrations, seed CSV edits, `manifest.json` edits, or app source changes.

## Acceptance Criteria

- Mert Teknik must not be modified.
- Puls Teknik A.S. remote proof tenant is created from the deterministic PR13 proof dataset.
- SQL `00-10`, `02-04`, and `07-09` pass.
- `05_link_auth_personas_template.sql` links real remote auth users.
- `06_jwt_mutation_proof_smoke.sql` passes with JWT role/sub, create/decide RPC, and lifecycle smoke.
- Sanitized results are recorded in `13_remote_puls_teknik_tenant_proof_results.md`.
- No secret value is committed.
