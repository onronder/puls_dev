# PR15.3 Connector Runtime Observability And Failure Model

PR15.3, PR15.1 job queue ve PR15.2 worker skeleton üzerine güvenli runtime gözlemlenebilirliği ekler. Amaç connector işlerinin ne zaman tamamlandığını, neden tekrar deneneceğini, ne zaman manuel inceleme beklediğini ve hangi güvenli hata sınıfına düştüğünü ürün içinde anlaşılır hale getirmektir.

Bu PR provider API çağrısı, credential readback, import apply, canonical write veya ERP/source writeback açmaz.

## Product Outcome

PULS'ta UI iş çalıştırmaz. UI ve admin ekranları yalnızca güvenli job durumunu, retry penceresini, dead-letter sınırını ve operator-visible job loglarını gösterir. Worker service-role boundary üzerinden işi tamamlar; DB deterministic retry/failure kararını verir; activity timeline güvenli event history üretir.

Bu model Canias'a özel değildir. Canias, Logo, CSV/Excel, Custom API veya SFTP gibi kaynaklar aynı queue, failure class, retry ve operator review sözleşmesini kullanır. Provider-specific runtime sadece bu ortak omurganın üstünde eklenir.

## What PR15.3 Adds

| Area | Result |
| --- | --- |
| Failure class | `none`, `transient`, `credential`, `mapping`, `provider_limit`, `provider_unavailable`, `worker`, `unsupported`, `unknown` |
| Retry policy | Retryable failure classes deterministic backoff ile `retrying` state'e alınır |
| Dead letter | Maksimum deneme sınırı aşılırsa job `dead_letter` olur ve otomatik ilerlemez |
| Operator severity | `info`, `warning`, `error`, `critical` sınıfları UI ve AI-safe event history için tutulur |
| Job events | `connector_job_events` immutable safe activity stream üretir |
| UI read model | `/erp` runtime queue failure class, retry window ve manual review sinyali gösterir |
| Worker skeleton | Unsupported veya worker-level hatalar safe observation olarak tamamlanır |

## Safe Logging Boundary

Connector runtime event'leri şunları içermez:

- Secret value
- Credential reference value
- Provider response body
- Request body
- Raw source payload
- Password, token veya API key

Activity timeline ve Sentry-ready context yalnızca safe status, safe error code, failure class, retry count, next action ve scrubbed counters gibi ürün sinyallerini taşır.

## Retry And Dead-Letter Rules

Retryable classes:

- `transient`
- `provider_unavailable`
- `provider_limit`
- `worker`

Non-retry classes:

- `credential`
- `mapping`
- `unsupported`
- `unknown`

Retryable job hâlâ attempt hakkına sahipse `retrying` olur ve `scheduled_at` deterministic backoff penceresine taşınır. Attempt sınırı dolduysa `dead_letter` olur, `operator_review_required=true` olarak işaretlenir ve manuel inceleme bekler.

## AI-Ready Evidence

PR15.3 AI için aksiyon açmaz. Ancak HR AI ve AI Coach ileride şu güvenli sinyallerden öneri üretebilir:

- Credential eksik veya doğrulanmamış
- Mapping blocker var
- Provider erişim/limit sinyali oluştu
- Worker lease recovery çalıştı
- Dead-letter job manuel inceleme bekliyor
- Retry penceresi dolmadan tekrar deneme yapılmamalı

AI bu sinyalleri açıklayabilir, özetleyebilir ve sonraki adımı önerebilir. AI job claim edemez, complete edemez, credential okuyamaz, import apply başlatamaz veya ERP'ye yazamaz.

## Acceptance Criteria

- `complete_connector_job` safe failure class üretir.
- Retry count ve next retry zamanı deterministic hesaplanır.
- Dead-letter job tekrar otomatik çalışmaz.
- `connector_job_events` tenant-scoped safe timeline olarak okunur.
- `/erp` raw provider error yerine ürün diliyle failure class, retry ve manuel inceleme mesajı gösterir.
- Worker context secret, token, password, credential reference, raw payload, request body veya response body içermez.
- Sentry-ready context safe error code ve scrubbed metadata sınırında kalır.

## Handoff To PR15.4

PR15.4 secure credential storage ve runtime boundary üzerinde çalışacak. PR15.3'ün failure modelinde credential sınıfı şimdiden ayrı tutulduğu için credential setup, verification ve revoke akışları aynı safe job event sözleşmesine bağlanabilir.
