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

**Implementation status:** PR15.6 implements the AI-safe runtime evidence contract, adds the `connector_runtime` context domain to AI Coach, and reads only count/status/source-disclosed signals from connector jobs, worker events, credential state, import preview, and safe activity records. No migration, job start, credential read, import apply, canonical write, ERP/source writeback, or autonomous AI action is added.

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

### PR15.7 - Railway Worker Deployment Readiness

**Ürün değeri:** Queue ve worker kodu gerçek bir arka plan servisi olarak çalışabilir hale gelir; PR16 data movement browser'dan değil worker'dan yürür.

**Implementation status:** PR15.7 makes `services/erp-connector` Railway-deployable with config-as-code, `pnpm start:railway`, `/health`, required environment variables, one-replica guidance, and remote smoke proof. Provider API runtime, credential readback, import apply, canonical writes, ERP/source writeback, and AI autonomous actions remain closed.

**Kapsam:**

- Railway service root/config path contract
- `services/erp-connector/railway.toml`
- Worker start command and healthcheck path
- Required Railway secret/env list
- Heartbeat and `noop_health` smoke procedure
- One-worker guidance until batch lock/idempotency is live

**Kapsam dışı:**

- Canias API runtime
- CSV / Excel import apply
- Provider credentials beyond opaque service env boundary
- Multi-worker horizontal scaling
- ERP/source writeback

**Doğrulama:**

- Railway healthcheck returns 200 without exposing secrets.
- `connector_worker_heartbeats` shows the Railway worker id.
- `noop_health` job is claimed and completed by the Railway worker.
- Worker safe context contains no credential, raw payload, request, or response body.

### PR15.8 - Railway Worker Production Guardrails

**Ürün değeri:** PR16 data movement açılmadan önce Railway worker yanlış ortamda, yanlış job tipiyle veya çift worker penceresiyle çalışamaz hale gelir.

**Implementation status:** PR15.8 adds Railway production guardrails: non-production worker loops are disabled by default, `import_apply` requires an explicit PR16 enablement flag, `railway.toml` pins one replica with zero deploy overlap and graceful drain, and the worker handles shutdown signals cleanly. Provider API runtime, credential readback, import apply execution, canonical writes, ERP/source writeback, and AI autonomous actions remain closed.

**Kapsam:**

- `RAILWAY_ENVIRONMENT_NAME` based non-production disablement
- `PULS_CONNECTOR_WORKER_ALLOW_NON_PRODUCTION` explicit override
- `PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED` explicit apply gate
- `numReplicas = 1`, `overlapSeconds = 0`, `drainingSeconds = 30`
- Railway `watchPatterns` for monorepo-safe deploy scope
- `SIGTERM` / `SIGINT` shutdown handling
- PR16 handoff checklist for enabling `import_apply`

**Kapsam dışı:**

- CSV / Excel apply execution
- Canias runtime
- Provider credentials in Railway
- Multi-worker horizontal scaling
- Autonomous AI execution

**Doğrulama:**

- Preview/staging Railway env does not run worker loop unless explicitly allowed.
- `import_apply` is filtered out unless the PR16 flag is true.
- Health payload exposes guardrail state but never service-role or provider secrets.
- Remote smoke uses `connector_job_events.worker_id` as the canonical worker proof.

## PR16 - First Controlled Data Movement

PR16, PR15 runtime omurgası üzerinde ilk gerçek data movement'ı açar. Öncelik CSV / Excel olmalıdır; çünkü external API belirsizliği olmadan canonical write, audit, idempotency, overwrite policy ve rollback disiplini kanıtlanabilir.

PR16'nın ana kuralı şudur:

> PULS blind overwrite yapmaz. Her canonical write önce preview, change-set, risk sınıfı, before snapshot, admin approval, batch lock ve worker execution sınırından geçer. Delete/tombstone, ERP writeback ve AI autonomous apply kapalı kalır.

CRUD audit kuralı da aynı sertlikte ele alınmalıdır:

> PULS canonical insert, update, soft-delete, restore, rollback veya compensating update yaptığında bunu iş nesnesi seviyesinde loglar. Update gibi overwrite riski taşıyan işlemler ayrıca field-level diff ve rollback snapshot politikasına bağlıdır. Raw kişisel veri UI/AI context'e taşınmaz; hot retention ve purge/archive sınırı PR16 içinde tanımlanır.

### PR16.1 - Apply Safety Contract Ve Permission Hardening

**Ürün değeri:** PULS veri yazmaya başlamadan önce yanlış Excel, eski dosya, hatalı mapping veya accidental overwrite senaryolarını ürün politikasıyla sınırlar.

**Implementation status:** PR16.1 closes the direct apply surface, makes `apply_import_batch(UUID, TEXT)` service-role only, rejects `import_apply` connector jobs until create-only gates exist, and exposes an AI-safe apply safety contract on `/erp`. Canonical writes, Canias API import, ERP/source writeback, rollback execution, and AI autonomous apply remain closed.

**Kapsam:**

- Existing `apply_import_batch` direct kullanım yüzeyinin yeniden değerlendirilmesi
- Browser/authenticated direct apply path'in worker-only/service-role boundary'ye çekilmesi
- CRUD audit tier modeli:
  - object event ledger
  - field diff ledger
  - rollback snapshot
  - optional cold archive summary
- Hot retention policy:
  - object event ledger için daha uzun, tenant-policy uyumlu saklama
  - field diff ledger ve rollback snapshot için 90 gün default sıcak saklama
  - purge/archive ownership
- KVKK odaklı minimization:
  - UI/AI safe summary
  - sensitive before/after values için service-role-only/encrypted boundary
  - raw payload ve provider response readback yok
- Apply policy state modeli:
  - `create_only`
  - `guarded_update`
  - `blocked_destructive`
  - `rollback_preview_required`
- Destructive-equivalent alan sınıfları:
  - `employment_status`
  - `is_active`
  - assignment close/deactivate
  - manager / reporting line
- Missing field vs explicit clear-field ayrımı
- Source ownership ve source priority kuralı
- PR16 flag'leri için enablement checklist

**Kapsam dışı:**

- Canonical write execution
- Canias API import
- ERP writeback
- AI autonomous apply
- Rollback execution

**AI-ready çıktı:**

- AI Coach "neden apply kapalı?", "hangi risk sınıfı var?", "hangi onay eksik?" gibi soruları safe policy evidence üzerinden yanıtlayabilir.

**Doğrulama:**

- Authenticated/browser direct apply mümkün değildir.
- `import_apply` worker claim'i PR16.1 boyunca kapalı kalır veya only dry-run safety job olarak kalır.
- App code eski `apply_import_batch` RPC'yi çağırmaz.
- Policy secret, raw payload veya credential reference içermez.
- Insert, update, soft-delete, restore, rollback ve compensating update için audit policy tanımlanmadan execution açılmaz.
- Field diff ve rollback snapshot retention/purge kararı olmadan high-volume update path açılmaz.

### PR16.2 - Change Set, Before Snapshot Ve Risk Ledger

**Ürün değeri:** Admin neyin değişeceğini satır ve alan seviyesinde görmeden PULS veri yazmaz. Yanlış veri yüklenirse neyin geri alınabileceği apply öncesi bilinir.

**Implementation status:** PR16.2 implements immutable change-set generation from previewed dry-run batches, safe risk ledger summaries on `/erp`, audit tier and retention bucket evidence, idempotent generation by source checksum, and admin-checked RPC boundaries. Canonical writes, worker `import_apply`, ERP/source writeback, credential readback, rollback execution, raw payload readback, and AI autonomous action remain closed.

**Kapsam:**

- Preview edilmiş batch'ten immutable apply change-set üretme
- Field-level before/after diff
- Before row hash ve expected current hash
- Service-role-only rollback snapshot metadata
- Object audit intent:
  - target schema/table/entity
  - canonical object id veya identity candidate
  - operation type: insert/update/soft_delete/restore/rollback/compensating_update
  - actor/job/batch/source evidence
- Audit retention bucket:
  - object event
  - field diff
  - rollback snapshot
- Safe UI summary: create/update/skip/block/risk counters
- Update risk sınıfları:
  - safe additive
  - guarded overwrite
  - destructive-equivalent
  - source conflict
  - stale preview
- `blocked_update_requires_policy` ve `stale_target_requires_repreview`
- AI-safe evidence contract

**Kapsam dışı:**

- Canonical write execution
- Rollback execution
- ERP writeback
- Raw payload readback

**AI-ready çıktı:**

- AI Coach import öncesi risk özetleri üretebilir: "12 create, 3 guarded update, 1 destructive-equivalent blocked."

**Doğrulama:**

- Change-set olmadan apply job oluşturulamaz.
- Before snapshot raw secret/payload içermez.
- Change-set her item için audit granularity ve retention bucket taşır.
- Preview sonrası canonical kayıt değiştiyse apply blocked olur.
- UI yalnızca safe diff özetlerini görür.

### PR16.3 - Create-Only Worker Apply

**Ürün değeri:** PULS ilk gerçek canonical write'ı en düşük riskli şekilde açar: sadece yeni master-data kayıtları oluşturulur, mevcut kayıtlar ezilmez.

**Implementation status:** PR16.3 opens worker-only create apply for admin-approved reference-dimension change-sets. It adds service-role execution RPCs, safe object event audit, `/erp` queue gating, and worker `import_apply` handling behind `PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED=true`. PR16.3A create-only context hardening preserves queued job safe context during Railway worker lease heartbeats after smoke exposed heartbeat context overwrite risk. Browser direct apply, authenticated direct canonical writes, employee apply, guarded updates, deletes, rollback execution, Canias API import, ERP/source writeback, credential readback, raw payload readback, and AI autonomous action remain closed.

**Kapsam:**

- Worker üzerinden `import_apply` job execution
- `PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED=true` için create-only gate
- Preview + review + admin approval + change-set zorunluluğu
- Batch lock
- Idempotency key enforcement for create-only writes
- Reference dimensions first:
  - legal entities
  - locations
  - departments
  - cost centers
  - positions
- Existing target found ise update değil block/skip
- Row-level apply result
- Identity map create/update for newly created records
- Safe activity and connector job event
- Every create emits an object event ledger row with safe business summary.
- Create audit does not store raw source payload or provider response.

**Kapsam dışı:**

- Employee guarded update
- Existing record overwrite
- Assignment close/deactivate
- Delete/tombstone
- ERP writeback
- Canias API import
- AI autonomous apply

**AI-ready çıktı:**

- AI Coach "hangi yeni organizasyon kayıtları oluşturuldu?" sorusunu safe audit üzerinden yanıtlayabilir.

**Doğrulama:**

- Aynı batch iki kez apply edilemez.
- Aynı idempotency key iki create üretemez.
- Existing record update denenirse apply blocked olur.
- Worker dışında canonical write path kapalı kalır.
- Cross-tenant apply engellenir.
- Created objects have row-level apply result plus object-level audit event.

### PR16.4 - Guarded Update Apply

**Ürün değeri:** PULS kontrollü update yapabilir; ancak yanlış dosyanın var olan doğru veriyi sessizce ezmesine izin vermez.

**Implementation status:** PR16.4.1 adds guarded update evidence only: immutable hash-only field diffs, service-role rollback snapshots, admin/service-role evidence generation, authenticated-safe evidence listing, and `/erp` review visibility. PR16.4.2 opens a narrow worker-only guarded update apply path for admin-approved reference-dimension `name` updates with evidence, rollback snapshots, and stale hash revalidation. PR16.4.3 adds a post-apply recovery readiness read model that verifies object events, field diff counts, rollback snapshot posture, hot retention, and purge/archive readiness without opening rollback execution. PR16.4.4 adds an operator-facing recovery runbook read model that classifies rollback-preview candidacy, evidence gaps, and compensating-review handoff while keeping rollback preview/execution closed. Employee updates, destructive-equivalent fields, ERP/source writeback, provider API calls, credential readback, raw payload readback, field value readback, rollback execution, browser direct apply, authenticated direct apply, and AI autonomous apply remain closed.

**Kapsam:**

- Allowlisted field updates
- Existing record overwrite only with:
  - change-set
  - before snapshot
  - expected current hash
  - admin approval
  - source ownership check
  - worker execution
- Missing field does not clear existing value
- Explicit clear-field action ayrı risk olarak işaretlenir
- Destructive-equivalent updates blocked by default
- Employee master guarded update can start with low-risk fields only
- Assignment/status/manager updates require separate approval class
- Canonical write audit trail
- Object event ledger for every update attempt/result
- Field diff ledger for changed fields only
- Sensitive before/after values redacted for UI/AI and retained only through service-role-safe snapshot when rollback requires exact value
- 90-day default hot retention for field diffs and rollback snapshots

**Kapsam dışı:**

- Delete/tombstone sync
- ERP writeback
- Multi-provider conflict resolver UI
- Automatic destructive rollback

**AI-ready çıktı:**

- AI güvenli audit üzerinden "hangi alanlar değişti, hangi alanlar blocked kaldı?" sorusuna cevap verebilir.

**Doğrulama:**

- Stale before hash update'i durdurur.
- Manual lower-priority source higher-priority owned field'i ezemez.
- Empty/missing fields accidental clear yapmaz.
- High-risk alanlar ayrı approval olmadan update olmaz.
- Update audit shows field, old safe value, new safe value, source, approval, job, and risk class without leaking raw payload.

### PR16.5 - Rollback / Compensating Preview And Execution

**Ürün değeri:** Hatalı import durumunda PULS sadece "geçmiş olsun" demez; güvenli geri alma veya telafi batch'i üretir.

**Implementation status:** PR16.5 starts with guarded-update rollback preview only: immutable hash-only rollback preview ledgers, admin/service-role preview generation, authenticated-safe preview listing, current-state drift blockers, and `/erp` review visibility. Rollback execution, compensating preview/execution, ERP/source writeback, provider API calls, credential readback, raw payload readback, snapshot payload readback, field value readback, browser direct apply, authenticated direct rollback, and AI autonomous execution remain closed.

**Kapsam:**

- Apply sonucu için recovery plan metadata
- Before snapshot üzerinden rollback preview
- Compensating batch generation
- Rollback approval policy
- Worker-executed rollback job
- Current hash guard: kayıt apply sonrası başka işlemle değiştiyse rollback blocked
- Written rows summary
- Manual rollback runbook
- Risk sınıfları
- Rollback and compensating execution emit their own object audit events.
- Rollback snapshot usage is service-role-only and retention-limited.
- Purged snapshot durumunda rollback yerine compensating review/runbook önerilir.

**Kapsam dışı:**

- Tek tık destructive rollback
- ERP/source writeback
- Raw payload rollback UI
- Cross-source conflict automation

**AI-ready çıktı:**

- AI Coach riskli import sonrası "hangi kayıtlar incelenmeli?" ve "hangi recovery adımı önerilir?" gibi öneriler üretebilir.

**Doğrulama:**

- Her apply job recovery metadata üretir.
- Recovery metadata secret/raw payload içermez.
- Rollback de preview + approval + worker execution ister.
- Current state drift varsa rollback blocked olur.
- Rollback audit trail links original apply event, rollback preview, approval, worker job, and final result.

### PR16.6 - Guarded Update Rollback Approval

**Ürün değeri:** Hatalı guarded update apply sonrası rollback çalıştırmadan önce admin, tam olarak hangi hash-only preview'i onayladığını kayıt altına alır.

**Implementation status:** PR16.6 records checksum-bound guarded-update rollback approval in an immutable service-role table, exposes authenticated-safe approval summaries in `/erp`, and keeps rollback execution, rollback job enqueue, compensating execution, ERP/source writeback, provider API calls, credential readback, raw payload readback, snapshot payload readback, field value readback, browser direct rollback, and AI autonomous execution closed.

**Kapsam:**

- `connector_apply_rollback_approvals` immutable approval ledger
- `record_connector_guarded_update_rollback_approval` admin/service-role RPC
- `list_connector_guarded_update_rollback_approvals` safe read model
- Preview checksum binding
- Blocker, drift, evidence, snapshot availability, and retention gate checks
- `/erp` rollback approval gate visibility

**Kapsam dışı:**

- Rollback worker execution
- Rollback job enqueue
- Compensating execution
- ERP/source writeback
- Raw rollback payload UI

**Doğrulama:**

- Blocked preview approval kaydedemez.
- Drift veya expired snapshot approval kaydedemez.
- Approval checksum immutable preview checksum'a bağlıdır.
- Approval kaydı rollback execution açmaz.

### PR16.7 - Guarded Update Rollback Worker Readiness

**Ürün değeri:** Rollback approval sonrası rollback worker'a geçmeden önce approval, checksum, current-state, original apply event ve retention kanıtı tek immutable handoff kaydıyla doğrulanır.

**Implementation status:** PR16.7 records checksum-bound guarded-update rollback worker readiness in an immutable service-role table, exposes authenticated-safe readiness summaries in `/erp`, and keeps rollback job enqueue, rollback execution, canonical rollback writes, compensating execution, ERP/source writeback, provider API calls, credential readback, raw payload readback, snapshot payload readback, field value readback, browser direct rollback, and AI autonomous execution closed.

**Kapsam:**

- `connector_apply_rollback_worker_readiness` immutable readiness ledger
- `generate_connector_guarded_update_rollback_worker_readiness` admin/service-role RPC
- `list_connector_guarded_update_rollback_worker_readiness` safe read model
- Approval checksum binding
- Current-state recheck
- Original apply object event, field diff, rollback snapshot, and retention gate checks
- `/erp` rollback worker readiness gate visibility

**Kapsam dışı:**

- Rollback worker execution
- Rollback job enqueue
- Compensating execution
- ERP/source writeback
- Raw rollback payload UI

**Doğrulama:**

- Approval yoksa readiness üretilemez.
- Checksum mismatch readiness üretmez.
- Drift, missing object event veya expired snapshot readiness üretmez.
- Readiness kaydı rollback job enqueue veya execution açmaz.

### PR16.8 - Guarded Update Rollback Worker Apply

**Ürün değeri:** Onaylanmış guarded update rollback artık sadece kanıt seviyesinde kalmaz; service-role worker, checksum ve current-state tekrar kontrollerinden sonra güvenli referans adlarını geri alabilir.

**Implementation status:** PR16.8 opens a worker-only rollback enqueue/execution path from PR16.7 readiness. It restores only safe reference-dimension `name` fields from hash-verified rollback snapshots, emits rollback object events linked to the original apply event, and keeps browser direct rollback, source writeback, provider API calls, credential readback, raw payload readback, snapshot payload readback, field value readback, and compensating execution closed.

**Kapsam:**

- `enqueue_connector_guarded_update_rollback_apply_job` admin/service-role queue RPC
- `execute_connector_guarded_update_rollback_apply_job` service-role worker execution RPC
- PR16.7 readiness, approval, preview, checksum, original apply event, field diff, snapshot, retention ve current-state recheck gate
- Reference-dimension `name` restore helper
- Rollback object events linked to readiness, approval, preview, original apply event and worker job
- ERP connector worker routing for `import_apply_guarded_update_rollback`
- `/erp` rollback worker queue action

**Kapsam dışı:**

- Employee rollback
- Destructive rollback
- Compensating execution
- ERP/source writeback
- Provider API calls
- Browser direct canonical rollback
- Raw snapshot/value UI

**Doğrulama:**

- Non-service-role execution reddedilir.
- Readiness/checksum/current-state/snapshot retention mismatch rollback kuyruğunu veya execution'ı açmaz.
- Worker lease sahibi olmayan job execute edilemez.
- Rollback her satır için `rollback` object event üretir.
- Aynı worker job idempotent, farklı job duplicate rollback yapamaz.

### PR16.9 - Notification Center Foundation

**Ürün değeri:** Admin ve ilgili roller önemli connector olaylarını ekran aramadan takip eder.

**Kapsam:**

- Notification entity/model
- Connector job tamamlandı, hata aldı, approval bekliyor, credential eksik, import tamamlandı event'leri
- Riskli update blocked, stale preview, rollback required event'leri
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

### PR16.10 - Canias Runtime Spike On Generic Connector Foundation

**Ürün değeri:** Canias artık sadece metadata/demo profili olmaktan çıkar; generic PULS runtime omurgası üzerinde ilk ERP API connector denemesi başlar.

**Kapsam:**

- Canias connector adapter contract
- Read-only connection test
- Metadata discovery veya declared-field refresh
- Dry-run import batch oluşturma
- Preview üretme
- Runtime logs
- PR16 safety modeline uygun change-set handoff

**Kapsam dışı:**

- ERP writeback
- Destructive sync
- Direct canonical apply without PR16 safety controls
- Canias-specific product architecture

**AI-ready çıktı:**

- AI Coach Canias'tan gelen setup/preflight/preview sinyallerini diğer kaynaklarla aynı vocabulary ile yorumlar.

**Doğrulama:**

- Canias runtime generic job queue üzerinden çalışır.
- Provider-specific code generic connector contract dışına taşmaz.
- Raw provider payload UI/AI/Sentry içinde görünmez.

### PR16.11 - AI Operational Recommendations

**Ürün değeri:** HR AI, yalnızca sayfa içi teaser değil; operasyonel verilerden öneri üreten vazgeçilmez bir süreç katmanı haline gelir.

**Kapsam:**

- Connector outcomes + canonical data + workflow state üzerinden öneri üretim sözleşmesi
- Recommendation types:
  - setup_gap
  - mapping_gap
  - data_quality_risk
  - approval_bottleneck
  - import_review_needed
  - overwrite_risk
  - rollback_recommended
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
- CSV / Excel üzerinden ilk controlled canonical data movement create-only ve worker-only şekilde kanıtlanmıştır.
- Blind overwrite kapalıdır; update ancak change-set, before snapshot, source ownership, stale hash guard ve admin approval ile açılır.
- Apply işlemleri admin approval, batch lock, idempotency, change-set, before snapshot, CRUD audit, retention policy ve recovery metadata ile korunur.
- Insert/update/soft-delete/restore/rollback/compensating update operasyonlarının object-level audit policy'si vardır.
- Update operasyonları field-level diff ve rollback snapshot retention sınırıyla korunur.
- Rollback veya compensating action preview + approval + worker execution olmadan çalışmaz.
- Connector job ve import sonuçları Notification Center ve activity timeline'a bağlanır.
- AI Coach connector/runtime/canonical data sinyallerinden güvenli öneriler üretebilir.
- AI hâlâ autonomous mutation, ERP writeback, credential access veya import apply çalıştırmaz.

## Stop Conditions

Bu fazlarda aşağıdaki durumlardan biri görülürse sonraki adıma geçilmemelidir:

- Job queue cross-tenant isolation kanıtlanmadıysa
- Worker duplicate job execution riski varsa
- Credential secret herhangi bir app table, log, Sentry event veya UI response içinde görünüyorsa
- Batch lock/idempotency testleri geçmiyorsa
- Change-set ve before snapshot üretilmeden canonical write açılıyorsa
- Blind overwrite veya missing-field clear riski varsa
- CRUD audit, field diff retention veya recovery metadata yoksa
- Purge/archive owner tanımlanmadan high-volume update path açılıyorsa
- Rollback preview/approval/current-hash guard yoksa
- AI context raw payload veya secret taşıyorsa
- Canias-specific kararlar generic connector contract'in yerini alıyorsa

## Sonuç

PR15-PR16, PULS'un connector setup ürünü olmaktan çıkarak gerçek runtime ve HR AI platformuna dönüşmeye başladığı fazdır. En doğru sıra önce queue/worker/credential/runtime safety, sonra overwrite-safe controlled CSV / Excel execution, ardından Canias runtime spike ve AI operational recommendations'dır.

Bu sıra sade kalır, RabbitMQ gibi erken karmaşıklıkları ötelemiş olur, ama ileride daha yüksek hacimli queue sistemlerine geçişi de kapatmaz.
