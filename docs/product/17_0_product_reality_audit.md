# PR17.0 — Product Reality Audit & Closed-Loop HR Gap Map

> **Durum:** Resmi PR17.0 ürün karar dokümanı / yol haritası (kod contract'ı değil; verify-script gerektirmez).
> **Tarih:** 2026-06-11 · **Rev 20** (PR17.2G4C OCR local extraction benchmark eklendi: `pdf_text` route, Türkçe locale parse validation, synthetic fixture contract ve network-free benchmark runner tamamlandı; browser enqueue, Railway deploy, canonical expense write ve paid OCR/VLM provider hâlâ kapalı). Önceki: Rev 19 (PR17.2G4B OCR queue resilience proof).
> **Kapsam:** Read-only denetim. Kod değiştirilmedi.
> **Yöntem:** 19 ürün route'u (~10.000 satır UI), 74 migration, data adapter'lar, RLS/RPC kontratları, audit trigger'ları, notification ledger'ı ve AI context yüzeyleri okundu. 6 paralel keşif ajanı + hedefli backend doğrulamaları.
> **Önkoşul bağlam:** PR16.10.13-20 tamamlandı (DataSource split, runtime hardening, audit/policy guard'ları, CI verify gate). Hedef: connector-bağımsız, kapalı devre AI HR App ürünleşmesi (PR17).

---

## 0. Executive Summary

> ### 🔄 Rev 20 güncel durum (PR17.1A-D + PR17.2A-F3 + PR17.2G1/G2A/G2B/G3/G3A + G4/G4A/G4B/G4C sonrası)
>
> Aşağıdaki §0-§6 metni **PR17 öncesi** durumu anlatır (tarihsel referans). PR17.1 ve PR17.2 dilimleri landıktan sonra yapılan re-audit'in sonuçları:
>
> | Risk / hedef                                 | PR                                                                                                                                  | Yeni durum     | Kanıt                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
> | -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
> | **R3** org/performans audit yok              | 17.1A                                                                                                                               | ✅ **KAPANDI** | `puls_core.{departments,positions,employees}` + `performance_cycles` audit trigger → `puls_audit.audit_logs` (mig 20260609120000)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
> | departman/pozisyon soft-delete yok           | 17.1B                                                                                                                               | ✅ **KAPANDI** | `deactivate/restore_{department,position}` RPC + bağımlılık guard'ları + UI (mig 20260609130000)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
> | **R10** çalışan atama düzeltme yok           | 17.1C                                                                                                                               | ✅ **KAPANDI** | `update_employee_assignment` RPC, server-validated + audited + ERP-source korumalı; calisanlar.tsx gerçek form (mig 20260609140000)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
> | şirket profili kilitli                       | 17.1D                                                                                                                               | ✅ **KAPANDI** | `update_company_profile` RPC (ad/sektör/dil/tz), audited; sirket-kurulum.tsx gerçek form (mig 20260609150000)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
> | **R1** HR workflow notification              | 17.2A/B/C/D                                                                                                                         | ✅ **KAPANDI** | Producer + 6-olay taxonomy + prefs UI + live DB dispatch tamam; teslimat connector worker beklemez                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
> | **R7** workflow e2e                          | 17.2B/D/E                                                                                                                           | 🟡 **KISMİ**   | DB-boundary rollback-only smoke artık live dispatch + reconcile no-duplicate guard'ı kanıtlar; gerçek tarayıcı UI e2e ve tenant'ta multi-step policy yoksa zorunlu multi-step kanıtı hâlâ ürün/QA kuyruğudur                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
> | **R11** connector-bağımlı bildirim teslimatı | 17.2D                                                                                                                               | ✅ **KAPANDI** | Workflow row triggers same-transaction notification dispatch yapar; `run_app_notification_producers` backfill/reconcile yolu olarak kalır                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
> | **R8** belge/evidence upload                 | 17.2F1/F2/F3 + 17.2G1/G2A/G2B/G3/G3A tamam; G4 karar dokümanı + G4A quota gate + G4B queue resilience + G4C local benchmark eklendi | 🟡 **KISMİ**   | Private storage + staging + intent/finalize RPC + submit-with-evidence + leave/expense/contract UI tamam; attached evidence viewing açıldı; expense receipt OCR queue/result/event DB contract var; disabled worker skeleton server-side hash hesaplayabilir ve lease heartbeat atar; human review decision UI/RPC tamam; self-review ve unauthorized actor negatif smoke kapalı; G4 vendor/VLM evaluation dokümanı VLM benchmark yönünü tanımlar; G4A service-role enqueue'u tenant posture, quota, spend cap, provider allowlist ve file/page limitleriyle kapılar; G4B stale lease recover/retry/dead-letter ve receipt projection tutarlılığını kanıtlar; G4C `pdf_text` free-route extraction ve sentetik benchmark harness ekler; browser enqueue ve provider entegrasyonu hâlâ kapalı |
>
> **Net:** PR17.1 Core HR closed-loop **gerçekten kapandı** (audit + lifecycle + edit, hepsi server-validated/audited). PR17.2 notification platformu artık **connector-bağımsız canlı teslimat** yapar: workflow event trigger'ları notification ledger'a metadata-only kayıt düşer, mevcut producer orchestrator ise duplicate-safe backfill/reconcile yolu olarak kalır. PR17.2E bu sözleşmeyi `docs/data/17_2_e_workflow_e2e_reconcile_smoke.sql` ile kilitledi. PR17.2F1/F2 belge/evidence upload'ın storage/RPC ve browser form kenarını açtı; PR17.2F3 finalize aşamasını gerçek storage size metadata kontrolüyle sertleştirdi. PR17.2G1 attached evidence görüntüleme kenarını açtı: yetkili kullanıcılar private `workflow-evidence` Storage RLS sınırı içinde kısa TTL signed URL alır; public URL yoktur. PR17.2G2A expense receipt OCR/extraction için DB contract'ı ekledi: service-role-only enqueue/claim/heartbeat/complete/recover RPC'leri, result ledger, duplicate suspicion ve immutable event log var. PR17.2G2B ayrı worker skeleton'ı ekledi: private storage object indirir, server-side SHA-256 hesaplar ve disabled/mock provider result'ını G2A RPC'leriyle tamamlar. PR17.2G3 human review boundary'yi ekledi; PR17.2G3A bu boundary'yi self-review blokajı ve unauthorized/requester negatif smoke ile sertleştirdi. PR17.2G4 karar dokümanı pahalı vertical OCR yerine VLM/document-to-JSON benchmark yönünü, provider enum mapping'ini, route coverage ölçümünü ve quota/spend/KVKK kapılarını netleştirdi. PR17.2G4A tenant/global OCR posture tablolarını ve enqueue quota gate'ini ekledi; service-role enqueue artık default kapalıdır ve ancak tenant flag, quota, spend cap, provider allowlist, file/page limitleri geçerse iş kuyruğa alınır. PR17.2G4B queue resilience borcunu kapattı: worker claim sonrası heartbeat atar, stale lease recovery retry/dead-letter davranışını ve receipt `ocr_status` projection tutarlılığını rollback smoke kanıtlar. PR17.2G4C free-route ölçüm zeminini açtı: `pdf_text` local extraction, Türkçe amount/date/currency parser, adversarial sentetik fixture ve network-free benchmark runner var. Kalan G4 işi gerçek benchmark veri/KVKK/bütçe/region kararları açılırsa paid provider benchmark ve sonrasında production integration'dır. Pahalı OCR provider'ı varsayılan yol değildir; structured parse/PDF text/duplicate/manual fallback önce gelir.

> #### PR17.2 alt faz kararı (Rev20)
>
> | Faz                                                    | Amaç                                                                                                                                                                                   | Durum                                                |
> | ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
> | **17.2A-D**                                            | Workflow notification taxonomy, producer, preferences ve connector-bağımsız live dispatch                                                                                              | ✅ Tamamlandı                                        |
> | **17.2E — Workflow E2E Baseline & Reconcile Contract** | İzin/masraf request→approve→notify→audit akışını eşdeğer full-stack DB-boundary smoke ile kanıtla; producer reconcile/backfill'in duplicate yaratmadığını regression guard ile kilitle | ✅ Tamamlandı                                        |
> | **17.2F1 — Evidence Upload Backend Boundary**          | Private storage bucket, staging table, intent/finalize RPC, domain metadata RLS hardening, contract attach RPC ve metadata-only audit                                                  | ✅ Tamamlandı                                        |
> | **17.2F2 — Evidence Upload Product Flow**              | İzin eki, masraf fişi ve sözleşme belgesi UI akışlarını F1 boundary'ye bağla; required evidence submit contract'ını aç                                                                 | ✅ Tamamlandı                                        |
> | **17.2F3 — Evidence Finalization Hardening**           | Finalize aşamasında actual storage object size metadata kontrolü, localized evidence RPC errors ve G öncesi trust-boundary sertleştirmesi                                              | ✅ Tamamlandı                                        |
> | **17.2G1 — Evidence Viewing Access**                   | Attached evidence için authorized read model + kısa TTL signed URL + compact view action; OCR yok                                                                                      | ✅ Tamamlandı                                        |
> | **17.2G2A — OCR DB Contract**                          | Expense receipts için provider-agnostic queue/result/event schema + service-role-only RPC contract; üretim enqueue/worker/provider yok                                                 | ✅ Tamamlandı                                        |
> | **17.2G2B — OCR Worker Skeleton**                      | Disabled-by-default worker: private storage read, server SHA-256, mock/disabled provider adapter, no external provider call                                                            | ✅ Tamamlandı                                        |
> | **17.2G3 — Human Review UI**                           | OCR önerilerini belgeyle yan yana göster; accept/correct/reject/new-document decision; canonical write yok                                                                             | ✅ Tamamlandı                                        |
> | **17.2G3A — OCR Review Hardening**                     | Self-review blokajı, unauthorized/requester negatif smoke, structured correction ve queue recover/dead-letter G4 backlog netliği                                                       | ✅ Tamamlandı                                        |
> | **17.2G4 — Vendor/VLM Evaluation & Benchmark Gate**    | VLM/document-to-JSON, OCR-only ve vertical parser yollarını maliyet/token/rate-limit/KVKK/Türkçe belge benchmark/quota guard'larıyla karşılaştır; production enqueue kapalı kalsın     | 🟡 Karar dokümanı eklendi; mühendislik kapıları açık |
> | **17.2G4A — OCR Tenant Posture & Quota Gate**          | Tenant/global OCR posture, quota/spend cap, provider allowlist, file/page limit ve safe cost metering ile service-role enqueue'u default kapalı hale getir                             | ✅ Tamamlandı                                        |
> | **17.2G4B — OCR Queue Resilience Proof**               | Worker heartbeat, stale lease recover, retry, dead-letter ve receipt `ocr_status` projection tutarlılığını provider/browser enqueue açmadan kanıtla                                    | ✅ Tamamlandı                                        |
> | **17.2G4C — OCR Local Extraction Benchmark**           | `pdf_text` free-route extraction, Türkçe locale parser, synthetic fixture contract ve network-free benchmark runner ekle; paid provider/customer dataset yok                           | ✅ Tamamlandı                                        |

**Tek cümlelik gerçek:** PULS'un _gerçek backend workflow motoru_ (RPC + RLS + audit trigger + approver resolver), _gerçek notification platformu_, _attached evidence görüntüleme kenarı_ ve masraf fişi OCR human-review sınırı artık HR workflow için bağlı; izin/masraf submit ve decision event'leri connector beklemeden Notification Center'a düşer. **AI context yüzeyi hâlâ HR mutation'larından beslenmiyor.**

Senin tanımladığın tam döngü — **oluştur → gönder → onayla → audit → notification → belge/evidence → AI context** — izin ve masraf için artık hardened evidence upload + authorized evidence viewing + masraf OCR review boundary kenarına kadar ilerledi. Kalan sistemik açıklar **production OCR enqueue/vendor kapıları**, **tarayıcı e2e kanıtı** ve **AI context** katmanıdır.

### Sayfa kategorileri

| Kategori                                                                      | Sayfalar                                                                   | Durum                                                                 |
| ----------------------------------------------------------------------------- | -------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| **Gerçek workflow (backend + notification + evidence upload/viewing/review)** | izin, masraf                                                               | Production OCR provider/enqueue, AI context ve browser e2e açık       |
| **Gerçek setup/lifecycle CRUD**                                               | departmanlar, pozisyonlar, izin-tanımları, masraf-kategorileri, performans | Audit/RPC zemini güçlü; bazı ürün döngüsü aksiyonları hâlâ eksik      |
| **Partial ürün yüzeyi**                                                       | dashboard, çalışanlar, şirket-kurulum, sözleşmeler, ayarlar                | Seçilmiş mutation/tercih akışları gerçek; tüm sayfa closed-loop değil |
| **Stub / teaser**                                                             | performans-parametreleri, kariyer, eğitim, iş-değerleme, ai-koc            | Gerçek ürün akışı yok veya bilinçli teaser                            |
| **Stabil connector yüzeyi**                                                   | verikaynakları                                                             | PR16.10.13-20 sonrası kabul                                           |

> **Envanter:** 19 ürün route'u denetlendi (`/menu` ve `/erp redirect` kapsam dışı). Workflow/core setup tarafı artık gerçek RPC, RLS, audit ve notification zeminine sahip; partial/stub/teaser ailesi hâlâ PR17'nin ürünleştirme yükünü taşıyor.

### Üç sistemik açık

1. ✅ **Notification kenarı HR workflow'unda bağlı (Rev5/6/7).** Ledger/center/realtime hazır; connector/runtime + file import producer'ları çalışıyor; PR17.2A-D ile HR workflow producer, preferences UI ve connector-bağımsız live dispatch tamamlandı. PR17.2E, live dispatch + reconcile/backfill duplicate-safety contract'ını DB-boundary rollback-only smoke ile kilitledi. Kalan notification işi artık gerçek tarayıcı UX e2e ve gelecek kanalların ürün kararıdır.
2. **Belge/evidence kenarı kısmi kapandı (HIGH→MEDIUM).** İzin eki, masraf fişi ve sözleşme dokümanı artık private storage + staging + RPC + form akışına bağlı; attached evidence görüntüleme/indirme UX'i PR17.2G1 ile açıldı. Masraf fişi OCR/extraction DB contract'ı PR17.2G2A ile eklendi; disabled worker skeleton ve server-side SHA-256 yolu PR17.2G2B ile eklendi; human review UI/RPC PR17.2G3 ile tamamlandı. Üretim enqueue ve provider seçimi özellikle PR17.2G4 konusudur.
3. **AI context kenarı kopuk (HIGH).** `src/lib/data/ai-coach/` var ama hiçbir HR sayfasından beslenmiyor; `/ai-koc` PR16.10.16'da dürüst "coming soon" teaser'a indirildi.
4. **STUB/productization ailesi açık (MEDIUM).** Sözleşmeler, performans parametreleri, kariyer, eğitim ve iş-değerleme hâlâ gerçek kapalı döngü ürün yüzeyi değil; PR17.3'ün ana yükü burada.

**Ortalama readiness: ~63/100** (Rev20; 19 route). PR17.1 Core HR dilimleri ve PR17.2 notification/evidence upload/viewing/OCR-DB-contract/worker-skeleton/human-review/quota/resilience/local-benchmark dilimleri skorları belirgin yükseltti; STUB ailesi (performans-param/kariyer/eğitim/iş-değerleme) ve sözleşmelerin kalan ürün akışları hâlâ ortalamayı aşağı çekiyor — PR17.3'ün konusu.

---

## 1. Sayfa Sayfa Tablo (özet)

| #   | Sayfa                       | Hedef kullanıcı    | UI gerçekliği                                                                                                                                                                                                                                                                                                 | Backend                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Closed-loop                                                                                                                                                             | Connector bağımsız                       | Skor           |
| --- | --------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- | -------------- |
| 1   | `/dashboard`                | Hepsi              | Read-only + navigasyon; demo fallback                                                                                                                                                                                                                                                                         | `puls_calc.*` SELECT, RLS ✓                                                                                                                                                                                                                                                                                                                                                                                                                                        | ❌ (yönlendirir)                                                                                                                                                        | MEDIUM                                   | **75**         |
| 2   | `/calisanlar`               | Manager/HR         | **Rev4:** gerçek atama edit formu (dept/poz/cc/manager); ERP kaydı read-only                                                                                                                                                                                                                                  | `update_employee_assignment` RPC + audit ✓ (PR17.1C)                                                                                                                                                                                                                                                                                                                                                                                                               | 🟡 Partial (edit kapalı, salt-okuma değil)                                                                                                                              | **YES**                                  | ~~65~~ **80**  |
| 3   | `/departmanlar`             | HR admin           | **Gerçek CREATE/UPDATE** + **Rev4:** deactivate/restore lifecycle                                                                                                                                                                                                                                             | `puls_core.departments` + guardrail + **audit trigger + lifecycle RPC** ✓ (PR17.1A/B)                                                                                                                                                                                                                                                                                                                                                                              | ✅ Kapalı (CRUD+lifecycle+audit)                                                                                                                                        | **YES**                                  | ~~72~~ **85**  |
| 4   | `/pozisyonlar`              | HR admin           | **Gerçek CREATE/UPDATE** + **Rev4:** deactivate/restore lifecycle                                                                                                                                                                                                                                             | `puls_core.positions` + guardrail + **audit trigger + lifecycle RPC** ✓ (PR17.1A/B)                                                                                                                                                                                                                                                                                                                                                                                | ✅ Kapalı (CRUD+lifecycle+audit)                                                                                                                                        | **YES**                                  | ~~71~~ **84**  |
| 5   | `/sirket-kurulum`           | Admin/HR           | Read-only checklist + **Rev4:** şirket profili edit formu (ad/sektör/dil/tz)                                                                                                                                                                                                                                  | `update_company_profile` RPC + audit ✓ (PR17.1D); tax/legal read-only                                                                                                                                                                                                                                                                                                                                                                                              | 🟡 Partial (profil editable, checklist read-only)                                                                                                                       | MEDIUM                                   | ~~68~~ **80**  |
| 6   | `/izin`                     | Employee + Manager | **Tam workflow**: oluştur→onayla; approver UI; **Rev12:** gerekli belge upload + attached evidence görüntüleme açık                                                                                                                                                                                           | `create/decide` RPC + audit ✓; **Rev5:** same-transaction notification dispatch ✓; **Rev9:** `create_leave_request_with_evidence` ✓; **Rev12:** Storage RLS signed URL ✓                                                                                                                                                                                                                                                                                           | 🟡 Backend+notification+evidence upload/view tamam; AI/e2e eksik                                                                                                        | MEDIUM                                   | ~~82~~ **89**¹ |
| 7   | `/izin-tanimlari`           | HR admin           | **Tam lifecycle**: create/update/deactivate/restore + audit history + policy binding                                                                                                                                                                                                                          | `leave_types` RLS (admin-write) + lifecycle audit                                                                                                                                                                                                                                                                                                                                                                                                                  | 🟡 Setup mutation                                                                                                                                                       | MEDIUM                                   | **80**¹        |
| 8   | `/masraf`                   | Employee + Manager | **Tam workflow** + server receipt policy; **Rev20:** gerekli fiş/belge upload + attached evidence görüntüleme açık, OCR DB contract + disabled worker skeleton + human review panel var; service-role OCR enqueue quota-gated, queue resilience kanıtlı, local `pdf_text` benchmark var, OCR vendor seçilmedi | `create/decide` RPC; `PULS_RECEIPT_REQUIRED` ✓; **Rev5:** same-transaction notification dispatch ✓; **Rev9:** `create_expense_claim_with_evidence` ✓; **Rev12:** Storage RLS signed URL ✓; **Rev13:** `expense_receipt_ocr_*` DB contract ✓; **Rev14:** worker skeleton ✓; **Rev17:** `record_expense_receipt_ocr_review` ✓; **Rev18:** OCR tenant posture/quota gate ✓; **Rev19:** heartbeat/recover/dead-letter smoke ✓; **Rev20:** local `pdf_text` benchmark ✓ | 🟡 Backend+notification+evidence upload/view/OCR DB+disabled worker+human review+quota gate+queue resilience+local benchmark tamam; browser enqueue/vendor/AI/e2e eksik | MEDIUM                                   | ~~80~~ **91**¹ |
| 9   | `/masraf-kategorileri`      | HR admin           | **Tam lifecycle** + cost-center readiness (read-only) + routing warnings                                                                                                                                                                                                                                      | `expense_categories` RLS + lifecycle audit                                                                                                                                                                                                                                                                                                                                                                                                                         | 🟡 Setup mutation                                                                                                                                                       | MEDIUM (cost-center ERP köprüsü)         | **78**¹        |
| 10  | `/sozlesmeler`              | HR/Employee        | **Partial** — sözleşme belgesi PDF upload + attached document görüntüleme açık; reminder "coming soon"                                                                                                                                                                                                        | `puls_workflow.contracts` + `contract_files`; PR17.2F1/F2 attach RPC + metadata RLS ✓; **Rev12:** Storage RLS signed URL ✓                                                                                                                                                                                                                                                                                                                                         | 🟡 Partial (document evidence açık, reminder/e-signature yok)                                                                                                           | MEDIUM                                   | ~~25~~ **48**  |
| 11  | `/performans`               | Manager            | **Gerçek create + status transition**; DB lifecycle trigger + tek-active index; **close UI yok**                                                                                                                                                                                                              | `performance_cycles` + lifecycle ✓; **Rev4:** audit trigger eklendi (PR17.1A)                                                                                                                                                                                                                                                                                                                                                                                      | 🟡 Partial (close UI yok, notif yok; audit artık var)                                                                                                                   | **YES**                                  | ~~72~~ **75**  |
| 12  | `/performans-parametreleri` | HR admin           | **STUB** — Edit disabled (gerekçesiz), display-only; seed-only                                                                                                                                                                                                                                                | `competency_templates`/`kpi_weights`/`score_bands` SELECT, RLS ✓                                                                                                                                                                                                                                                                                                                                                                                                   | ❌ STUB                                                                                                                                                                 | YES                                      | **15**         |
| 13  | `/verikaynaklari`           | Connector admin    | **Tam connector loop** (create→preview→apply→rollback); hardened                                                                                                                                                                                                                                              | `erp_*` + worker RPC, credential boundary, audit ✓                                                                                                                                                                                                                                                                                                                                                                                                                 | ✅ Kapalı (connector domeni)                                                                                                                                            | N/A                                      | **82**         |
| 14  | `/kariyer`                  | Employee/Manager   | **STUB** — "Create Plan" sheet açar ama submit disabled; AI Coach disabled; demo seed                                                                                                                                                                                                                         | `puls_core.employees` + `puls_performance.career_profiles`/`training_needs` SELECT, RLS ✓                                                                                                                                                                                                                                                                                                                                                                          | ❌ STUB                                                                                                                                                                 | MEDIUM (development plan demo-hardcoded) | **25**         |
| 15  | `/egitim`                   | Employee/Manager   | **STUB** — buton/handler yok; demo seed; "school teaser" coming-soon                                                                                                                                                                                                                                          | `puls_performance.training_needs` SELECT, RLS ✓                                                                                                                                                                                                                                                                                                                                                                                                                    | ❌ STUB                                                                                                                                                                 | YES                                      | **20**         |
| 16  | `/is-degerleme`             | HR admin           | **STUB (backend dahil)** — `fetchRealJobEvaluationOverview()` her zaman boş döner                                                                                                                                                                                                                             | **Gerçek backend yok** — yalnız demo fixture                                                                                                                                                                                                                                                                                                                                                                                                                       | ❌ STUB                                                                                                                                                                 | N/A (backend yok)                        | **15**         |
| 17  | `/ayarlar`                  | Hepsi              | **Rev4:** notification preferences paneli bağlı (gerçek upsert/clear mutation); diğer alanlar read-only                                                                                                                                                                                                       | `puls_calc`/`puls_integration`/`puls_audit` SELECT; **`upsert/clear AppNotificationPreference` wired** (PR17.2C)                                                                                                                                                                                                                                                                                                                                                   | 🟡 Partial (notif prefs editable)                                                                                                                                       | MEDIUM                                   | ~~45~~ **70**  |
| 18  | `/ai-koc`                   | Hepsi              | **Dürüst teaser** (PR16.10.16) — composer disabled, "soon" pill; mesaj hiçbir yere gitmiyor                                                                                                                                                                                                                   | **AI context altyapısı production-ready ama UI'a/LLM'e bağlı değil**: 9 domain snapshot + runtime evidence contract + allowed/forbidden actions (context-readiness.ts)                                                                                                                                                                                                                                                                                             | ❌ (PR17.4 yüzeyi)                                                                                                                                                      | MEDIUM                                   | **15**         |
| 19  | `/profil`                   | Hepsi              | Read-only dashboard; edit/security disabled; **gerçek logout** + persona-switch audit                                                                                                                                                                                                                         | `puls_core.employees` + `puls_calc.*` SELECT, RLS ✓; logout `signOut()`; `logPersonaSwitch()` audit                                                                                                                                                                                                                                                                                                                                                                | 🟡 Partial (logout)                                                                                                                                                     | HIGH                                     | **72**         |

¹ _Ajan bu sayfalara backend kalitesi açısından 82-92 verdi. Tam döngü tanımına göre (notification + AI context dahil) tempolayarak düşürüldü — backend mükemmel, döngünün son 2 kenarı eksik._

---

## 2. Sayfa Sayfa Detay ve Kanıtlar

Her sayfa için: **(1) Ürün amacı · (2) Hedef kullanıcı · (3) UI durumu · (4) Backend durumu · (5) Eksik full-stack işler · (6) Closed-loop readiness · (7) Connector bağımsızlık · (9) Skor · (10) Önerilen faz.**

---

### 2.1 `/dashboard` — dashboard.tsx (519 satır)

**1. Ürün amacı:** Tenant'ın HR durumunu tek bakışta gösteren özet + bekleyen aksiyonlara yönlendirme.
**2. Hedef kullanıcı:** Tüm roller.
**3. UI durumu:** **Sıfır mutation.** Tüm queue (q1-q4) ve quick-action kartları yalnızca navigasyon:

- `q1 → /performans` (dashboard.tsx:115-120), `q2 → /verikaynaklari` (122-130), `q3 → /izin` (132-140), `q4 → /masraf` (142-150)
- Quick action kartları → `/izin`, `/masraf`, `/performans` (489-513)
- Demo fallback: `isDashboardEmpty()` (overview.ts:95-106) boş tenant'ta empty-state tetikler (254-290); demo pill `source === 'demo'` ise (233).

**4. Backend:** Tümü SELECT — `puls_calc.dashboard_overview` (308-313), `puls_integration.erp_connections` (314-335), `puls_calc.leave_overview` (337-343), `puls_workflow.leave_balances` (344-350), `puls_calc.expense_overview` (352-359). RLS: `current_tenant_id()` server-side (migration 20260520130000:158-170).

**5. Eksik işler:** Audit yok (görüntüleme izlenmiyor); real-time yok (manuel refetch); queue statik — role/pending'e göre dinamik değil.
**6. Closed-loop:** ❌ — iş başlatılıp bitirilemiyor, yönlendirir.
**7. Connector bağımsız:** MEDIUM — ERP connection metadata okuyor ama gerektirmiyor.
**9. Skor:** **75/100** — temiz read-only, RLS + demo fallback sağlam; eksik: audit, real-time, dinamik queue.
**10. Faz:** PR17.1 (dinamik queue) + PR17.2 (pending action besleme).

---

### 2.2 `/calisanlar` — calisanlar.tsx (656 satır)

**1. Ürün amacı:** Çalışan listesi + atama gereksinim (readiness) tanısı.
**2. Hedef kullanıcı:** Manager / HR admin (employee persona reddedilip yönlendiriliyor — 278-291).
**3. UI durumu:** **Sıfır mutation, tamamen read-only.** `EmployeeRow` sadece read-only detay sheet açar (600). Detay: dept, pozisyon, cost center, manager, e-posta, izin bakiyesi — hepsi read-only (510-577). Boundary notu: _"erpNoWrite: ERP-synced employee data cannot be edited from PULS"_ (579-581). Demo pill (310).

**4. Backend:** `puls_core.employees` SELECT (employee-assignment-readiness.ts üzerinden); `puls_calc.leave_overview` (213-217). RLS: `employees_tenant_select` SELECT-only (migration 20260520130000:233-236); `employees_self_update` yalnız `user_id = auth.uid()` (238-242) → manager toplu düzenleyemez.

**5. Eksik işler:** Eksik atamayı düzeltme UI'ı yok (en kritik); export/rapor yok; manager remediation kuyruğu yok; audit/notif yok.
**6. Closed-loop:** ❌ — tanı var, tedavi yok; başka sayfaya gitmek gerekiyor.
**7. Connector bağımsız:** MEDIUM-HIGH — saf PULS org yapısı gösteriyor; atama verisi ERP'den gelebilir (`source` alanı).
**9. Skor:** **65/100** — iyi read-only UX (filtre/arama/role-gate/detay) ama düzeltme yok değer düşürüyor.
**10. Faz:** PR17.1 — PULS-kaynaklı çalışanlar için atama düzenleme.

---

### 2.3 `/departmanlar` — departmanlar.tsx (406 satır)

**1. Ürün amacı:** Departman tanımlama ve yönetimi (org yapısının temeli).
**2. Hedef kullanıcı:** HR admin.
**3. UI durumu:** **Gerçek CREATE/UPDATE var.**

- CREATE: `createDepartment()` (133; adapter organization.ts:388-410) → `pulsCore().from('departments').insert({...})`; toast `orgSetupCrud.department.created` (139).
- UPDATE: `updateDepartment()` (129; organization.ts:412-444) → `.update({...}).eq('tenant_id').eq('id')`.
- DELETE: **yok.** ERP-kaynaklı kayıtlar kilit ikonu (285); demo fallback `fetchDemoDepartmentsOverview()` (270).

**4. Backend:** `puls_calc.organization_overview` + `puls_core.departments` SELECT; INSERT/UPDATE. **Server-side validation (mandatory)** — guardrail trigger `validate_department_setup_guardrails()` (migration 20260529110000:26-86):

- `PULS_ORG_DEPARTMENT_SOURCE_READ_ONLY` (39) — ERP kaydı update bloklu
- `_NAME_REQUIRED`, `_CODE_REQUIRED`, `_CODE_INVALID` (regex `^[a-z][a-z0-9_]{1,63}$`) (45-54)
- `_MANAGER_INVALID` (57-67), `_COST_CENTER_INVALID` (69-79)
- Unique `(tenant_id, code)`.
  RLS: `departments_tenant` FOR ALL, `tenant_id = current_tenant_id()` (migration 20260520130000:222-225).

**5. Eksik işler:** **Audit yok** (`puls_audit.audit_logs` var ama dept mutation'ında trigger yok); soft-delete/deactivate yok; notif yok; manager atama UI'ı yok (backend destekliyor); cost-center form alanı yok.
**6. Closed-loop:** 🟡 Partial — create/edit çalışıyor, lifecycle (deactivate/hierarchy) yok.
**7. Connector bağımsız:** **YES** — saf PULS core.
**9. Skor:** **72/100** — fonksiyonel CRUD + sağlam server validation; eksik: audit, soft-delete, bulk, manager/cost-center UI.
**10. Faz:** PR17.1.

---

### 2.4 `/pozisyonlar` — pozisyonlar.tsx (479 satır)

**1. Ürün amacı:** Pozisyon (kadro) tanımlama, departmana bağlama, norm headcount.
**2. Hedef kullanıcı:** HR admin.
**3. UI durumu:** **Gerçek CREATE/UPDATE.**

- CREATE: `createPosition()` (179; organization.ts:446-465) → insert `{tenant_id, name, code, department_id, norm_headcount, is_active}`.
- UPDATE: `updatePosition()` (175; organization.ts:467-499).
- DELETE: yok; ERP kaydı kilit (325).

**4. Backend:** `organization_overview` + `positions` + `departments` (dropdown) SELECT; INSERT/UPDATE. Guardrail trigger `validate_position_setup_guardrails()` (migration 20260529110000:88-140): `_SOURCE_READ_ONLY` (101), `_DEPARTMENT_INVALID` (119-128), `_NORM_INVALID` [0,100000] (130-133), `_CODE_INVALID`. RLS: `positions_tenant` FOR ALL (migration 20260520130000:228-231).

**5. Eksik işler:** Audit yok; soft-delete yok; notif yok; parent-position hierarchy UI yok (backend destekliyor); `showsTemplateMetrics` hep false (199).
**6. Closed-loop:** 🟡 Partial.
**7. Connector bağımsız:** **YES.**
**9. Skor:** **71/100** — solid CRUD + guardrail; eksik audit/soft-delete/hierarchy.
**10. Faz:** PR17.1.

---

### 2.5 `/sirket-kurulum` — sirket-kurulum.tsx (355 satır)

**1. Ürün amacı:** Şirket kurulum durumu özeti + readiness checklist + alt-kurulum sayfalarına yönlendirme.
**2. Hedef kullanıcı:** Admin / HR admin.
**3. UI durumu:** **Sıfır mutation, read-only checklist.** Şirket alanları (ad, VKN, sektör, dil, timezone, paket) düzenlenemez; checklist (321-352) statik ikon; readiness "Open" linkleri (166-168) `/departmanlar`, `/calisanlar`'a yönlendirir. Boundary: _"erpNoWrite"_ (280-281). Demo pill (215).

**4. Backend:** Tümü SELECT — `puls_core.tenants` (company.ts:46-50), `puls_calc.setup_readiness_summary` (51-55), employee count (56-60), `erp_field_mappings` (61-69), `performance_cycles` count (70-73). `isCompanySetupEmpty()` (company.ts:36-38).

**5. Eksik işler:** Düzenlenebilir alan yok (ad/timezone/dil kilitli); readiness drill-down yok; checklist auto-update değil; remediation wizard yok.
**6. Closed-loop:** ❌ — özet/navigasyon.
**7. Connector bağımsız:** MEDIUM.
**9. Skor:** **68/100** — temiz özet + iyi navigasyon; eksik: editable alanlar, drill-down.
**10. Faz:** PR17.1 (en azından locale/timezone editable).

---

### 2.6 `/izin` — izin.tsx (911 satır) — **WORKFLOW ÇEKİRDEĞİ**

**1. Ürün amacı:** İzin talebi oluştur → yöneticiye yönlendir → onayla/reddet → bakiye güncelle → audit.
**2. Hedef kullanıcı:** Employee (talep) + Manager (onay).
**3. UI durumu:** **Tam, gerçek workflow.**

- CREATE: `createLeaveRequest()` (izin.tsx:619-632 → requests.ts:22-51 → RPC `puls_workflow.create_leave_request`). RPC auth guard (RPC.sql:194-197 `PULS_AUTH_REQUIRED`). Etkilenen tablolar: `leave_requests` INSERT, `approval_requests` INSERT, `leave_balances` pending_days UPDATE. Dönüş: `{leaveRequestId, approvalRequestId, businessDays, status:'pending', approverEmployeeId, approverName}` (requests.ts:83-108).
- APPROVE/REJECT: **Approver UI var** — `ApprovalsTab` (izin.tsx:435-536), manager persona'da görünür (`showApprovals = activePersona === 'manager'`, 193). `decideApprovalRequest()` (izin.tsx:505-529 → approvals.ts:22-57 → RPC `decide_approval_request`).
- **Rev12 belge/evidence:** `EvidenceUploadField` yalnız belge gerektiren izin tiplerinde görünür; `create_leave_request_with_evidence` finalized evidence'i aynı transaction içinde `leave_documents` kaydına bağlar. Attached evidence artık private Storage RLS üzerinden kısa TTL signed URL ile görüntülenir; OCR bu domain için G kapsam dışıdır.
- Demo pill `source === 'demo'` (215-219); readiness `buildLeaveCreationReadiness()` (604-612); submit disabled koşulları (710-719).

**4. Backend:** Şema migration 20260523160000. RPC `decide_approval_request` server guard'ları:

- Self-approval engel: `PULS_SELF_APPROVAL` (RPC.sql:634-645)
- Yetki engel: `PULS_APPROVAL_FORBIDDEN` (aynı blok)
- State persist: `approval_requests.status` UPDATE (647-652); `leave_requests.status='approved'` (672-677); `leave_balances` pending→used (688-694)
- Audit: `write_audit_log(... 'leave_requests' ...)` (723-734)
  Approver resolution server-side: manager → HR → superadmin (RPC.sql:47-106). SECURITY DEFINER, `SET search_path` (174).
  RLS: `leave_requests_select` (tenant + admin/owner/manager) ve `leave_requests_insert` (owner-only) (migration 20260523160000:655-699). **Audit trigger** `puls_workflow_leave_requests_audit_row` AFTER INSERT/UPDATE/DELETE (migration 20260609070000:142-148).

**5. Eksik full-stack işler:**

- **Notification: TAMAM (Rev5)** — approval request insert ve leave/expense decision status update event'leri aynı transaction içinde Notification Center'a düşer; existing producer orchestrator backfill/reconcile yolu olarak kalır.
- **AI context: YOK** — izin verisi ai-coach'a beslenmiyor.
- Multi-step approval şema-hazır (`approval_policy_steps`, `result.final` handle ediliyor 441-456) ama **test edilmemiş**, fiilen tek-step.
- Belge upload F1/F2/F3 ile tamamlandı; evidence viewing/indirme UI PR17.2G1 ile açıldı.
- **e2e yok** (adapter unit testleri var: requests.test.ts, overview.test.ts).

**6. Closed-loop:** 🟡 Backend + notification + evidence upload/view kapalı (create→route→approve→balance→audit→notification→evidence gerçek+persist+view), ama **AI context** ve tarayıcı e2e kenarı yok.
**7. Connector bağımsız:** MEDIUM — saf PULS tablolar; sadece leave_type kurulumu gerekiyor.
**9. Skor:** **89/100** (backend kalitesi yüksek; AI/e2e eksiği için tempolu).
**10. Faz:** PR17.2.

---

### 2.7 `/izin-tanimlari` — izin-tanimlari.tsx (1001 satır)

**1. Ürün amacı:** İzin tiplerini tanımla/düzenle/pasifleştir + onay politikası bağla (admin setup).
**2. Hedef kullanıcı:** HR admin.
**3. UI durumu:** **Tam lifecycle.**

- CREATE/UPDATE: `createLeaveType()` / `updateLeaveType()` (282-324, 299-301).
- DEACTIVATE: `deactivateLeaveType()` + reason + `window.confirm` (326-374, 497-508).
- RESTORE: `restoreLeaveType()` (351-374) — `result.status==='restored' && result.eventId` ise audit'li toast (364-366).
- Inactive tip read-only sheet (697-713, 387); lifecycle history `fetchLeaveTypeLifecycleEvents()` (965-997); demo pill (540-544).

**4. Backend:** Şema migration 20260523160000. RLS: select tenant, insert/update **admin-only** (`is_admin()`) (596-611). Audit trigger leave_types üzerinde. Hata mapping `mapLeaveTypeMutationError()` (313-323). Policy binding: `ApprovalPolicyBindingSection` + `buildPolicySelectOptions()` 'leave' modülü filtreleme (117-146, 913-937).

**5. Eksik işler:** e2e yok; multi-step policy execution test edilmemiş; belge entegrasyonu eksik; notif/AI yok.
**6. Closed-loop:** 🟡 Setup mutation (request workflow değil); kendi içinde create→audit kapalı.
**7. Connector bağımsız:** MEDIUM.
**9. Skor:** **80/100** — tam lifecycle + audit + policy binding readiness.
**10. Faz:** PR17.2 (workflow ile birlikte).

---

### 2.8 `/masraf` — masraf.tsx (944 satır) — **WORKFLOW ÇEKİRDEĞİ**

**1. Ürün amacı:** Masraf talebi oluştur → policy kontrol → onaya yönlendir → onayla/reddet → audit.
**2. Hedef kullanıcı:** Employee + Manager.
**3. UI durumu:** **Tam workflow.**

- CREATE: `createExpenseClaim()` (617-630 → claims.ts:23-61 → RPC `create_expense_claim`). Dönüş `{expenseClaimId, approvalRequestId, policyStatus, status:'pending', title}` (claims.ts:53-60).
- APPROVE/REJECT: `ApprovalsTab` (427-530), `decideApprovalRequest()` (paylaşımlı). RPC expense path (RPC.sql:762-791): `expense_claims.status` UPDATE + audit.
- **Rev20 belge/evidence:** receipt-required durumda `EvidenceUploadField` görünür; `create_expense_claim_with_evidence` finalized evidence'i aynı transaction içinde `expense_receipts` kaydına bağlar. Attached receipt/document evidence artık private Storage RLS üzerinden kısa TTL signed URL ile görüntülenir. `expense_receipt_ocr_jobs/results/events` DB contract'ı, disabled worker skeleton, worker heartbeat/recover/dead-letter proof, local `pdf_text` benchmark harness, `record_expense_receipt_ocr_review` human-review RPC/UI paneli ve service-role OCR enqueue quota gate'i var; ancak browser enqueue, real provider, canonical OCR apply ve AI context yoktur. **OCR teaser "SOON"** form içinde hâlâ production OCR sözü vermez; canlı panel yalnız mevcut OCR result varsa görünür.
- **Server-side policy:** receipt threshold (`receiptRequired` submit'i bloklar, 725) ve kategori limiti (PolicyLine 876-897). `PULS_RECEIPT_REQUIRED` server-side enforce (migration 20260609070000 + masraf.tsx selectedCategoryLimit?.receiptRequiredOver).

**4. Backend:** Şema migration 20260523160000. RLS `expense_claims_select` (tenant + admin/owner/manager) + `_insert` (owner-only) (702-733). Audit trigger expense_claims üzerinde. Approver resolution leave ile aynı RPC.

**5. Eksik işler:** **AI context YOK**; OCR sahte/provider seçilmedi; e2e yok; policy check `currency==='TRY'` kilitli (890) ama form multi-currency.
**6. Closed-loop:** 🟡 Backend + notification + evidence upload/view kapalı; OCR/AI/e2e yok.
**7. Connector bağımsız:** MEDIUM — kategori kurulumu gerekiyor.
**9. Skor:** **88/100** (backend + notification + evidence upload/view güçlü; OCR/AI/e2e tempolu).
**10. Faz:** PR17.2.

---

### 2.9 `/masraf-kategorileri` — masraf-kategorileri.tsx (1115 satır)

**1. Ürün amacı:** Masraf kategorisi tanımla + limit/receipt eşiği + cost-center routing + policy binding.
**2. Hedef kullanıcı:** HR admin.
**3. UI durumu:** **Tam lifecycle** (create/update/deactivate/restore — 254-339, leave-types deseniyle aynı). **Cost-center mappings: read-only** ("Read Only" pill 1074, disabled footer 1076, boundary `erpNoWrite` 659). Routing warnings (179-210) — eksik cost-center mapping uyarısı. Inactive read-only sheet (762-770). Demo pill (501-511).

**4. Backend:** Şema migration 20260523160000 (`expense_categories` + `cost_centers` read-only). RLS admin-only write (613-628). Audit trigger. Cost-center readiness `fetchCostCenterReadinessOverviewWithMeta()` (236-240) → export_ready_erp/external/needs_mapping/puls_only/inactive. Policy binding `ApprovalPolicyBindingSection` (996-998, 1024).

**5. Eksik işler:** Cost-center read-only (connector boundary); routing warning aksiyon alınamıyor; e2e yok; notif/AI yok.
**6. Closed-loop:** 🟡 Setup mutation; create→audit kapalı.
**7. Connector bağımsız:** MEDIUM — `erp_account_code` ve cost-center opsiyonel ama export readiness cost-center bekliyor.
**9. Skor:** **78/100.**
**10. Faz:** PR17.2.

---

### 2.10 `/sozlesmeler` — sozlesmeler.tsx (421 satır)

**1. Ürün amacı (vaat):** Sözleşme yönetimi + belge upload + hatırlatma. **Gerçek:** metadata özeti + PDF belge upload; hatırlatıcı hâlâ kapsam dışı.
**2. Hedef kullanıcı:** HR / Employee.
**3. UI durumu:** **Partial — belge upload mutation açık.**

- Admin upload sheet `EvidenceUploadField` ile PDF yükler, `attachContractFileEvidence` finalized evidence'i `contract_files` metadata'sına bağlar.
- Reminder sheet "Coming soon" + disabled save (389-392).
- Detail sheet belge sayısı ve son dosya adını gösterir; dosya içeriği private storage'da kalır.

**4. Backend:** `fetchContractsOverviewWithMeta()` → `dashboard_overview` + `puls_workflow.contracts` + `contract_files` metadata. PR17.2F1 private `workflow-evidence` bucket + `evidence_uploads` staging + `attach_contract_file_evidence` RPC ekledi; `metadata_only` dosya içeriğinin DB'de değil private storage'da olduğunu ifade eder.

**5. Eksik işler:** Reminder; e-signature; e2e. OCR/human review yalnız expense receipt kapsamıyla PR17.2G2/G3'e alınır; sözleşme OCR'ı bu kontratta hedef değildir.
**6. Closed-loop:** 🟡 Partial (document evidence upload açık; reminder/e-signature yok).
**7. Connector bağımsız:** MEDIUM.
**9. Skor:** **45/100** — belge evidence upload gerçek; reminder/e-signature/metadata CRUD hâlâ eksik.
**10. Faz:** PR17.3 (metadata CRUD + reminder veya daha dar ürün kararı).

---

### 2.11 `/performans` — performans.tsx (724 satır)

**1. Ürün amacı:** Performans döngüsü oluştur (draft) → başlat (active) → kapat (closed) + competency template.
**2. Hedef kullanıcı:** Manager.
**3. UI durumu:** **Gerçek mutation var.**

- CREATE: `createPerformanceCycle()` (cycles.ts:227-270; mutation 436-451) → `pulsPerformance().from('performance_cycles').insert({...})`.
- UPDATE status: `updatePerformanceCycle()` (cycles.ts:272-377; mutation 453-460) → "Launch" `{status:'active'}` (649). Client `canTransitionPerformanceCycleStatus()` pre-flight (cycles.ts:345-353).
- **"Close cycle" UI butonu YOK** — `active→closed` sadece API.
- Demo pill (423-424, 525-534); employee'ye "Only managers can create" (616-619).

**4. Backend:** **DB lifecycle trigger** `enforce_performance_cycle_lifecycle()` (migration 20260609100000:4-40): INSERT'te `closed` reddi (11-14); UPDATE'te yalnız `draft→active` / `active→closed` (16-22); **tek-active-per-tenant** `PULS_PERFORMANCE_ACTIVE_CYCLE_EXISTS` (25-36) + unique index `performance_cycles_one_active_per_tenant_idx` (65-67). Şema: status enum draft/active/closed, `UNIQUE(tenant_id,name)`, `CHECK(ends_at>=starts_at)`. RLS enabled (463), select tenant (479), insert/update admin-only (484-490).

**5. Eksik işler:** **Audit YOK** (cycle create/transition iz bırakmıyor); **notif YOK** (activate/close bildirimi yok); **AI context YOK**; close UI yok; adapter mutation unit testi yok (sadece validation/transition/parse); e2e yok.
**6. Closed-loop:** 🟡 Partial (manager-only) — başlat var, **kapat UI yok** → döngü yarım.
**7. Connector bağımsız:** **YES** — saf `puls_performance`.
**9. Skor:** **72/100** — server lifecycle enforcement + RLS güçlü; audit/notif/close-UI/test eksik.
**10. Faz:** PR17.3.

---

### 2.12 `/performans-parametreleri` — performans-parametreleri.tsx (232 satır)

**1. Ürün amacı (vaat):** Competency template / KPI ağırlık / score band düzenleme. **Gerçek:** display-only.
**2. Hedef kullanıcı:** HR admin (`SetupRouteGuard` + `canShowSetupHub()` 36-40).
**3. UI durumu:** **STUB.** Edit butonu **disabled, gerekçesiz** (153). `useMutation` yok, sadece `useQuery` (62-66). 3 bölüm (template list, KPI weight bar, score band pill) statik. Demo pill (85-88).

**4. Backend:** `fetchPerformanceParametersOverviewWithMeta()` (performance-parameters.ts:162-172) → 4 tablo paralel SELECT: `competency_templates`, `kpi_category_weights`, `score_bands`, `performance_cycles` (active check). RLS enabled tüm config tabloları (464,470,471), insert/update admin-only. **Write adapter yok.**

**5. Eksik işler:** Tüm mutation; audit; notif; AI; **adapter unit testi yok**; e2e yok. Disabled Edit gerekçe vermiyor.
**6. Closed-loop:** ❌ STUB (admin bile düzenleyemiyor).
**7. Connector bağımsız:** **YES.**
**9. Skor:** **15/100** — role-gated gerçek veri okuyor; sıfır mutation/test/audit; parametreler seed-only görünüyor.
**10. Faz:** PR17.3 (gerçek editor veya dürüst "seed-only" konumlama).

---

### 2.13 `/verikaynaklari` — verikaynaklari.tsx (1194 satır) — **STABİL (kabul)**

**1. Ürün amacı:** Connector (ERP/CSV/API) bağla → preview → apply (create-only / guarded-update) → rollback/recovery.
**2. Hedef kullanıcı:** Connector admin (hr_admin / superadmin).
**3. UI durumu:** **Tam connector loop, gerçek mutation'lar.** startConnectorSetup (erp.ts:7774), requestConnectorCredentialHandoff (8000+), runConnectorImportPreview, requestConnectorCreateOnlyApplyJob (9647, RPC `enqueue_connector_create_only_apply_job`), requestConnectorGuardedUpdateApplyJob (9790), recordConnectorApplyApproval (9040), rollback approval (9095+). Demo pill page-level (DemoSourcePill 1073-1075).

**4. Backend:** `puls_integration.*` (erp_connections, erp_sync_batches, import_batches/records, connector_apply_change_sets, connector_apply_object_events, connector_worker_heartbeats) + worker RPC'leri. Server validation: role check (`hr_admin`/`superadmin`), tenant check, state gate, `applyExecutionContract.safeToExecute`. Credential boundary `server_side_write_only` (erp.ts:250). Audit: her mutation `actor_employee_id` + timestamp.

**5/7. Residual gaps:** Worker mid-job revoke RPC'si yok (heartbeat timeout / manuel); rollback evidence retention edge testi yok; per-card demo badge yok (page-level pill var); credential readback blok gerekçe badge'i yok. **Uygulamanın geri kalanı connector'a bağımlı değil** (opt-in enhancement).
**9. Skor:** **82/100** — PR16.10.13-20 ile hardened; gaps minör, üretim güvenliğini bloklamaz.
**10. Faz:** Kapsam dışı (stabil); residual gaps PR17 ile fırsatçı.

---

### 2.14 `/kariyer` — kariyer.tsx (359 satır)

**1. Ürün amacı (vaat):** Kariyer basamağı + hedef rol + yetkinlik açığı + gelişim planı. **Gerçek:** read-only özet.
**2. Hedef kullanıcı:** Employee / Manager.
**3. UI durumu:** **STUB.** "Create Plan" butonu sheet açar (298-304) ama **sheet submit disabled** (329-331, status pill `common.soon` 326-328). "View Training" disabled (305-306), "AI Coach" disabled coming-soon (308-316). `useMutation` / RPC yok. Demo pill (84-88).
**4. Backend:** `fetchCareerOverviewWithMeta()` → `puls_core.employees` (JOIN dept/pozisyon, 48-56), `puls_performance.career_profiles` (current_step/target_step/readiness_score/missing_competencies, 59-62), `training_needs` COUNT (64-69). **Gelişim planı (d30/d90/d180) demo fixture'da hardcoded** (puls-demo-data.ts:1314-1376), backend'den hesaplanmıyor. Tip: `type CareerOverview = DemoCareerOverview` (overview.ts:7). RLS: `career_profiles` tenant-scoped (migration 20260523170000:162+). Mutation yok.
**5. Eksik işler:** Tüm mutation katmanı (plan oluştur/düzenle/kaydet); gelişim planı backend hesaplama; audit; notif; AI context; e2e.
**6. Closed-loop:** ❌ STUB.
**7. Connector bağımsız:** MEDIUM — core veriyle çalışır ama gelişim planı statik.
**9. Skor:** **25/100.**
**10. Faz:** PR17.3.

---

### 2.15 `/egitim` — egitim.tsx (205 satır)

**1. Ürün amacı (vaat):** Eğitim ihtiyaçları + atama + tamamlama takibi. **Gerçek:** read-only liste.
**2. Hedef kullanıcı:** Employee / Manager.
**3. UI durumu:** **STUB.** Eğitim listesi tablo/mobil kart (124-182); **edit/save/delete/complete butonu/handler'ı yok.** "School teaser" AI kutusu coming-soon (185-202, `common.soon`). Demo pill (67-71). Tip `type TrainingOverview = DemoTrainingOverview` (overview.ts:7).
**4. Backend:** `puls_performance.training_needs` SELECT (skill_topic/status/employee JOIN, 36-48), `.eq('tenant_id')`, limit 20. Mutation/RPC yok. RLS tenant-scoped (migration 20260523170000:183+).
**5. Eksik işler:** Tüm mutation (eğitim oluştur/ata/tamamla); audit; notif; AI; e2e.
**6. Closed-loop:** ❌ STUB.
**7. Connector bağımsız:** **YES** — saf `training_needs`.
**9. Skor:** **20/100.**
**10. Faz:** PR17.3.

---

### 2.16 `/is-degerleme` — is-degerleme.tsx (188 satır)

**1. Ürün amacı (vaat):** Pozisyon iş değerleme (faktör puanlama, seviye bandı). **Gerçek:** backend dahil tam stub.
**2. Hedef kullanıcı:** HR admin.
**3. UI durumu:** **STUB.** Pozisyon skorları (113-163) ve seviye bantları (174-183) read-only; handler/buton yok. Placeholder mesajı `hrGrowthPerformance.placeholder` (56-64).
**4. Backend:** **GERÇEK BACKEND YOK.** `fetchRealJobEvaluationOverview(_userId)` userId'yi yok sayıp `emptyJobEvaluationOverview()` döner (overview.ts:51-53). DB sorgusu/RPC yok; faktörler (knowledge/problem/responsibility/impact) hardcoded template (7-44). Gösterilen her şey demo fixture (puls-demo-data.ts:1485-1547).
**5. Eksik işler:** **Tüm backend** (schema, RPC, RLS) + tüm mutation + audit + notif + AI + e2e.
**6. Closed-loop:** ❌ STUB (backend bile yok).
**7. Connector bağımsız:** N/A — backend implementasyonu yok.
**9. Skor:** **15/100** — denetlenen en az olgun sayfa; gerçek backend stub.
**10. Faz:** PR17.3 (veya kapsam-dışı kararı — bkz. §6).

---

### 2.17 `/ayarlar` — ayarlar.tsx (276 satır)

**1. Ürün amacı:** Ayarlar merkezi — bildirim tercihleri, hesap, tenant, audit görünürlüğü.
**2. Hedef kullanıcı:** Tüm roller.
**3. UI durumu:** Read-only — **tüm aksiyon butonları disabled.** Sheet footer disabled `settingsSetup.sheet.actionUnavailable` = _"This area is view-only for now"_ (226-228). Section row'ları sheet açar (170-194) ama read-only. Demo pill (136-139).
**4. Backend:** Gerçek veri okur (overview.ts:488-544): `puls_calc.setup_readiness_summary`, `puls_integration.erp_connections`/`erp_field_mappings`/`source_namespaces`, `puls_audit.audit_logs` COUNT (`auditSince()` filtreli). Hepsi `.eq('tenant_id')`. Mutation yok.
**5. Eksik full-stack işler:**

- **Notification preferences UI bağlı değil:** `upsertAppNotificationPreference()` / `fetchAppNotificationPreferences()` RPC'leri `src/lib/data/app/notifications.ts:168-200`'de **var ama ayarlar.tsx çağırmıyor** — UI disabled. _(R1'i güçlendirir: yazma altyapısı hazır, sadece bağlanmamış.)_
- Persona switch audit `logPersonaSwitch()` (persona.ts:96-123) **var ama buradan tetiklenmiyor** (başka yerden).
- Audit logları görünür ama read-only (199-216).
- e2e yok.
  **6. Closed-loop:** 🟡 Partial — okur, değiştiremez.
  **7. Connector bağımsız:** MEDIUM — readiness için ERP connection state okuyor.
  **9. Skor:** **45/100** — gerçek RLS-scoped veri + audit görünürlüğü; ama notif prefs UI'a bağlanmamış, hiçbir alan editable değil.
  **10. Faz:** PR17.2 (notif prefs UI'ını mevcut RPC'ye bağla — düşük efor, döngü değeri yüksek).

---

### 2.18 `/ai-koc` — ai-koc.tsx (~112 satır) — **PR17.4 ANA YÜZEYİ**

**1. Ürün amacı:** Context-aware AI HR asistanı (açıkla / özetle / gap tespit / sonraki adım öner).
**2. Hedef kullanıcı:** Tüm roller.
**3. UI durumu:** **Dürüst teaser** (PR16.10.16 fake `toast.info`'yu kaldırdı). Composer disabled (Textarea 83, send button 93), prompt önerileri disabled (73), "soon" pill (60), `aiCoachSetup.chat.disabledHint` (91). Sabit assistant mesajı (64-66). `useMutation` yok; **mesaj hiçbir yere gönderilmiyor.** Yanlış beklenti vermiyor.
**4. Backend — kritik nüans:** **AI context altyapısı production-ready ama UI'a/LLM'e bağlı değil.** `context-readiness.ts`:

- `fetchRealAiCoachOverview()` 32 domain count okur (setup/dashboard/leave/expense/performance/contracts + core + workflow + performance + integration), `resolveTenantContext` + her sorgu `.eq('tenant_id')` (43-348).
- `AiCoachContextSnapshot` + 9 domain (`buildAiCoachContextDomains` 399-418) ready/partial/blocked deriver.
- **Runtime evidence contract** (420-503): ALLOWED [explain, summarize, detect_gap, recommend_next_step, prepare_review, source_disclosure]; **FORBIDDEN** [start_connector_job, read_credential, apply_import, write_to_source, mutate_workflow] — guardrail hazır.
- **ai-koc.tsx bu adapter'ı import etmiyor;** sıfır network çağrısı; LLM endpoint yok.
  **5. Eksik işler:** Snapshot'ı UI'a bağla; LLM/chat endpoint; mutation→context besleme (snapshot şu an pasif count telemetrisi, mutation'dan beslenmiyor); e2e. _(Test mevcut: overview.test.ts 277 satır — helper + integration.)_
  **6. Closed-loop:** ❌ — composer disabled, iş yok.
  **7. Connector bağımsız:** MEDIUM — connector runtime status opsiyonel (yoksa "partial").
  **9. Skor:** **15/100** — dürüst teaser; **ama altyapı zemini güçlü** → PR17.4 için LLM + UI wiring kaldı.
  **10. Faz:** PR17.4 (zemin hazır; R2'yi inceltir — bkz. Risk Register).

---

### 2.19 `/profil` — profil.tsx (~330 satır)

**1. Ürün amacı:** Kullanıcı profili + hesap self-service + self-HR özet + çıkış.
**2. Hedef kullanıcı:** Tüm roller (kullanıcıya açık gerçek ürün sayfası).
**3. UI durumu:** Read-only dashboard + **1 gerçek mutation: logout.** `handleLogout()` → `signOut()` (137; auth.tsx:80-82). Edit butonu disabled (`profileSetup.actions.editUnavailable` 188), Security disabled (281). Profil alanları (email/dept/pozisyon/persona), self-HR metrikleri (izin bakiyesi/bekleyen masraf/cycle) read-only display. Recent activities **hardcoded boş** (`recentActivities: []` overview.ts:202). Demo pill (154-158).
**4. Backend:** `fetchRealProfileOverview()` (overview.ts:105-208) — `puls_core.employees` (email/employment_status/persona_role/dept/pozisyon), `puls_calc.leave_overview`/`expense_overview`/`performance_overview`, `puls_workflow.expense_claims` count. Hepsi `.eq('tenant_id')`/`.eq('employee_id')`. **Yazma yok** (profil alanları update edilmiyor). Persona switch audit: `logPersonaSwitch()` → `puls_audit.audit_logs` (persona.ts:96-123) — ama bu sayfadan değil, auth context'ten tetiklenir.
**5. Eksik işler:** Profil alanı düzenleme (disabled); recent activities backend fetch (boş stub); e2e. Logout + persona audit gerçek.
**6. Closed-loop:** 🟡 Partial — logout başlatılıp bitiriliyor; profil düzenlenemiyor (kasıtlı read-only).
**7. Connector bağımsız:** **HIGH** — `puls_integration` okumuyor; saf core + calc.
**9. Skor:** **72/100** — dürüst read-only dashboard + gerçek logout + persona audit; eksik: edit path, recent activities, e2e.
**10. Faz:** PR17.1 (self-service edit path — opsiyonel) veya kabul (read-only yeterli kararı).

---

### Kapsam dışı route'lar

| Route   | Durum         | Not                                                                    |
| ------- | ------------- | ---------------------------------------------------------------------- |
| `/menu` | Navigasyon    | Sayfa değil, menü/yönlendirme yüzeyi — ürün döngüsü yok, denetim dışı. |
| `/erp`  | Eski redirect | `/verikaynaklari`'na yönlendiren legacy route; ayrı ürün yüzeyi değil. |

---

## 3. Risk Register

| ID      | Risk                                                                                                                                                                                                                                                                                                                                   | Şiddet          | Kanıt                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Etki                                                                                                                                                                                                                                                                                                                  |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **R1**  | ✅ **KAPANDI (Rev5 — PR17.2A/B/C/D).** HR workflow notification platformu + live dispatch tamam: producer + taxonomy + prefs UI + same-transaction workflow triggers bağlı.                                                                                                                                                            | **HIGH→CLOSED** | Producer `refresh_workflow_app_notifications()` + 6 olay; prefs UI bağlı; PR17.2D trigger dispatch (`approval_requests` insert, `leave_requests/expense_claims` status update) aynı dedupe key'leriyle ledger'a yazar.                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | Onay bekleyen yönetici ve karar sonucu bekleyen requester connector worker beklemeden Notification Center'da görünür.                                                                                                                                                                                                 |
| **R2**  | **AI context zemini var ama UI'a/LLM'e bağlı değil ve mutation'dan beslenmiyor.** Read-only snapshot altyapısı (9 domain + runtime evidence contract + guardrail) hazır; eksik olan: LLM wiring, UI bağlantısı, mutation→context canlı besleme.                                                                                        | **MEDIUM→HIGH** | `context-readiness.ts` 32 domain count + allowed/forbidden actions (420-503) var ama `ai-koc.tsx` import etmiyor; snapshot pasif telemetri (mutation'dan beslenmiyor)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | PR17.4 zemini mevcut (iyi haber) ama LLM + canlı besleme yapılmadan AI HR App boş kalır.                                                                                                                                                                                                                              |
| **R3**  | ✅ **KAPANDI (Rev4 — PR17.1A).** `puls_core.departments/positions/employees` + `puls_performance.performance_cycles` üzerine AFTER INSERT/UPDATE/DELETE audit trigger eklendi.                                                                                                                                                         | **MEDIUM**      | `write_core_hr_row_audit_log()` + `write_performance_row_audit_log()` → `puls_audit.audit_logs`, allow-list metadata (PII yok), SECURITY DEFINER + REVOKE authenticated/anon (migration 20260609120000:253-301)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | Org/performans değişiklikleri artık izlenebilir; compliance açığı kapandı.                                                                                                                                                                                                                                            |
| **R4**  | **STUB/partial sayfalar yanlış vaat verebilir.**                                                                                                                                                                                                                                                                                       | **MEDIUM**      | `performans-parametreleri` Edit disabled gerekçesiz; `sozlesmeler` belge upload açıldı ama reminder/e-signature hâlâ coming-soon.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Kullanıcı "burada iş yapılır" sanıyor; disabled veya yarım aksiyonlar net ürün kararı ister.                                                                                                                                                                                                                          |
| **R5**  | **Multi-step approval şema-hazır ama test edilmemiş, fiilen tek-step.**                                                                                                                                                                                                                                                                | **MEDIUM**      | `approval_policy_steps` var, `result.final` handle (izin.tsx:441-456) ama e2e yok                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Çok adımlı onay üretimde ilk kez patlayabilir.                                                                                                                                                                                                                                                                        |
| **R6**  | **Performans cycle "close" aksiyonu UI'da yok.**                                                                                                                                                                                                                                                                                       | **MEDIUM**      | `active→closed` sadece API; performans.tsx'te buton yok                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Cycle başlatılıp bitirilemiyor — döngü yarım.                                                                                                                                                                                                                                                                         |
| **R7**  | 🟡 **KISMİ (Rev7).** DB-boundary e2e + live dispatch + reconcile duplicate guard tamamlandı. Kalan: gerçek tarayıcı/UI e2e ve tenant'ta multi-step policy yoksa zorunlu multi-step kanıtı.                                                                                                                                             | **MEDIUM**      | `docs/data/17_2_b_workflow_closed_loop_smoke.sql`; `docs/data/17_2_e_workflow_e2e_reconcile_smoke.sql`; PR17.2D trigger dispatch contract; ortak dedupe key + `UNIQUE(tenant_id,dedupe_key)`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Workflow backend sözleşmesi korunuyor; gerçek tarayıcı akışı hâlâ QA/productization kuyruğu.                                                                                                                                                                                                                          |
| **R8**  | 🟡 **KISMİ (Rev20).** Belge/evidence upload storage/RPC, form akışı, finalize hardening, attached evidence viewing, expense receipt OCR DB contract, disabled worker skeleton, human review, self-review hardening, G4A quota gate, G4B queue resilience ve G4C local benchmark tamamlandı; browser enqueue/provider integration açık. | **HIGH→MEDIUM** | PR17.2F1 private bucket + staging + intent/finalize/attach RPC; PR17.2F2 `create_*_with_evidence` + izin/masraf/sözleşme UI; PR17.2F3 actual storage size metadata verification; PR17.2G1 private Storage RLS signed URL viewing; PR17.2G2A service-role OCR queue/result/event DB contract; PR17.2G2B private storage read + server SHA-256 worker skeleton; PR17.2G3 `record_expense_receipt_ocr_review` + masraf review panel; PR17.2G3A self-review block + negative actor smoke; PR17.2G4 vendor/VLM evaluation doc; PR17.2G4A tenant/global OCR posture + quota gate; PR17.2G4B worker heartbeat + recover/retry/dead-letter smoke; PR17.2G4C `pdf_text` local extraction + benchmark runner. | Gerçek HR'da masraf fişi/izin belgesi/sözleşme dokümanı artık yüklenebilir ve yetkili kullanıcı tarafından görülebilir; OCR önerisi human review kararı alabilir, queue lease/retry/dead-letter kanıtlıdır ve PDF text-layer free-route ölçülebilir, ama browser enqueue, real provider ve canonical apply kapalıdır. |
| **R9**  | **§2.8 borcu açık:** çoklu-active cycle'lı tenant index'siz kaldı.                                                                                                                                                                                                                                                                     | **LOW**         | PR16.10.20 audit SQL eklendi (docs/data/16*10_20*...\_duplicate_audit.sql) ama cleanup migration yok                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Eski kirli veri trigger'la korunuyor ama temizlenmedi.                                                                                                                                                                                                                                                                |
| **R10** | ✅ **KAPANDI (Rev4 — PR17.1C).** `update_employee_assignment` RPC (dept/pozisyon/cost-center/manager) — server-validated, audited, admin-only, ERP-source read-only korunuyor. UI'da gerçek edit formu.                                                                                                                                | **LOW**         | RPC `update_employee_assignment` (migration 20260609140000): admin guard, ERP `external_source` bloğu (70-73), cycle/aktiflik validation, audit (276-308); calisanlar.tsx gerçek form + mutation (445-452, 716-798)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Tanı + tedavi tamam (yalnız PULS-kaynaklı aktif çalışanlar).                                                                                                                                                                                                                                                          |
| **R11** | ✅ **KAPANDI (Rev5 — PR17.2D).** Workflow notification teslimatı connector worker'a bağımlı değil.                                                                                                                                                                                                                                     | **HIGH→CLOSED** | `puls_workflow_approval_requests_notification_dispatch`, `puls_workflow_leave_requests_notification_dispatch`, `puls_workflow_expense_claims_notification_dispatch`; internal workflow-only emitter browser rollerine kapalı.                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Connector hiç çalışmayan tenant'ta da izin/masraf bildirimleri workflow transaction içinde üretilir.                                                                                                                                                                                                                  |

---

## 4. Önerilen PR17 Roadmap

### PR17.0.x — Data hygiene (mini, PR17.1 öncesi)

- §2.8 çoklu-active cycle cleanup migration + mevcut audit SQL'i çalıştır (R9).

### PR17.1 — Core HR Closed Loop _(org katmanını gerçek ürün yap)_

- departmanlar/pozisyonlar: soft-delete/deactivate lifecycle + `puls_core.*` audit trigger (R3).
- calisanlar: PULS-kaynaklı çalışanlar için atama düzenleme (dept/pozisyon/cost-center/manager), RLS admin-write (R10).
- sirket-kurulum: en azından tenant locale/timezone editable.
- dashboard: dinamik queue (role/pending bazlı).
- **Full-stack her madde:** UI form + RPC/constraint + RLS + audit + adapter test.

### PR17.2 — Workflow Closed Loop _(en yüksek ROI — backend zaten hazır)_

- ✅ **17.2A-E tamamlandı:** Notification taxonomy/contract, HR workflow producer, settings notification preferences, connector-bağımsız live dispatch ve DB-boundary e2e/reconcile guard. `create_*` / `decide_approval_request` akışı artık Notification Center'a aynı transaction içinde metadata-only kayıt üretir; connector producer duplicate-safe reconcile/backfill olarak kalır.
- **Gerçek tarayıcı e2e notu:** PR17.2E eşdeğer full-stack DB-boundary smoke'u kilitledi. Ürünün görsel/UX browser e2e'si ayrı QA kuyruğudur; document upload/OCR öncesi workflow backend doğruluğunun açık riski değildir.
- ✅ **17.2F1 — Evidence Upload Backend Boundary:** `puls_workflow.evidence_uploads` staging tablosu, private storage bucket, server-generated storage path, intent/finalize RPC, metadata-only audit, direct domain metadata insert/update hardening, contract uploader metadata ve approver-readable attached evidence RLS tamamlandı.
- ✅ **17.2F2 — Evidence Upload Product Flow:** leave/expense submit-with-evidence RPC'leri, sözleşme upload UI, compact file chip, required evidence server enforcement ve dead disabled upload kontrollerinin kaldırılması tamamlandı.
- ✅ **17.2F3 — Evidence Finalization Hardening:** `finalize_workflow_evidence_upload` actual storage object size metadata kontrolüyle sertleşti; storage-size evidence RPC errors localized edildi. `sha256_client` hâlâ client-declared metadata; server hash/content sniffing/OCR claim'i yok.
- ✅ **17.2G1 — Evidence Viewing Access tamamlandı:** attached evidence için authorized read model + private Storage RLS üzerinden kısa TTL signed URL + compact view action. Yeni OCR/provider/review yok.
- ✅ **17.2G2A — OCR DB Contract tamamlandı:** yalnız expense receipts için provider-agnostic queue/result/event modeli ve service-role-only enqueue/claim/heartbeat/complete/recover RPC'leri. Üretim enqueue, worker, provider yok; canonical expense write açılmaz.
- ✅ **17.2G2B — OCR Worker Skeleton tamamlandı:** disabled-by-default worker, private storage read, server-side SHA-256, mock/disabled adapter; provider SDK/external call, Railway deploy ve production enqueue yok.
- ✅ **17.2G3 — Human Review UI tamamlandı:** belge ve öneriler masraf ekranında review panelinde görünür; accept/correct/reject/new-document kararları audit/event metadata'sına safe özetle kaydedilir; OCR sonucu otomatik canonical write yapmaz.
- ✅ **17.2G3A — OCR Review Hardening tamamlandı:** requester self-review server-side bloklandı; rollback smoke unauthorized ve requester negatif aktörleri de kapsar. G3 correction UX'i not tabanlıdır; structured corrected field entry ayrı apply/review dilimine kalır.
- **17.2G4 — Vendor Evaluation & Worker Integration:** OCR vendor seçimi maliyet, KVKK/GDPR, data residency, Türkçe belge benchmark'ı, quota ve fallback kararlarından sonra yapılır. Pahalı hyperscaler provider varsayılan yol değildir.
- ✅ **17.2G4B — OCR Queue Resilience tamamlandı:** worker claim sonrası heartbeat atar; rollback smoke stale lease recovery, retry, dead-letter ve receipt projection tutarlılığını kanıtlar.
- ✅ **17.2G4C — OCR Local Extraction Benchmark tamamlandı:** `pdf_text` worker route'u, Türkçe amount/date/currency parser, sentetik fixture contract ve network-free benchmark runner eklendi; paid provider/customer dataset yok.
- **AI context feed kancası:** Workflow mutation, notification ve evidence event'lerini AI context'e güvenli özet olarak besle; LLM/AI Coach wiring PR17.4'te ürünleşir.

### PR17.3 — Performance & Career Productization _(STUB ailesini ürünleştir)_

- performans: "close cycle" UI + cycle audit + notif (R6, R3).
- performans-parametreleri: STUB → gerçek editor veya dürüstçe "seed-only" (R4).
- sozlesmeler: gerçek metadata CRUD + reminder, ya da net "pilot dışı" konumlama (R4).
- kariyer: gelişim planı backend hesaplama + plan CRUD (şu an demo-hardcoded).
- egitim: eğitim ihtiyacı oluştur/ata/tamamla mutation'ları.
- is-degerleme: **gerçek backend yok** — schema + RPC + RLS sıfırdan, veya net kapsam-dışı kararı (§6).

### PR17.4 — AI HR App Layer

- HR mutation'larını AI context'e besle (izin trendleri, masraf anomalileri, cycle durumu) (R2).
- `/ai-koc` teaser → gerçek context-aware asistan.

---

## 5. İlk Yapılacak 5 İş

> **Rev20 not:** Notification taxonomy, producer, preferences UI, connector-bağımsız dispatch, DB-boundary e2e/reconcile guard, audit trigger'ları, Core HR edit işleri, evidence upload F1/F2/F3, evidence viewing G1, expense receipt OCR DB contract G2A, disabled worker skeleton G2B, human review G3, self-review hardening G3A, tenant OCR quota gate G4A, queue resilience G4B ve local benchmark harness G4C tamamlandı. PR17.2G artık tek parça "OCR yap" işi değildir; sıradaki paid benchmark/production integration işleri ürün-hukuk-bütçe kararlarına bağlıdır. Aşağıdaki liste artık "workflow ürünü bitti" varsaymadan kalan productization kenarlarını sıralar. Orijinal liste tarihsel referans için §5-arşiv'de.

1. **PR17.2G4D — Paid Provider Benchmark Run hazırlığı** (R8). Gerçek/sentetik benchmark veri seti KVKK onayı, bütçe/quota default'ları ve region/residency kararı bağlanmadan paid provider benchmark koşulmamalı; canonical write hâlâ ayrı apply kararı gerektirir.
2. **Gerçek browser/UX e2e** (R7). PR17.2E DB-boundary e2e'yi kapattı; ürün QA için request→Notification Center→approve→requester notification ve evidence upload/view akışı Playwright/auth persona ile ayrıca yürütülmeli.
3. **AI context'i mutation/evidence event'lerinden beslemeye başla** (R2, PR17.4 zemini). `context-readiness.ts` snapshot'ı hazır; izin/masraf/performans mutation'larını ve upload/OCR evidence özetlerini canlı besle + `ai-koc.tsx`'i adapter'a bağla.
4. **STUB ürün ailesini kapat** (PR17.3). Sözleşme reminder, performans parametreleri, kariyer, eğitim ve iş-değerleme için gerçek ürün kararı/akışı belirlenmeli.
5. **Evidence janitor/runbook kararı** (R8 ops kuyruğu). Expired/orphan storage objelerinin service-role janitor veya operasyonel runbook ile nasıl temizleneceği netleşmeli.

---

## 6. Kod Yazmadan Önce Verilmesi Gereken Ürün Kararları

> Bunlar geliştirme değil, **ürün** kararları — kodla çözülemez.

1. **Belge upload PR17 scope'unda mı?** İzin belgesi / masraf fişi gerçek HR'da çoğu zaman zorunlu. Rev20 kararı: evet; PR17.2F1/F2/F3 ile storage/RLS/RPC/audit boundary, browser form akışı ve finalize storage-size hardening açıldı; PR17.2G1 ile attached evidence viewing açıldı; PR17.2G2A ile masraf fişi OCR/extraction DB contract'ı açıldı; PR17.2G2B ile disabled worker skeleton ve server-side content hash path'i eklendi; PR17.2G3 ile human review karar yüzeyi açıldı; PR17.2G4A ile service-role OCR enqueue tenant posture/quota gate arkasına alındı; PR17.2G4B ile queue heartbeat/recover/retry/dead-letter kanıtlandı; PR17.2G4C ile local `pdf_text` benchmark harness eklendi. Malware scan veya server-verified hash claim'i browser/upload aşamasında yapılmaz; `sha256_client` client-declared metadata olarak kalır. PR17.2G'nin kalan kısmı paid benchmark ve vendor seçimi kararlarını ayrı alt fazlara böler.
2. **OCR vendor şimdi seçiliyor mu?** Hayır. PR17.2G1-G3A vendor bağımsız kalır. Öncelik structured e-invoice/e-archive payload, PDF text layer, duplicate detection ve manual fallback'tir. Ancak XML/e-invoice intake bugün açık değildir; mevcut evidence allowlist PDF/PNG/JPEG ile sınırlıdır. Duplicate/cost guard da `sha256_client`'a dayanamaz; worker server-side content hash hesaplamalıdır. Azure/Google/AWS gibi pahalı provider'lar ancak G4'te gerçek Türkçe örnek seti, aylık maliyet, tenant quota, KVKK/GDPR, data residency ve retention kararlarından sonra benchmark/fallback olarak değerlendirilir.
3. **Notification kanalı sadece in-app mi, e-posta/push de mi?** Ledger in-app hazır. Manager onay bildirimini e-postayla da almalı mı? Producer tasarımını ve PR17.2 boyutunu belirler.
4. **Multi-step approval gerçekten gerekiyor mu, yoksa tek-step (manager→HR fallback) yeter mi?** Şema multi-step destekliyor ama hiç kullanılmıyor. Pilot tek-step ise, multi-step'i e2e+UI yükünden çıkar.
5. **performans-parametreleri ve sozlesmeler: ürün mü, seed-only mı?** Parametreler onboarding'de seed ediliyorsa in-app editor'e gerek yok — dürüstçe "read-only, kurulumda tanımlanır" de. Karar verilmezse 15/100 stub kalır.
6. **calisanlar düzenlenebilir mi, yoksa ERP system-of-record mı?** "ERP no-write" bir mimari karar. Connector-bağımsız ürün hedefin varsa, PULS-kaynaklı çalışanlar **düzenlenebilir** olmalı — aksi halde connector olmadan çalışan yönetilemez.
7. **AI Coach ne zaman gerçek olur — PR17'de mi, sonra mı?** Veri zemini (R2) yoksa AI katmanı boş. PR17.2F/G'de evidence event'lerini, PR17.4'te workflow/notification/evidence özetlerini güvenli context'e beslemeden AI Coach gerçek ürün katmanına geçemez.
8. **STUB ailesi (kariyer / egitim / is-degerleme) ve teaser (ai-koc) PR17 scope'unda mı?** Hepsi denetlendi (§2.14-2.16, §2.18); en kritik karar **is-degerleme** — gerçek backend'i hiç yok (`fetchRealJobEvaluationOverview()` boş döner), yani "ürünleştir" demek schema+RPC+RLS sıfırdan demek. `/ai-koc` ise zemini hazır teaser (PR17.4). Her biri için: ürünleştir (roadmap'e faz) mi, yoksa menü görünürlüğünü kıs / "pilot dışı" işaretle mi? Karar verilmezse demo-seed stub olarak kalırlar.

---

## 7. Net Sonuç

Backend gerçeklik katmanı (RPC, RLS, audit trigger, lifecycle guard, server validation) PR16.10 ve PR17.1/17.2 turlarıyla gerçekten sağlamlaştı — bu, çoğu MVP'nin sahip olmadığı bir zemin. Kalan büyük ürün kenarı: AI context hâlâ HR mutation'larından beslenmiyor ve tarayıcı e2e kanıtı tamamlanmadı.

PR17'nin sıradaki en yüksek getirili işi yeni yüzey eklemek değil — **mevcut AI context altyapısını gerçek HR mutation'larına bağlamak** ve izin/masraf kapalı döngüsünü tarayıcı e2e ile kanıtlamak.

---

### Ek: Doğrulama komutları (bu denetimde çalıştırıldı)

```
# Notification: Rev5 sonrası connector/runtime + file-import producer'larına ek olarak
# HR workflow live dispatch trigger'ları var.
# NOT: file_import_uploaded producer'ı *notification*-isimli olmayan bir migration'da
# (puls_integration_file_import_contract), bu yüzden TÜM .sql migration'larda ara:
grep -rhniE "source_event_key" supabase/migrations/*.sql \
  | grep -oiE "'[a-z_]+'" | sort -u
# → file_import_uploaded,
#   import_apply_rollback_{approval_recorded,preview_ready,worker_ready}
#   ('all' ve 'source_event_key' regex gürültüsü)
#   Ek credential producer'ları (farklı alan adı): reference_revoked, verification_{failed,succeeded}
#   Rev5 ayrıca workflow trigger dispatch'i ekler; producer orchestrator backfill/reconcile olarak kalır.

# Audit trigger kapsamı
grep -rn "TRIGGER.*audit" supabase/migrations/20260609070000_*.sql
# → yalnız puls_workflow leave_requests / expense_claims / approval_requests

# Workflow notification live dispatch trigger'ları
grep -niE "notif|enqueue.*notif|app_notification" \
  supabase/migrations/20260610100000_puls_workflow_notification_dispatch_boundary.sql
# → approval_requests insert + leave/expense decision status update dispatch
```
