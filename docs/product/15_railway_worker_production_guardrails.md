# PR15.8 Railway Worker Production Guardrails

Date: 5 June 2026

## Executive Summary

PR15.8 hardens the deployed Railway connector worker before PR16 opens controlled data movement. PR15.7 proved that the worker can deploy, heartbeat, claim, and complete safe jobs. PR15.8 makes that posture harder to misuse by adding production-only defaults, an explicit `import_apply` runtime gate, one-replica config-as-code, and graceful deployment shutdown.

This PR does not add provider runtime, CSV / Excel apply execution, credential readback, canonical writes, ERP/source writeback, or autonomous AI actions.

## Guardrail Decisions

| Decision | Production rule |
| --- | --- |
| Railway environment | If `RAILWAY_ENVIRONMENT_NAME` is non-production, the queue loop remains disabled unless `PULS_CONNECTOR_WORKER_ALLOW_NON_PRODUCTION=true`. |
| Import apply | `import_apply` is filtered from `PULS_CONNECTOR_WORKER_JOB_TYPES` unless `PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED=true`. |
| Replica count | `numReplicas = 1` until PR16 proves batch lock, idempotency, approval, and audit. |
| Deploy overlap | `overlapSeconds = 0` to avoid two connector workers claiming jobs during deploy handoff. |
| Graceful shutdown | `drainingSeconds = 30` plus `SIGTERM` / `SIGINT` handling lets the process stop polling cleanly. |
| Monorepo deploys | Railway `watchPatterns` limits worker redeploys to the connector service and root package metadata. |
| Health evidence | `/health` remains safe and includes only non-secret guardrail state. |

## Railway Variables

Keep the PR15.7 production values:

- `PULS_CONNECTOR_WORKER_ENABLED=true`
- `PULS_SUPABASE_URL`
- `PULS_SUPABASE_SERVICE_ROLE_KEY`
- `PULS_CONNECTOR_WORKER_ID=railway-erp-connector-production-1`
- `PULS_CONNECTOR_WORKER_JOB_TYPES=noop_health,connector_runtime_preflight`
- `PULS_CONNECTOR_WORKER_POLL_MS=5000`
- `PULS_CONNECTOR_WORKER_LEASE_SECONDS=300`
- `PULS_CONNECTOR_WORKER_RECOVER_STALE=true`
- `PULS_CONNECTOR_WORKER_RECOVERY_LIMIT=25`

Add these explicit guardrail defaults:

- `PULS_CONNECTOR_WORKER_ALLOW_NON_PRODUCTION=false`
- `PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED=false`

`RAILWAY_ENVIRONMENT_NAME` is provided by Railway. Production may run the queue loop. Preview, staging, or other non-production Railway environments must not run the loop unless an operator intentionally enables `PULS_CONNECTOR_WORKER_ALLOW_NON_PRODUCTION=true`.

Do not add Canias, Logo, SFTP, custom API, or provider credential values to Railway until the matching provider runtime PR defines the connector contract and secret manager boundary.

## Remote Smoke Expectations

The PR15.7 `noop_health` smoke remains valid with one correction: job completion clears the runtime lock. Therefore the connector job row should prove `status='succeeded'`, `started_at is not null`, `finished_at is not null`, and `safe_error_code is null`; it should not require `locked_by` to remain populated after completion.

Use `connector_job_events` as the canonical worker proof:

```sql
select
  job_id,
  job_type,
  status,
  event_key,
  level,
  worker_id,
  safe_error_code,
  safe_error_context,
  created_at
from puls_integration.connector_job_events
where job_id = '<noop_health_job_id>'::uuid
order by created_at desc;
```

Expected result:

- `event_key='connector_job_succeeded'`
- `worker_id='railway-erp-connector-production-1'`
- `safe_error_context` contains no credential, raw payload, request body, or response body

## PR16 Handoff

Before PR16 can set `PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED=true` or include `import_apply` in the production job type list, the product must prove:

- preview exists for the same batch
- admin approval exists
- batch lock prevents concurrent apply
- idempotency key prevents duplicate execution
- canonical write audit is persisted
- rollback or compensating action is documented
- Notification Center delivery is safe
- AI evidence is source-disclosed and actionless

Until those proofs exist, the production Railway worker may run `noop_health` and `connector_runtime_preflight` only.

## Operator Checklist

- Keep Railway replicas at one.
- Keep `overlapSeconds = 0`.
- Keep `drainingSeconds = 30`.
- Alert on stale `connector_worker_heartbeats.last_seen_at`.
- Alert when `connector_worker_heartbeats.safe_error_code` is not null.
- Alert when connector jobs enter `dead_letter`.
- Treat repeated `PGRST202` as a schema-profile or PostgREST cache issue before assuming worker failure.
- Remove public Railway domains if the service does not need browser access beyond Railway healthchecks.

## References

- Railway config-as-code reference: https://docs.railway.com/config-as-code/reference
- Railway deployment reference: https://docs.railway.com/deployments/reference
- Railway deployment teardown: https://docs.railway.com/deployments/deployment-teardown
