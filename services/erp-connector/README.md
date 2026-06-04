# erp-connector — Connector Worker Boundary

Safe worker skeleton for future connector runtime. **PR15.2 does not open provider API calls, credential readback, import apply, canonical writes, or ERP/source writeback.**

## Posture

| Property              | Value                                                            |
| --------------------- | ---------------------------------------------------------------- |
| Version               | `0.2.0-worker-skeleton`                                          |
| Provider              | Source-independent (`noop_health` by default)                    |
| Runtime               | Health endpoint + optional safe queue worker loop                |
| App integration       | None — PULS app reads `puls_integration.*` via Supabase adapters |
| Production deployment | Railway-ready; worker loop is disabled unless env explicitly enables it |

## What this service is

**erp-connector is the future connector worker boundary.** In PR15.2 it can claim service-role jobs from `puls_integration.connector_jobs`, heartbeat its lease, recover stale jobs, and complete `noop_health` jobs with safe context.

Canias is only one future provider profile. The same worker contract must fit Logo, CSV / Excel, SFTP, and custom API connectors.

## What this service is not

- Not a live Canias API client
- Not a sync trigger for `/erp`
- Not a credential store
- No credential readback
- No import apply execution
- No canonical writes
- No source or ERP writeback
- No secrets, API keys, or tokens in this repo

## Security

- No credentials in repo
- Runtime uses service-role credentials from environment only
- Health payload never returns service-role keys
- Worker safe context must not include raw provider payloads, credentials, request bodies, or response bodies
- **No automatic destructive ERP writes**

## Observability

PR14.9 defines the Sentry posture for connector runtime. PR15.2 keeps this service in skeleton mode: errors must be captured with scrubbed job/status context only; raw provider payloads, credentials, service-role keys, passwords, tokens, and customer data values must never be attached to telemetry.

PR15.2 adds DB-backed heartbeat visibility through `puls_integration.connector_worker_heartbeats`. The UI can show whether a worker skeleton has recently checked in, but this is not proof that a provider connector exists.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `8081` | HTTP health port |
| `PULS_CONNECTOR_WORKER_ENABLED` | `false` | Enables the queue loop only when explicitly set |
| `PULS_SUPABASE_URL` / `SUPABASE_URL` | none | Supabase project URL for service-role RPC calls |
| `PULS_SUPABASE_SERVICE_ROLE_KEY` / `SUPABASE_SERVICE_ROLE_KEY` | none | Service-role key; never returned in health payload |
| `PULS_CONNECTOR_WORKER_ID` | `erp-connector-worker` | Stable worker id for locks and heartbeats |
| `PULS_CONNECTOR_WORKER_JOB_TYPES` | `noop_health` | Comma-separated job types the skeleton may claim |
| `PULS_CONNECTOR_WORKER_POLL_MS` | `5000` | Queue poll interval |
| `PULS_CONNECTOR_WORKER_LEASE_SECONDS` | `300` | Running job lease heartbeat |
| `PULS_CONNECTOR_WORKER_RECOVER_STALE` | `true` | Moves expired running jobs to retry/dead-letter |
| `PULS_CONNECTOR_WORKER_RECOVERY_LIMIT` | `25` | Maximum stale jobs recovered per loop |
| `PULS_CONNECTOR_WORKER_VERSION` | `0.2.0-worker-skeleton` | Safe runtime version label for heartbeat evidence |

## Railway deployment readiness

PR15.7 makes this service deployable as the long-running Railway worker for the connector queue.

Railway service settings:

| Setting | Value |
| --- | --- |
| Root directory | `services/erp-connector` |
| Config file path | `/services/erp-connector/railway.toml` |
| Start command | `pnpm start:railway` |
| Healthcheck path | `/health` |
| Process count | `1` worker replica until PR16 batch-lock/idempotency gates are live |

Required Railway variables:

- `PULS_CONNECTOR_WORKER_ENABLED=true`
- `PULS_SUPABASE_URL`
- `PULS_SUPABASE_SERVICE_ROLE_KEY`
- `PULS_CONNECTOR_WORKER_ID=railway-erp-connector-production-1`
- `PULS_CONNECTOR_WORKER_JOB_TYPES=noop_health,connector_runtime_preflight`
- `PULS_CONNECTOR_WORKER_POLL_MS=5000`
- `PULS_CONNECTOR_WORKER_LEASE_SECONDS=300`
- `PULS_CONNECTOR_WORKER_RECOVER_STALE=true`
- `PULS_CONNECTOR_WORKER_RECOVERY_LIMIT=25`

Do not set provider API credentials in this service yet. PR15.7 proves deployment, heartbeat, claim, complete, and safe runtime-preflight plumbing only. Provider API calls, credential readback, import apply execution, canonical writes, and ERP/source writeback remain closed.

Production smoke:

1. Open Railway deployment logs and confirm `erp-connector worker loop enabled listening on :$PORT`.
2. Request `/health`; the response must show `enabled=true`, `configured=true`, and no service-role key value.
3. Check `puls_integration.connector_worker_heartbeats` for the Railway worker id.
4. Enqueue a `noop_health` job with a unique idempotency key and verify it becomes `succeeded`.
5. If credentials are verified for a connector, request runtime preflight from `/erp` and verify the worker completes it without provider API calls.

## Local dev

```bash
cd services/erp-connector
node --experimental-strip-types src/index.ts
# curl http://localhost:8081 → safe health payload
```

Railway-mode local smoke:

```bash
PULS_CONNECTOR_WORKER_ENABLED=true \
PULS_SUPABASE_URL="https://example.supabase.co" \
PULS_SUPABASE_SERVICE_ROLE_KEY="service-role-key-from-env-only" \
PULS_CONNECTOR_WORKER_JOB_TYPES="noop_health" \
pnpm start:railway
```

## References

- [`docs/product/15_connector_job_queue_contract.md`](../../docs/product/15_connector_job_queue_contract.md)
- [`docs/product/15_connector_worker_skeleton.md`](../../docs/product/15_connector_worker_skeleton.md)
- [`docs/product/15_railway_worker_deployment_readiness.md`](../../docs/product/15_railway_worker_deployment_readiness.md)
- [`docs/product/14_error_observability_sentry.md`](../../docs/product/14_error_observability_sentry.md)
