# PR15.6 AI Runtime Evidence Contract

Tarih: 4 Haziran 2026

## Amaç

PR15.6, connector runtime sinyallerini AI Coach için güvenli ve kaynak açıklamalı bir kanıt sözleşmesine bağlar. Bu PR yeni job çalıştırmaz, yeni migration açmaz, connector API çağrısı yapmaz ve AI'a operasyon başlatma yetkisi vermez.

Ürün hedefi şudur: AI Coach, connector queue, worker event, credential state, import preview ve activity sinyallerini aynı tenant içinde okuyabilir; fakat yalnızca açıklama, özet, boşluk tespiti, sonraki insan onaylı adım önerisi ve inceleme hazırlığı yapabilir.

## Kanıt Kaynakları

AI Coach runtime bağlamı yalnızca aşağıdaki safe read-model sinyallerinden beslenir:

| Kaynak | AI'a giren bilgi | Girmeyen bilgi |
| --- | --- | --- |
| `puls_integration.connector_jobs` | Job sayısı, failure/dead-letter sayısı, domain ve durum özeti | Job başlatma, provider cevabı, secret değeri |
| `puls_integration.connector_job_events` | Safe worker ve queue olay sayısı | Worker claim/complete yetkisi |
| `puls_integration.erp_connections.credential_state` | Missing/verified credential posture sayısı | Credential değeri veya opaque reference değeri |
| `puls_integration.import_batches` | Dry-run preview sonucu var mı | Import apply veya canonical write |
| `puls_integration.erp_sync_batches` | Safe activity sayısı | ERP writeback veya provider payload |

## İzinli AI Önerileri

AI Coach yalnızca şu öneri sınıflarını kullanır:

- `explain`
- `summarize`
- `detect_gap`
- `recommend_next_step`
- `prepare_review`
- `source_disclosure`

Her öneri, kullandığı kaynağı açıkça belirtmek zorundadır. Bu sözleşme HR AI'ın gelecekte connector ve canonical model sinyallerinden güvenli öneriler üretmesi için temel oluşturur.

## Kapalı Aksiyonlar

AI Coach aşağıdaki aksiyonları başlatamaz:

- `start_connector_job`
- `read_credential`
- `apply_import`
- `write_to_source`
- `mutate_workflow`

Bu sınır PR13.7 AI action boundary ile uyumludur: AI açıklayabilir, özetleyebilir ve insan onaylı sonraki adımı hazırlayabilir; fakat workflow, connector, import veya ERP/source tarafında otonom aksiyon çalıştıramaz.

## Ürün Etkisi

PR15.6 ile `/ai-koc` artık yalnızca genel DB hazırlığını değil, connector runtime omurgasının güvenli kanıtlarını da gösterir. Bu, gelecekte AI Coach'un “neden bağlantı canlıya alınamıyor?”, “hangi adım eksik?”, “hangi veri hareketi sadece preview aşamasında?” gibi soruları kaynağıyla cevaplayabilmesi için gereken ürün sözleşmesini kurar.

Bu PR hâlâ teaser/readiness çizgisindedir. Live LLM chat, autonomous workflow mutation, AI tarafından job başlatma, import apply ve ERP/source writeback kapsam dışıdır.

## Kabul Kriterleri

- `/ai-koc` içinde `connector_runtime` domain'i görünür.
- Runtime evidence bölümü source disclosure zorunluluğunu gösterir.
- AI context yalnızca count/status/source-disclosure sinyalleri taşır.
- Secret değeri, opaque reference değeri, raw provider body veya request/response body AI context'e girmez.
- PR15.6 diff'i migration, seed, service worker veya ERP route runtime davranışı eklemez.
