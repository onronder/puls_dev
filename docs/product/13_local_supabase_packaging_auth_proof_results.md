# PR13.8 — Local Supabase Packaging + Auth Proof Results

Status: Passed local execution.

This file records sanitized local proof results only. Do not paste `DATABASE_URL`, passwords, access tokens, auth emails, or raw secret-bearing logs.

## Environment

| Field | Value |
|-------|-------|
| Environment label | Local Supabase |
| Run date | 2026-06-01 |
| Git commit | PR13.8 branch worktree |
| Docker / Supabase status | Full local stack running; imgproxy/pooler stopped by local config |
| `VITE_PULS_DEMO_MODE=false` app smoke | Pending |

## SQL Proof

| Step | Script | Result | Notes |
|------|--------|--------|-------|
| 1 | `00_reset_puls_sanayi_seed.sql` | Passed | Local DB reset; guardrail-aware reset fixes applied |
| 2 | `01_load_puls_sanayi_seed.sql` | Passed | Dockerized `psql` fallback used because host `psql` was absent |
| 3 | `02_validate_puls_sanayi_seed.sql` | Passed | Baseline proof |
| 4 | `03_generate_workflow_scenarios.sql` | Passed | Workflow scenarios generated: leave=30, expense=30, approvals>=60 |
| 5 | `04_generate_performance_scenarios.sql` | Passed | Performance scenarios generated: kpis=15, evals=45, scores=45 |
| 6 | `07_validate_packaging_proof.sql` | Passed | Packaging proof |
| 7 | `08_validate_ai_context_readiness.sql` | Passed | AI context readiness |
| 8 | `09_validate_canias_connector_readiness.sql` | Passed | Canias metadata readiness |

## Mandatory Auth Proof

| Persona env var | Required | Result | Notes |
|-----------------|----------|--------|-------|
| `admin_user_id` | Yes | Passed | Local auth user exists; UUID value intentionally omitted |
| `hr_admin_user_id` | Yes | Passed | Local auth user exists; UUID value intentionally omitted |
| `manager_user_id` | Yes | Passed | Local auth user exists; UUID value intentionally omitted |
| `employee_user_id` | Yes | Passed | Local auth user exists; UUID value intentionally omitted |
| `incomplete_setup_user_id` | No | Passed | Optional edge user staged and passed through `05` |
| `05_link_auth_personas_template.sql` | Yes | Passed | Linked local auth UUIDs to seeded employees |
| `06_jwt_mutation_proof_smoke.sql` | Yes | Passed | JWT/RPC smoke passed; transaction rolled back |
| Auth password grant | Yes | Passed | Login smoke passed for admin, hr_admin, manager, employee |

Auth persona proof is mandatory for PR13.8 signoff. This run passed `06_jwt_mutation_proof_smoke.sql` with real local auth UUIDs.

## Local Run Notes

- Docker was initially unavailable, then started successfully.
- Host `psql` was absent; runner used the Dockerized Postgres client fallback.
- Local Auth admin API rejected the local JWT key format, so persona users were staged in local Auth tables for this development-only proof.
- No connection string, password, API key, token, or raw auth UUID value is recorded here.

## Signoff

| Gate | Result |
|------|--------|
| Local SQL `00-09` proof | Passed |
| Mandatory auth/JWT proof | Passed |
| Auth password-grant smoke | Passed |
| Static verify | Passed |
| Sensitive grep | Passed |
| App smoke with demo mode off | Pending |

PR13.8 local DB/auth proof is green. App route smoke with demo mode off remains a separate closeout gate.
