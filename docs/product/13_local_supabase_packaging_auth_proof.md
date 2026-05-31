# PR13.8 — Local Supabase Packaging + Mandatory Auth Proof

PR13.8 is the local signoff gate before any remote Puls Teknik A.S. tenant work. It proves the merged PR13.4-PR13.7 seed, scenario, AI context, Canias metadata, and JWT persona smoke stack inside the local Supabase/Postgres environment.

## Scope

In scope:

- Local Supabase/Postgres proof using `psql` and the existing PR13 SQL stack.
- Mandatory auth persona binding and JWT/RPC smoke via `05` and `06`.
- Sanitized local proof results.

Out of scope:

- Remote Puls Teknik A.S. tenant setup.
- `src/**`, migrations, seed CSV, `manifest.json`, package or OpenAPI changes.
- Railway, Canias runtime, live AI, credentials, or `.env*` commits.

## Assumptions

- Local Supabase runs through Docker and `supabase status` can report the local DB URL.
- SQL Editor is not used for `01_load_puls_sanayi_seed.sql`; it cannot read local CSV files for `\copy`.
- The Postgres connection string is exported only in the terminal as `DATABASE_URL`.
- Auth persona UUIDs come from local Supabase Auth users created in Studio or another local-only admin flow.
- If host `psql` is not installed, `run-13-local-supabase-auth-proof.sh` uses a Dockerized Postgres client against `host.docker.internal`.

## Required Proof Order

From the repo root:

```bash
export DATABASE_URL='postgresql://...'
export admin_user_id='...'
export hr_admin_user_id='...'
export manager_user_id='...'
export employee_user_id='...'
# optional:
# export incomplete_setup_user_id='...'

./scripts/run-13-local-supabase-auth-proof.sh
```

The runner executes:

1. `00_reset_puls_sanayi_seed.sql`
2. `01_load_puls_sanayi_seed.sql`
3. `02_validate_puls_sanayi_seed.sql`
4. `03_generate_workflow_scenarios.sql`
5. `04_generate_performance_scenarios.sql`
6. `07_validate_packaging_proof.sql`
7. `08_validate_ai_context_readiness.sql`
8. `09_validate_canias_connector_readiness.sql`
9. `05_link_auth_personas_template.sql`
10. `06_jwt_mutation_proof_smoke.sql`

Auth persona proof is mandatory for PR13.8 signoff. If any of `admin_user_id`, `hr_admin_user_id`, `manager_user_id`, or `employee_user_id` is missing, the runner fails before touching the DB.

## Local Auth Persona Requirement

Create local auth users and map their UUIDs to the seeded persona anchors:

| Env var | Persona proof | Seed employee anchor |
|---------|---------------|----------------------|
| `admin_user_id` | Admin/settings and lifecycle smoke | `PS-001` |
| `hr_admin_user_id` | HR admin fallback for lifecycle smoke | `PS-006` |
| `manager_user_id` | Manager approval proof | `PS-021` |
| `employee_user_id` | Leave/expense/profile proof | `PS-023` |
| `incomplete_setup_user_id` | Optional incomplete setup edge | public bridge only when available |

`05` links users to `puls_core.employees.user_id`; `06` proves JWT context, create/decide RPC behavior, and lifecycle RPC behavior inside `BEGIN ... ROLLBACK`.

## Stop Conditions

Do not proceed to remote Puls Teknik A.S. tenant work until all are true:

- Local Supabase is running.
- `./scripts/run-13-local-supabase-auth-proof.sh` passes.
- `./scripts/verify-13-local-supabase-auth-proof.sh HEAD` passes.
- Sanitized results are recorded in `13_local_supabase_packaging_auth_proof_results.md`.
- The app can be smoked locally with `VITE_PULS_DEMO_MODE=false`.

## Local Proof Status

Initial authoring found Docker unavailable:

```text
Cannot connect to the Docker daemon
```

After Docker was started, PR13.8 local proof executed successfully on 2026-06-01:

- SQL `00-09` passed.
- `05_link_auth_personas_template.sql` linked admin, hr_admin, manager, and employee personas.
- `06_jwt_mutation_proof_smoke.sql` passed with create/decide/lifecycle RPC smoke inside `ROLLBACK`.
- Local Auth password-grant smoke passed for the four required personas.

The only remaining PR13.8-adjacent work is app route smoke with `VITE_PULS_DEMO_MODE=false`, which belongs to the route smoke closeout gate.
