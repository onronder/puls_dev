# PR15.7 Railway Worker Deployment Readiness

Date: 4 June 2026

## Executive Summary

PR15.7 closes the gap between the PR15 runtime contract and an actually running connector worker. PR15.1-15.6 created the queue, worker skeleton, heartbeat, retry/failure model, credential boundary, runtime preflight, and AI-safe evidence. PR15.7 makes `services/erp-connector` deployable on Railway with a clear start command, healthcheck, required variables, and remote smoke procedure.

This PR does not add provider runtime. It does not call Canias, Logo, SFTP, custom API, or any external ERP endpoint. It does not read credential values, apply imports, write canonical data, or write back to source systems.

## What PR15.7 Proves

| Area | Proof |
| --- | --- |
| Deployment contract | `services/erp-connector/railway.toml` defines Railpack build, `pnpm start:railway`, `/health`, and restart policy. |
| Monorepo boundary | Railway service root is `services/erp-connector`; config file path is `/services/erp-connector/railway.toml`. |
| Runtime ownership | Worker loop is enabled only with `PULS_CONNECTOR_WORKER_ENABLED=true`. |
| Queue operation | Railway worker can heartbeat, recover stale jobs, claim allowed job types, and complete safe jobs. |
| Safety boundary | Health, logs, DB events, and AI evidence never expose service-role keys, credential values, raw payloads, request bodies, or response bodies. |
| PR16 readiness | CSV / Excel controlled import execution can rely on an already deployed worker process instead of browser-side execution. |

## Railway Setup

Railway's current deployment model supports config-as-code through `railway.toml` and lets monorepo services define their own root directory and config source. Configure the service as follows:

| Railway setting | Value |
| --- | --- |
| Service name | `erp-connector` |
| Root directory | `services/erp-connector` |
| Config file path | `/services/erp-connector/railway.toml` |
| Start command | `pnpm start:railway` |
| Healthcheck path | `/health` |
| Replica count | `1` until PR16.2 batch lock/idempotency is live |

References:

- Railway config-as-code reference: https://docs.railway.com/config-as-code/reference
- Railway monorepo deployment guide: https://docs.railway.com/deployments/monorepo
- Railway healthcheck guide: https://docs.railway.com/deployments/healthchecks

## Required Railway Variables

| Variable | Value / rule |
| --- | --- |
| `PULS_CONNECTOR_WORKER_ENABLED` | `true` |
| `PULS_SUPABASE_URL` | Remote Supabase project URL |
| `PULS_SUPABASE_SERVICE_ROLE_KEY` | Remote Supabase service-role key; Railway secret only |
| `PULS_CONNECTOR_WORKER_ID` | `railway-erp-connector-production-1` |
| `PULS_CONNECTOR_WORKER_JOB_TYPES` | `noop_health,connector_runtime_preflight` |
| `PULS_CONNECTOR_WORKER_POLL_MS` | `5000` |
| `PULS_CONNECTOR_WORKER_LEASE_SECONDS` | `300` |
| `PULS_CONNECTOR_WORKER_RECOVER_STALE` | `true` |
| `PULS_CONNECTOR_WORKER_RECOVERY_LIMIT` | `25` |
| `PULS_CONNECTOR_WORKER_VERSION` | Optional deployment label, for example `0.2.0-worker-skeleton` |

Do not add provider credentials to Railway for PR15.7. Provider-specific API credentials remain closed until the corresponding connector runtime implementation exists.

## Remote Smoke Procedure

1. Deploy `erp-connector` on Railway.
2. Confirm the deployment log contains `erp-connector worker loop enabled listening on :$PORT`.
3. Open `/health`; the JSON must show `enabled=true`, `configured=true`, and must not include the Supabase service-role key.
4. Verify worker heartbeat:

```sql
select
  worker_id,
  status,
  runtime_version,
  supported_job_types,
  last_seen_at,
  safe_error_code,
  safe_context
from puls_integration.connector_worker_heartbeats
where worker_id = 'railway-erp-connector-production-1';
```

5. Queue a safe `noop_health` smoke job:

```sql
select puls_integration.enqueue_connector_job(
  p_job_type := 'noop_health'::puls_integration.connector_job_type,
  p_idempotency_key := 'pr15_7_railway_noop_health_smoke_v1',
  p_domain := 'runtime',
  p_priority := 10,
  p_max_attempts := 1,
  p_safe_error_context := '{"smoke":"railway_worker_readiness","external_call":false,"credential_read":false,"canonical_write":false}'::jsonb,
  p_next_action_key := 'confirm_worker_claim_complete',
  p_tenant_id := 'a0000001-0001-4001-8001-000000000001'::uuid
);
```

6. Confirm the worker completed the job:

```sql
select
  job_type,
  status,
  locked_by,
  started_at,
  finished_at,
  safe_error_code,
  safe_error_context,
  next_action_key
from puls_integration.connector_jobs
where idempotency_key = 'pr15_7_railway_noop_health_smoke_v1';
```

Expected result:

- `status='succeeded'`
- `locked_by='railway-erp-connector-production-1'`
- `safe_error_context` contains no credential, payload, request, or response values

## Operational Boundaries

- One Railway worker replica only until PR16.2 idempotency and batch-lock proof is live.
- Worker uses `service_role` only from Railway environment variables.
- Browser and AI Coach cannot claim or complete jobs.
- `/erp` may request allowed jobs; the worker is the only execution boundary.
- Healthcheck proves process readiness only; DB heartbeat proves queue-loop readiness.
- Provider runtime remains explicit per connector. Canias is one provider profile, not the product architecture.

## Out Of Scope

- Canias API runtime
- Logo API runtime
- SFTP/FTP runtime
- CSV / Excel import apply
- Credential readback
- Canonical writes
- ERP/source writeback
- Autonomous AI execution
- Multi-worker horizontal scaling

## Handoff To PR16

With PR15.7 complete, PR16.1 can start controlled CSV / Excel master-data import execution on a real worker process. The first apply path must still require preview, human review, admin approval, worker execution, safe audit, and idempotency checks.
