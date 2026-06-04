# PR15-PR16 Connector Runtime Ve HR AI Roadmap

Tarih: 4 Haziran 2026

## Amaç

PR14, PULS'un connector control plane'ini tamamladı: setup, mapping, preflight, credential boundary, activity timeline, dry-run preview, human review, approval policy, kapalı apply contract ve okunabilir `/erp` workbench.

PR15-PR16'nın amacı bu control plane'i gerçek runtime'a güvenli şekilde taşımaktır. Bu fazlarda PULS, çok tenant'lı ve çok connector'lü bir sistem olarak çalışmaya hazırlanır. Aynı zamanda connector'lardan ve canonical modelden gelen her sinyalin gelecekte AI Coach ve HR AI önerileri için kullanılabilir hale gelmesi sağlanır.

Bu planın ana iddiası:

> PULS'ta UI iş çalıştırmaz. UI güvenli job isteği oluşturur. Worker işi çalıştırır. DB state ve activity log sonucu tutar. AI bu güvenli state, event ve canonical data üzerinden öneri üretir. İnsan onayı olmadan workflow, import apply, ERP writeback veya destructive aksiyon çalışmaz.

## Codebase Dayanağı

| Mevcut temel | Bugünkü rolü | PR15-PR16 yorumu |
| --- | --- | --- |
| `puls_integration.erp_connections` | Connector setup, lifecycle, credential posture | Runtime job'ların hangi tenant/source/domain için çalışacağını belirler |
| `puls_integration.source_namespaces` | Source namespace ve source priority | Çok connector'lü data ownership ve idempotency için ana referans |
| `puls_integration.entity_identity_map` | External ID ile canonical kayıt ilişkisi | Apply sırasında duplicate/overwrite riskini azaltır |
| `puls_integration.import_batches` | Import batch state, preview/apply counters | Controlled execution için batch lock ve audit katmanı buraya bağlanır |
| `puls_integration.import_records` | Satır bazlı import sonucu ve preview action | CSV/Excel ve ileride API connector apply için satır kanıtı sağlar |
| `puls_integration.erp_sync_batches` | Safe activity timeline ve setup history | PR15 runtime event'leri için genişletilebilir history/read model |
| `services/erp-connector` | Health-only connector service skeleton | PR15'te worker/runtime service'e dönüşür |
| `services/llm-gateway` | Health-only AI service boundary | PR15-PR16'da AI için veri/olay sözleşmesi hazırlanır; live autonomous action açılmaz |
| `src/lib/data/setup/erp.ts` | `/erp` adapter ve connector workbench state'i | Job queue, runtime status, credential verification ve notifications görünürlüğü buradan okunur |
| `src/lib/data/ai-coach/*` | AI Coach DB context readiness | Runtime events ve canonical changes AI context'e kontrollü şekilde eklenir |

## Ana Mimari Kararlar

| Karar | Gerekçe |
| --- | --- |
| Başlangıç queue modeli Railway worker + Postgres/Supabase job queue | Ürün için yeterince production-grade, RabbitMQ'ya göre daha sade ve yönetilebilir |
| RabbitMQ ilk fazda yok | Mevcut hacim ve mimari için erken karmaşıklık; ileride gerekli olursa taşınabilir contract bırakılır |
| Browser/UI runtime çalıştırmaz | Güvenlik, retry, idempotency ve çok tenant operasyonu için worker zorunlu |
| Credential değerleri product DB'de tutulmaz | Product DB yalnızca safe reference/state tutar; secret readback yok |
| İlk executable data movement CSV / Excel üzerinden yapılır | API belirsizliği az; canonical apply disiplini önce güvenli alanda kanıtlanır |
| Canias runtime generic connector omurgasından sonra başlar | Canias ürün mimarisi değil, connector profillerinden biridir |
| AI tüm runtime event'lerinden beslenir ama aksiyon çalıştırmaz | HR AI öneri ve analiz üretebilir; human-in-the-loop çizgisi korunur |

## PR15 - Connector Runtime Control Plane

PR15 gerçek veri hareketi açmadan runtime omurgasını kurar. Bu fazın sonunda PULS job oluşturabilir, worker ile güvenli şekilde çalıştırabilir, retry/log/failure state tutabilir, credential reference doğrulama sınırını modelleyebilir ve AI için güvenli operasyon event'leri üretebilir.

### PR15.1 - Connector Job Queue Contract

**Ürün değeri:** PULS çok tenant'lı connector işlerini güvenli kuyruğa alabilir. Aynı tenant/domain üzerinde çakışan işler kontrol edilir.

**Implementation status:** PR15.1 implements the DB-backed queue contract, safe UI read model, and verify gate. Worker execution remains PR15.2.

**Kapsam:**

- `puls_integration.connector_jobs` tenant-scoped job tablosu
- Job status modeli: `queued`, `running`, `succeeded`, `failed`, `retrying`, `cancelled`, `dead_letter`
- `tenant_id`, `connection_id`, `source_namespace_id`, `provider`, `domain`, `job_type`
- `idempotency_key`, `attempt_count`, `max_attempts`
- `scheduled_at`, `started_at`, `finished_at`
- `safe_error_code`, `safe_error_context`, `next_action_key`
- Per-tenant/domain concurrency kuralı
- Service-role worker read/write boundary
- `/erp` safe runtime job queue read model

**Kapsam dışı:**

- Connector API call
- Credential capture
- Import apply
- ERP writeback
- AI autonomous action

**AI-ready çıktı:**

- Her job AI için güvenli bir operational signal üretir: hangi domain, hangi kaynak, hangi durum, hangi blocker, hangi next action.

**Doğrulama:**

- Aynı tenant/domain için duplicate running job engellenir.
- Cross-tenant job okunamaz/yazılamaz.
- Job payload secret veya raw source data içermez.

### PR15.2 - Railway Worker Skeleton

**Ürün değeri:** PULS artık arka planda iş çalıştırabilen bir mimariye geçer; ancak gerçek veri yazma hâlâ kapalı kalır.

**Implementation status:** PR15.2 implements the worker heartbeat, lease ownership, stale recovery contract, and source-independent `erp-connector` worker skeleton. Provider API runtime, credential resolution, import apply, and ERP/source writeback remain closed.

**Kapsam:**

- `services/erp-connector` health-only skeleton'dan worker skeleton'a evrilir.
- Worker DB queue'dan service-role RPC ile job alır.
- `worker_heartbeat_at` ve `lease_expires_at` ile güvenli lock sahipliği görünür olur.
- `connector_worker_heartbeats` safe read-model'i worker durumunu gösterir.
- Başlangıçta yalnızca `noop_health` safe skeleton job çalıştırılır.
- Unsupported job type provider runtime varmış gibi gösterilmez; safe failure olarak kapanır.
- Stale running job recovery `retrying` veya `dead_letter` state'e taşır.
- Worker config env üzerinden alınır; secret loglanmaz ve health payload'a dönmez.

**Kapsam dışı:**

- Canias API client
- CSV import apply
- Runtime credential readback
- ERP writeback

**AI-ready çıktı:**

- Worker event'leri AI Coach'un "hangi operasyon nerede takıldı?" sorusuna temel olur.

**Doğrulama:**

- Worker aynı job'ı iki kez alamaz.
- Worker kapanıp açıldığında stuck job recovery kuralı çalışır.
- Logs safe context dışında veri içermez.

### PR15.3 - Runtime Observability, Retry Ve Failure Model

**Ürün değeri:** Connector işi hata aldığında sistem sessiz kalmaz; admin ne olduğunu, sıradaki adımı ve risk seviyesini görebilir.

**Implementation status:** PR15.3 implements safe failure classification, deterministic retry/backoff, dead-letter state, immutable connector job events, operator-visible `/erp` runtime history, and worker-side safe failure observations. Provider API runtime, credential resolution, import apply, canonical writes, and ERP/source writeback remain closed.

**Kapsam:**

- Retry/backoff politikası
- `dead_letter` state
- Safe failure classification
- Runtime-safe Sentry capture
- Operator-visible job logları
- Activity timeline ile job history bağlantısı
- Kullanıcıya raw provider error değil, ürün diliyle recovery mesajı

**Kapsam dışı:**

- Provider-specific raw error display
- Secret veya raw payload logging
- Notification Center delivery

**AI-ready çıktı:**

- AI Coach güvenli failure pattern'lerinden öneri üretebilir: mapping eksik, credential doğrulanmadı, rate limit ihtimali, retry bekleniyor.

**Doğrulama:**

- Retry count ve next retry zamanı deterministik hesaplanır.
- Dead-letter job tekrar otomatik çalışmaz.
- Sentry context secret, token, password, raw payload içermez.

### PR15.4 - Secure Credential Storage Ve Runtime Boundary

**Ürün değeri:** Canias, custom API, SFTP gibi kaynaklar için gerekli bağlantı bilgileri güvenli şekilde alınabilir; ürün secret değerini göstermez ve product DB'ye düz metin yazmaz.

**Implementation status:** PR15.4 implements the source-independent secure credential runtime boundary: service-role-only opaque reference writes, no-readback credential events, safe UI/AI evidence, and revoked/missing/failed credential blockers for runtime-preflight jobs. Provider API runtime, secret manager implementation, import apply, canonical writes, and ERP/source writeback remain closed.

**Kapsam:**

- Secure credential capture flow
- Server-side secret write boundary
- Product DB'de yalnızca opaque reference
- No-readback modeli
- Credential state geçişleri: `missing`, `handoff_requested`, `configured`, `verified`, `failed`, `revoked`
- Credential update/revoke audit
- Secret scrubbing testleri

**Kapsam dışı:**

- Client-side secret storage
- Secret value readback
- Connector import apply
- ERP writeback

**AI-ready çıktı:**

- AI credential değerini görmez; sadece safe state görür: missing/configured/verified/failed.

**Doğrulama:**

- Secret değerleri app table, Sentry, activity log veya adapter response içinde yoktur.
- Credential reference cross-tenant kullanılamaz.
- Revoked credential runtime job başlatamaz.

### PR15.5 - Runtime Preflight With Credential Reference

**Ürün değeri:** PULS artık sadece "credential gerekli" demekle kalmaz; güvenli referans varsa bağlantı readiness'ını server-side doğrulayabilir.

**Kapsam:**

- Worker üzerinden runtime preflight job
- Credential reference resolver
- Source-independent preflight result
- Canias için read-only connection verification spike olabilir; customer data import yok
- CSV / Excel gibi credential gerektirmeyen kaynaklarda local file readiness korunur

**Kapsam dışı:**

- Import execution
- Apply
- ERP writeback
- AI autonomous action

**AI-ready çıktı:**

- AI Coach connector readiness'ı daha güvenilir yorumlar: credential verified, connection failed, mapping ready, runtime blocked.

**Doğrulama:**

- Missing/revoked credential ile runtime preflight başlamaz.
- Verification sonucu safe error code ile döner.
- Provider response raw şekilde saklanmaz.

**PR15.5 implementation status:** PR15.5 implements a source-independent runtime preflight queue request and worker safe-context handler. Runtime preflight now requires `verified` credential state plus opaque reference availability when credentials are required. The worker records safe setup/credential evidence only; provider API calls, credential readback, import apply, canonical writes, ERP/source writeback, and AI autonomous actions remain closed.

### PR15.6 - AI Runtime Evidence Contract

**Ürün değeri:** Connector runtime ve HR operasyon sinyalleri AI Coach için güvenli ve tutarlı bir veri zemini oluşturur.

**Kapsam:**

- AI'ın okuyabileceği safe evidence contract
- Connector job status, preflight, credential state, import preview, apply readiness, activity timeline sinyallerinin AI context'e bağlanması
- AI önerileri için source disclosure zorunluluğu
- AI suggestion taxonomy: explain, summarize, detect_gap, recommend_next_step, prepare_review
- AI forbidden action taxonomy PR13.7 ile uyumlu kalır

**Kapsam dışı:**

- Live autonomous workflow mutation
- AI tarafından job başlatma
- AI tarafından credential okuma
- AI tarafından import apply veya ERP writeback

**Doğrulama:**

- AI context raw payload veya secret içermez.
- AI önerileri source disclosure ile gelir.
- AI action boundary hâlâ human confirmation gerektirir.

## PR16 - First Controlled Data Movement

PR16, PR15 runtime omurgası üzerinde ilk gerçek data movement'ı açar. Öncelik CSV / Excel olmalıdır; çünkü external API belirsizliği olmadan canonical apply, audit, idempotency ve rollback disiplini kanıtlanabilir.

### PR16.1 - CSV / Excel Controlled Import Execution

**Ürün değeri:** PULS ilk kez kontrollü şekilde canonical modele gerçek veri yazabilir.

**Kapsam:**

- Preview edilmiş ve onaylanmış batch'ten execution job oluşturma
- Worker üzerinden import apply
- Admin-only execution request
- Browser direct apply yok
- Batch mode/status kuralları
- Safe activity event

**Kapsam dışı:**

- Canias API import
- ERP writeback
- AI autonomous apply
- Unapproved batch execution

**AI-ready çıktı:**

- AI Coach import sonucunu özetleyebilir: kaç create/update/skip, hangi domain, hangi riskler.

**Doğrulama:**

- Preview edilmemiş batch apply edilemez.
- Human review ve admin approval olmadan execution job oluşmaz.
- Worker dışında canonical write path kapalı kalır.

### PR16.2 - Batch Lock, Idempotency Ve Audit

**Ürün değeri:** Veri aktarımı tekrar çalışsa bile sistemi bozmaz; enterprise güven için gerekli temel oluşur.

**Kapsam:**

- Batch lock
- Idempotency key enforcement
- Canonical write audit trail
- Row-level apply result
- Identity map update kuralları
- Duplicate execution protection

**Kapsam dışı:**

- Full automatic rollback
- ERP writeback
- Multi-provider conflict resolver UI

**AI-ready çıktı:**

- AI güvenli audit üzerinden "bu değişiklik hangi batch ile geldi?" sorusuna cevap verebilir.

**Doğrulama:**

- Aynı batch iki kez apply edilemez.
- Aynı idempotency key iki kez canonical write üretemez.
- Cross-tenant apply engellenir.

### PR16.3 - Rollback / Compensating Action Model

**Ürün değeri:** Hatalı import durumunda operasyon ekibi neyin nasıl geri alınacağını bilir.

**Kapsam:**

- Apply sonucu için recovery plan metadata
- Written rows summary
- Compensating action tasarımı
- Manuel rollback runbook
- Risk sınıfları

**Kapsam dışı:**

- Tam otomatik rollback execution
- Destructive source overwrite
- ERP writeback

**AI-ready çıktı:**

- AI Coach riskli import sonrası "hangi kayıtlar incelenmeli?" ve "hangi recovery adımı önerilir?" gibi öneriler üretebilir.

**Doğrulama:**

- Her apply job recovery metadata üretir.
- Recovery metadata secret/raw payload içermez.
- Destructive rollback UI action açılmaz.

### PR16.4 - Notification Center Foundation

**Ürün değeri:** Admin ve ilgili roller önemli connector olaylarını ekran aramadan takip eder.

**Kapsam:**

- Notification entity/model
- Connector job tamamlandı, hata aldı, approval bekliyor, credential eksik, import tamamlandı event'leri
- Role-based notification visibility
- Read/unread state
- `/dashboard`, `/erp` ve ileride AI Coach bağlantısı

**Kapsam dışı:**

- Email/push delivery
- External notification provider
- AI autonomous notification action

**AI-ready çıktı:**

- AI Coach notification event'lerini context olarak kullanabilir ve "öncelikli aksiyonlar" üretebilir.

**Doğrulama:**

- Notification cross-tenant okunamaz.
- Secret/raw payload notification içinde yoktur.
- Role visibility doğru çalışır.

### PR16.5 - Canias Runtime Spike On Generic Connector Foundation

**Ürün değeri:** Canias artık sadece metadata/demo profili olmaktan çıkar; generic PULS runtime omurgası üzerinde ilk ERP API connector denemesi başlar.

**Kapsam:**

- Canias connector adapter contract
- Read-only connection test
- Metadata discovery veya declared-field refresh
- Dry-run import batch oluşturma
- Preview üretme
- Runtime logs

**Kapsam dışı:**

- ERP writeback
- Destructive sync
- Direct canonical apply without PR16 controls
- Canias-specific product architecture

**AI-ready çıktı:**

- AI Coach Canias'tan gelen setup/preflight/preview sinyallerini diğer kaynaklarla aynı vocabulary ile yorumlar.

**Doğrulama:**

- Canias runtime generic job queue üzerinden çalışır.
- Provider-specific code generic connector contract dışına taşmaz.
- Raw provider payload UI/AI/Sentry içinde görünmez.

### PR16.6 - AI Operational Recommendations

**Ürün değeri:** HR AI, yalnızca sayfa içi teaser değil; operasyonel verilerden öneri üreten vazgeçilmez bir süreç katmanı haline gelir.

**Kapsam:**

- Connector outcomes + canonical data + workflow state üzerinden öneri üretim sözleşmesi
- Recommendation types:
  - setup_gap
  - mapping_gap
  - data_quality_risk
  - approval_bottleneck
  - import_review_needed
  - employee_data_change_summary
  - policy_or_process_gap
- Source disclosure
- Human confirmation boundary
- Recommendation read model

**Kapsam dışı:**

- AI tarafından otomatik import/apply
- AI tarafından workflow mutation RPC call
- AI tarafından ERP writeback
- AI tarafından credential access

**Doğrulama:**

- Recommendation evidence source'ları görülebilir.
- AI önerisi aksiyon çalıştırmaz; sadece review/draft/next step üretir.
- Sensitive data ve raw connector payload öneri context'ine girmez.

## PR15-PR16 Kabul Kriterleri

PR15-PR16 tamamlandığında PULS şunları diyebilmelidir:

- Çok tenant'lı connector işleri güvenli queue'ya alınabilir.
- Worker işleri browser'dan bağımsız çalıştırır.
- Credential değerleri product DB'de veya UI'da görünmez.
- Runtime preflight güvenli credential reference ile çalışabilir.
- CSV / Excel üzerinden ilk controlled canonical data movement kanıtlanmıştır.
- Apply işlemleri admin approval, batch lock, idempotency ve audit ile korunur.
- Connector job ve import sonuçları Notification Center ve activity timeline'a bağlanır.
- AI Coach connector/runtime/canonical data sinyallerinden güvenli öneriler üretebilir.
- AI hâlâ autonomous mutation, ERP writeback, credential access veya import apply çalıştırmaz.

## Stop Conditions

Bu fazlarda aşağıdaki durumlardan biri görülürse sonraki adıma geçilmemelidir:

- Job queue cross-tenant isolation kanıtlanmadıysa
- Worker duplicate job execution riski varsa
- Credential secret herhangi bir app table, log, Sentry event veya UI response içinde görünüyorsa
- Batch lock/idempotency testleri geçmiyorsa
- Apply audit ve recovery metadata yoksa
- AI context raw payload veya secret taşıyorsa
- Canias-specific kararlar generic connector contract'in yerini alıyorsa

## Sonuç

PR15-PR16, PULS'un connector setup ürünü olmaktan çıkarak gerçek runtime ve HR AI platformuna dönüşmeye başladığı fazdır. En doğru sıra önce queue/worker/credential/runtime safety, sonra controlled CSV / Excel execution, ardından Canias runtime spike ve AI operational recommendations'dır.

Bu sıra sade kalır, RabbitMQ gibi erken karmaşıklıkları ötelemiş olur, ama ileride daha yüksek hacimli queue sistemlerine geçişi de kapatmaz.
