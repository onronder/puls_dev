# PR15.1 Connector Job Queue Contract

Tarih: 4 Haziran 2026

## Executive Summary

PR15.1, PULS connector runtime fazının ilk güvenli temelidir. Bu PR gerçek connector çalıştırmaz; bunun yerine tenant-scoped, idempotent ve service-role worker tarafından claim edilebilen DB-backed job queue sözleşmesini kurar.

PULS'ta UI iş çalıştırmaz. UI güvenli job isteği oluşturur; worker işi çalıştırır; DB state ve activity log sonucu tutar. AI bu güvenli state ve event sinyallerini okuyabilir, ancak işi başlatmaz veya workflow/import/ERP aksiyonu çalıştırmaz.

## What PR15.1 Proves

| Area | PR15.1 davranışı |
| --- | --- |
| Tenant isolation | Her job `tenant_id` ile scope edilir; authenticated kullanıcı yalnızca kendi tenant'ının güvenli özetlerini okuyabilir. |
| Idempotency | Aynı tenant + `idempotency_key` tekrar gelirse mevcut job döner. |
| Concurrency | Aynı tenant/source/domain/job type için aktif çakışan iş engellenir. |
| Worker boundary | `claim_next_connector_job` ve `complete_connector_job` yalnızca `service_role` içindir. |
| Safe diagnostics | `safe_error_code`, `safe_error_context`, `next_action_key` kullanıcı ve AI için güvenli sinyal üretir. |
| Product visibility | `/erp` aktivite sekmesi job queue sözleşmesini ve son güvenli job özetlerini gösterir. |

## What PR15.1 Does Not Do

- Connector API call
- Railway worker runtime
- Credential capture or secret resolution
- Import apply execution
- Canonical writes
- ERP/source writeback
- Notification delivery
- AI autonomous action

## Queue Contract

`puls_integration.connector_jobs` source-independent runtime job tablosudur. Canias yalnızca bir source profile'dır; aynı sözleşme Logo, CSV / Excel, SFTP ve custom API connector'leri için kullanılmalıdır.

Required state:

- `job_type`
- `status`
- `tenant_id`
- optional `connection_id`, `source_namespace_id`, `import_batch_id`
- `idempotency_key`
- `concurrency_key`
- attempt and scheduling fields
- safe error and next-action fields

Job statuses:

- `queued`
- `running`
- `succeeded`
- `failed`
- `retrying`
- `cancelled`
- `dead_letter`

Job types:

- `setup_preflight`
- `credential_verification`
- `import_preview`
- `import_apply`
- `connector_runtime_preflight`
- `source_discovery`
- `noop_health`

## Security Boundary

`safe_error_context` is a sanitized operational context only. It must not contain API keys, passwords, tokens, secret references, connection strings, raw provider payloads, request bodies, response bodies, or canonical write payloads.

Authenticated users do not directly insert or update connector jobs. Admin users enqueue through `enqueue_connector_job`; future workers claim and complete through service-role-only RPCs.

## AI Evidence

PR15.1 makes connector jobs AI-readable as safe operational evidence:

- source/domain
- job type
- lifecycle status
- safe error code
- next action
- attempt count

AI Coach can explain and summarize these signals, but must not enqueue, claim, complete, apply, sync, export, or write to ERP.

## Future Handoff

PR15.2 can implement a Railway worker skeleton using the PR15.1 contract:

1. claim next job with `claim_next_connector_job`
2. perform no-op or safe preflight work
3. complete with `complete_connector_job`
4. emit safe activity

The contract intentionally avoids RabbitMQ at this stage. Postgres/Supabase queue semantics are enough for the current product maturity while leaving a clear migration path if throughput later requires an external queue.
