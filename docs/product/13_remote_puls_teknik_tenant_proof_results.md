# PR13.9 — Remote Puls Teknik Tenant Proof Results

Status: Passed remote execution.

This file records sanitized remote proof results only. Do not paste `DATABASE_URL`, passwords, service-role keys, access tokens, auth emails with passwords, raw auth UUID values, or raw secret-bearing logs.

## Environment

| Field | Value |
|-------|-------|
| Environment label | Remote Supabase development |
| Run date | 2026-06-01 |
| Remote host | Supabase direct Postgres host inspected; value documented outside results |
| Existing tenant safety | Mert Teknik exists and must not be modified |
| Fixed PR13 proof tenant | Absent during read-only inspect |
| Puls Teknik posture | Uses fixed PR13 proof tenant labeled by `10_apply_puls_teknik_remote_posture.sql` |

## Read-Only Inspect

| Check | Result | Notes |
|-------|--------|-------|
| Remote Postgres connection | Passed | PostgreSQL 17.6 |
| PULS schemas present | Passed | Core workflow, performance, integration, calc, vault schemas exist |
| Migration table present | Passed | 31 migrations visible |
| Existing tenant count | Passed | 1 existing non-fixed tenant |
| PR13 fixed proof tenant absent | Passed | Safe to seed without reseed override |
| Target demo auth users | Passed | Required remote auth users were created before proof |

## SQL Proof

| Step | Script | Result | Notes |
|------|--------|--------|-------|
| 1 | `00_reset_puls_sanayi_seed.sql` | Passed | Fixed PR13 proof tenant reset scope |
| 2 | `01_load_puls_sanayi_seed.sql` | Passed | Baseline seed loaded through Dockerized `psql` client |
| 3 | `10_apply_puls_teknik_remote_posture.sql` | Passed | Fixed proof tenant labeled Puls Teknik A.S. |
| 4 | `02_validate_puls_sanayi_seed.sql` | Passed | Baseline proof |
| 5 | `03_generate_workflow_scenarios.sql` | Passed | Workflow scenarios generated |
| 6 | `04_generate_performance_scenarios.sql` | Passed | Performance scenarios generated |
| 7 | `07_validate_packaging_proof.sql` | Passed | Packaging proof |
| 8 | `08_validate_ai_context_readiness.sql` | Passed | AI context readiness proof |
| 9 | `09_validate_canias_connector_readiness.sql` | Passed | Canias metadata readiness proof |

## Mandatory Auth Proof

| Persona env var | Required | Result | Notes |
|-----------------|----------|--------|-------|
| `admin_user_id` | Yes | Passed | Remote auth user exists; UUID value intentionally omitted |
| `hr_admin_user_id` | Yes | Passed | Remote auth user exists; UUID value intentionally omitted |
| `manager_user_id` | Yes | Passed | Remote auth user exists; UUID value intentionally omitted |
| `employee_user_id` | Yes | Passed | Remote auth user exists; UUID value intentionally omitted |
| `incomplete_setup_user_id` | No | Pending | Optional edge user |
| `05_link_auth_personas_template.sql` | Yes | Passed | Linked remote auth UUIDs to seeded employees |
| `06_jwt_mutation_proof_smoke.sql` | Yes | Passed | JWT/RPC smoke passed; transaction rolled back |

Remote JWT smoke proved:

- authenticated JWT `role` + `sub` context
- `create_leave_request`
- `create_expense_claim`
- `decide_approval_request` multi-step policy behavior
- lifecycle smoke inside rollback scope

## Signoff

| Gate | Result |
|------|--------|
| Remote read-only inspect | Passed |
| Remote SQL proof | Passed |
| Mandatory remote auth/JWT proof | Passed |
| Static verify | Passed |
| Sensitive grep | Passed |
| App smoke with demo mode off | PR13.10 |

PR13.9 remote DB/auth proof is green. App route smoke with demo mode off remains a separate closeout gate.
