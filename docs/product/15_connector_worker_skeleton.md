# PR15.2 Connector Worker Skeleton

Tarih: 4 Haziran 2026

## Executive Summary

PR15.2, PR15.1 queue contract üzerine güvenli worker sahipliği ekler. Bu PR PULS'u arka planda connector işi çalıştırabilecek mimariye taşır; ancak gerçek provider API çağrısı, credential resolution, import apply, canonical write veya ERP/source writeback açmaz.

PULS'ta UI iş çalıştırmaz. UI güvenli job isteği oluşturur. Worker işi claim eder, lease heartbeat verir, sadece izin verilen safe skeleton işi tamamlar ve sonucu DB state olarak kaydeder.

## What PR15.2 Proves

| Area | PR15.2 davranışı |
| --- | --- |
| Worker heartbeat | `puls_integration.connector_worker_heartbeats` worker'ın son güvenli durumunu tutar. |
| Job ownership | Running job'lar `locked_by`, `locked_at`, `worker_heartbeat_at`, `lease_expires_at` ile sahiplenilir. |
| Lease recovery | Süresi dolan running job'lar service-role recovery RPC ile `retrying` veya `dead_letter` durumuna taşınır. |
| Service boundary | Worker RPC'leri yalnızca `service_role` ile çalışır. |
| Safe skeleton | `services/erp-connector` yalnızca `noop_health` gibi güvenli skeleton job'ları tamamlar. |
| Product visibility | `/erp` activity tab worker heartbeat ve job lease durumunu safe read-model olarak gösterir. |

## What PR15.2 Does Not Do

- Canias, Logo, SFTP veya custom API client
- Credential value readback
- Secret storage
- Import apply execution
- Canonical writes
- ERP/source writeback
- Provider payload logging
- AI autonomous action

## Worker Runtime Contract

`services/erp-connector` artık health-only sınırını aşmadan worker skeleton olarak çalışabilir. Worker loop yalnızca env ile açıkça etkinleştirilirse queue'yu poll eder.

Default supported job type:

- `noop_health`

Unsupported job types explicit olarak fail edilir:

- `connector_job_type_not_supported_by_worker_skeleton`

Bu davranış bilinçlidir. Skeleton worker provider runtime varmış gibi davranmaz.

## Safe Env Boundary

Worker service-role key'i yalnızca environment üzerinden alır. Health payload ve logs bu değeri döndürmez.

Required runtime env:

- `PULS_CONNECTOR_WORKER_ENABLED=true`
- `PULS_SUPABASE_URL`
- `PULS_SUPABASE_SERVICE_ROLE_KEY`
- optional `PULS_CONNECTOR_WORKER_ID`
- optional `PULS_CONNECTOR_WORKER_JOB_TYPES`

## AI Evidence

PR15.2, AI Coach için güvenli runtime evidence üretir:

- worker status
- last heartbeat
- supported safe job types
- job lease status
- safe error code
- next action

AI Coach bu sinyalleri açıklayabilir ve özetleyebilir. AI Coach job claim edemez, complete edemez, credential okuyamaz, import apply başlatamaz veya ERP'ye yazamaz.

## Handoff

PR15.3 runtime observability, retry ve failure modelini genişletebilir:

1. safe retry/backoff classification
2. dead-letter operator review
3. Sentry scrubbing for worker runtime
4. activity timeline linkage for worker outcomes
5. Notification Center groundwork

PR15.4 credential capture/storage boundary olmadan provider-specific runtime açılmamalıdır.
