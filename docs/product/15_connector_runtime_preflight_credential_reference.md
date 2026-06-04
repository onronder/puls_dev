# PR15.5 Runtime Preflight With Credential Reference

Tarih: 4 Haziran 2026

## Executive Summary

PR15.5, connector runtime'a geçişte ilk güvenli çalışma adımını açar: verified credential reference varsa admin, `connector_runtime_preflight` job'ını kuyruğa alabilir. Worker bu job'da provider API çağrısı, credential readback, import apply, canonical write veya ERP/source writeback yapmaz; yalnızca server-side safe context okuyup sonucu queue/event modeliyle kaydeder.

Bu PR Canias entegrasyonunu tamamlamaz ve canlı müşteri verisi çekmez. Canias, CSV/Excel, Logo, SFTP veya custom API gibi farklı kaynaklar için ortak PULS connectivity omurgasını güçlendirir.

## Product Boundary

| Alan | PR15.5 kararı |
| --- | --- |
| UI | Admin yalnızca runtime preflight job isteği açabilir; secret input veya API credential formu yok |
| DB | Runtime preflight, credential required ise yalnızca `verified` state ve opaque reference varlığında kuyruğa alınır |
| Worker | `get_connector_runtime_preflight_context` ile safe setup/credential state okur; `credentials_ref` değeri dönmez |
| Provider runtime | Canlı provider API çağrısı yok; provider-specific connector implementation future PR konusudur |
| Activity/AI evidence | Job sonucu safe error code, failure class ve next action olarak görünür; raw provider response yok |

## State Rules

| Credential state | Runtime preflight etkisi |
| --- | --- |
| `missing` | Kuyruğa alınmaz |
| `configured` | Kuyruğa alınmaz; önce verification gerekir |
| `verified` | Kuyruğa alınabilir |
| `failed` | Kuyruğa alınmaz; operatör güvenli referansı inceler |
| `revoked` | Kuyruğa alınmaz |
| `not_required` | CSV/Excel gibi credential gerektirmeyen kaynaklarda credential blocker uygulanmaz |

## What Changed

- `request_connector_runtime_preflight` authenticated admin/service-role RPC boundary eklendi.
- `get_connector_runtime_preflight_context` service-role-only worker read model olarak eklendi.
- `enqueue_connector_job` runtime preflight için `verified + reference_available` gate'ine sıkılaştırıldı.
- `erp-connector` worker, `connector_runtime_preflight` job'ını safe setup/credential context ile tamamlayabilir.
- `/erp` runtime queue tab'ına runtime preflight request action eklendi; worker veya credential hazır değilse aksiyon kapalı kalır.

## Explicit Non-Goals

- Provider API call yok.
- Credential resolver/secret manager implementation yok.
- Credential value veya opaque reference readback yok.
- Import execution/apply yok.
- Canonical write yok.
- ERP/source writeback yok.
- AI autonomous action yok.

## AI And HR Product Value

HR AI, connector runtime'ın neden hazır veya bloklu olduğunu daha güvenilir yorumlayabilir: credential verified mi, worker destekliyor mu, runtime preflight kuyruğa girdi mi, safe failure class ne ve operatörün sıradaki güvenli aksiyonu nedir. AI credential değeri, provider response veya write payload görmez.

## Verification

- Missing/configured/failed/revoked credential state runtime preflight başlatamaz.
- Worker runtime preflight sonucu safe context ile döner.
- Provider response raw şekilde saklanmaz.
- UI ve adapter secret/reference readback açmaz.
- Verify gate: [`../../scripts/verify-15-runtime-preflight-credential-reference.sh`](../../scripts/verify-15-runtime-preflight-credential-reference.sh)
