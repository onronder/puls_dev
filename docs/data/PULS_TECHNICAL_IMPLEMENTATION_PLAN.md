# PULS Technical Implementation Plan

Tarih: 23 Mayis 2026  
Durum: Planning / Cursor-ready Architecture  
Bagli dokuman: `PULS_DATA_SOURCE_CALCULATION_OWNERSHIP_CONTRACT.md`  
Kapsam: UI stabilizasyonu sonrasinda PULS'un Supabase + Railway + TanStack veri katmanini production-grade hale getirme plani.

## 1. Hedef

Bu planin amaci PULS'u ERP/HR yerine gecen bir sistem olarak degil, ERP/HR sistemlerinin uzerine oturan AI destekli calisan-yonetici asistani ve operational intelligence katmani olarak teknik olarak kurmaktir.

Ana hedefler:

- UI ekranlarini gercek canonical PULS verisiyle beslemek.
- Ham ERP veri golu kurmadan minimum canonical fact modeli olusturmak.
- ERP / HR / Excel kaynakli verileri staging + mapping + validation ile PULS domain modeline cevirmek.
- Dashboard, izin, masraf, performans, kariyer ve sozlesme metriklerini PULS calculation layer uzerinden uretmek.
- RLS ve role/persona mantigini production seviyesine tasimak.
- AI Koc'u bu fazda backend olarak kapsam disinda tutmak; yalnizca ileride baglanabilecek context altyapisini hazirlamak.

## 2. Mevcut Teknik Durum

Repo: `/Users/onuronder/Documents/puls_dev`

Mevcut temel yapi:

- Frontend: TanStack Start, React 19, Tailwind v4, shadcn-style components.
- Auth: Supabase Auth + Lovable compatibility.
- Persona: `employee`, `manager`, `hr_admin`, `superadmin`.
- UI: dashboard, calisanlar, izin, masraf, performans, ayarlar, ERP ve setup ekranlari gelistirilmis.
- Demo data: `src/lib/demo/puls-demo-data.ts`.
- Mevcut Supabase migration:
  - `departments`
  - `positions`
  - `employees`
  - `erp_connections`
  - `erp_field_mappings`
  - `erp_sync_logs`
  - `performans_competency_templates`
  - `performans_cycles`
  - `puls_vault.conversation_messages`
  - `puls_audit.audit_logs`
- Mevcut Railway skeleton:
  - `services/erp-connector`
  - `services/llm-gateway`

Bilinen teknik borc:

- `positions` tablosunda `salary_min` / `salary_max` var; MVP hassas veri ilkesiyle celisiyor. UI'da gosterilmemeli, yeni temiz schema'da varsayilan olmamali.
- Demo adapter'lar ekranlari dolduruyor; gercek data adapter katmani henuz tam yok.
- `erp-connector` sadece health endpoint seviyesinde.
- Leave, expense, contract, performance score, career, training tablolarinin production modeli yok veya demo seviyesinde.
- Supabase RLS scope'u temel tenant izolasyonunda; self/team/all ayrimi detaylanmali.

## 3. Hedef Katmanli Mimari

```text
TanStack Frontend
  ↓ supabase-js / data adapters
Supabase Canonical DB + RLS
  ↓ views / summaries / rpc
Calculation Layer
  ↑
Railway erp-connector
  ↑
ERP / HR / Excel / Manual Sources
```

Sorumluluklar:

- Frontend: kullanici deneyimi, form preview hesaplari, optimistic olmayan read/write akislari.
- Supabase: canonical data, auth, RLS, audit, deterministic SQL metrikleri.
- Railway `erp-connector`: external source adapter, mapping, validation, sync, staging.
- Railway calculation jobs: batch refresh, OCR, heavy reconciliation, ileride AI context enrichment.
- AI Koc: bu fazda aktif tool-call/chat kapsam disi.

## 4. Namespace ve Schema Stratejisi

Yeni temiz PULS namespace/proje hedefleniyorsa onerilen schema yapisi:

| Schema | Sorumluluk |
|---|---|
| `public` | Auth uyumlu tenant/profile gibi ortak public tablolar veya Supabase gereksinimleri |
| `puls_core` | tenant, employees, departments, positions, common reference data |
| `puls_workflow` | leave, expense, contract, approval transaction tablolar |
| `puls_performance` | cycles, kpi, competency, score, career/training inputlari |
| `puls_integration` | erp connections, mappings, staging, sync logs |
| `puls_calc` | views, materialized views, summary tablolar |
| `puls_audit` | append-only audit logs |
| `puls_vault` | AI Koc V2 icin ayrilmis vault, bu fazda pasif |

Pragmatik MVP alternatifi:

- Ilk iterasyonda mevcut `public` tablolar korunabilir.
- Yeni tablolar `puls_*` prefix veya schema ile eklenebilir.
- Frontend data adapter'lar tablo lokasyonunu soyutlamali; route dosyalari tablo adina baglanmamali.

Tavsiye:

> Yeni DB'ye gecilecekse schema ayrimini simdi yap. Mevcut Lovable DB uzerinde devam edilecekse backward-compatible migration ile ilerle, ama frontend adapter'lari gelecekteki schema ayrimini saklayacak sekilde yaz.

## 5. Canonical Table Plan

### 5.1 Core

`tenants` veya `puls_core.tenants`

- `id`
- `name`
- `legal_name`
- `trade_name`
- `tax_no` optional / masked
- `industry`
- `timezone`
- `locale`
- `plan_name`
- `kvkk_active`
- `created_at`
- `updated_at`

`employees`

- `id` / `anonymous_id`
- `tenant_id`
- `user_id`
- `external_employee_id`
- `external_source`
- `employee_code`
- `email`
- `full_name`
- `job_title`
- `department_id`
- `position_id`
- `manager_employee_id`
- `persona_role`
- `employment_status`
- `hire_date`
- `termination_date`
- `source_updated_at`
- `last_synced_at`
- `created_at`
- `updated_at`

MVP'de olmamali:

- TCKN
- IBAN
- salary
- birth date
- health data
- family data

`departments`

- `id`
- `tenant_id`
- `external_department_id`
- `name`
- `code`
- `parent_id`
- `manager_employee_id`
- `cost_center_code`
- `is_active`
- `source_updated_at`

`positions`

- `id`
- `tenant_id`
- `external_position_id`
- `name`
- `code`
- `department_id`
- `level`
- `parent_position_id`
- `employment_type`
- `norm_headcount`
- `is_active`
- `source_updated_at`

Not: `salary_min` / `salary_max` yeni schema'da default olmamali. Ileride `puls_compensation` veya role-gated ayri model olarak ele alinmali.

### 5.2 Integration

`erp_connections`

- `id`
- `tenant_id`
- `provider`
- `display_name`
- `connection_method`
- `base_url`
- `firm_code`
- `credentials_ref`
- `is_active`
- `sync_direction`
- `sync_schedule`
- `last_sync_at`
- `last_status`
- `created_at`
- `updated_at`

`erp_field_mappings`

- `id`
- `tenant_id`
- `connection_id`
- `source_entity`
- `source_field`
- `target_schema`
- `target_table`
- `target_field`
- `transform_rule`
- `is_required`
- `is_sensitive`
- `is_active`
- `version`

`erp_sync_batches`

- `id`
- `tenant_id`
- `connection_id`
- `sync_type`
- `status`
- `started_at`
- `finished_at`
- `records_seen`
- `records_inserted`
- `records_updated`
- `records_skipped`
- `records_failed`
- `error_summary`

`erp_staging_records`

- `id`
- `tenant_id`
- `connection_id`
- `sync_batch_id`
- `source_entity`
- `external_id`
- `payload_hash`
- `mapped_payload`
- `validation_status`
- `validation_errors`
- `mapping_status`
- `source_updated_at`
- `expires_at`

Raw payload varsayilan tutulmamalidir. Debug flag acilirsa `raw_payload_redacted` ve TTL ile tutulabilir.

### 5.3 Leave

`leave_types`

- `id`
- `tenant_id`
- `code`
- `name`
- `category`
- `paid`
- `annual_entitlement`
- `seniority_rules`
- `carryover_max_days`
- `min_days`
- `max_days`
- `requires_document`
- `requires_delegate`
- `show_in_calendar`
- `approval_policy_id`
- `is_active`

`leave_balances`

- `id`
- `tenant_id`
- `employee_id`
- `leave_type_id`
- `year`
- `source`
- `accrued_days`
- `used_days`
- `pending_days`
- `remaining_days`
- `as_of_date`
- `source_updated_at`

`leave_requests`

- `id`
- `tenant_id`
- `employee_id`
- `leave_type_id`
- `start_date`
- `end_date`
- `business_days`
- `half_day`
- `delegate_employee_id`
- `description`
- `status`
- `submitted_at`
- `approved_at`
- `rejected_at`
- `cancelled_at`
- `current_approval_step`
- `erp_sync_status`

### 5.4 Expense

`expense_categories`

- `id`
- `tenant_id`
- `code`
- `name`
- `parent_id`
- `monthly_limit`
- `transaction_limit`
- `default_vat_rate`
- `receipt_required`
- `receipt_required_over`
- `description_required`
- `approval_policy_id`
- `erp_account_code`
- `is_active`

`expense_claims`

- `id`
- `tenant_id`
- `employee_id`
- `category_id`
- `amount`
- `currency`
- `vat_rate`
- `vat_included`
- `expense_date`
- `title`
- `description`
- `receipt_file_id`
- `ocr_status`
- `policy_status`
- `status`
- `submitted_at`
- `approved_at`
- `paid_at`
- `erp_sync_status`

### 5.5 Performance

`performance_cycles`

- `id`
- `tenant_id`
- `name`
- `status`
- `starts_at`
- `ends_at`
- `scope`
- `kpi_frequency`

`competency_templates`

- `id`
- `tenant_id`
- `name`
- `description`
- `weight`
- `scale_min`
- `scale_max`
- `sort_order`
- `is_active`

`performance_kpis`

- `id`
- `tenant_id`
- `employee_id`
- `cycle_id`
- `name`
- `category`
- `target_value`
- `actual_value`
- `unit`
- `weight`
- `source`
- `score`
- `updated_at`

`competency_evaluations`

- `id`
- `tenant_id`
- `employee_id`
- `cycle_id`
- `competency_template_id`
- `evaluator_employee_id`
- `score`
- `comment`
- `submitted_at`

`performance_scores`

- `id`
- `tenant_id`
- `employee_id`
- `cycle_id`
- `kpi_score`
- `competency_score`
- `overall_score`
- `status_band`
- `calculation_version`
- `calculated_at`

### 5.6 Career, Training, Contracts

MVP icin minimum read model yeterli:

`career_profiles`

- `id`
- `tenant_id`
- `employee_id`
- `current_step`
- `target_step`
- `readiness_score`
- `missing_competencies`
- `updated_at`

`training_needs`

- `id`
- `tenant_id`
- `employee_id`
- `source_module`
- `skill_topic`
- `need_level`
- `priority`
- `status`
- `updated_at`

`contracts`

- `id`
- `tenant_id`
- `employee_id`
- `contract_type`
- `start_date`
- `end_date`
- `status`
- `signature_status`
- `file_ref`
- `metadata_only`
- `created_at`
- `updated_at`

## 6. Calculation Layer

Calculation layer route'larin dogrudan tablo aggregate etmesini azaltmalidir.

### 6.1 SQL Views

Onerilen views:

- `puls_calc.dashboard_overview`
- `puls_calc.employee_list_overview`
- `puls_calc.leave_overview`
- `puls_calc.expense_overview`
- `puls_calc.performance_overview`
- `puls_calc.contracts_overview`
- `puls_calc.erp_readiness_overview`

### 6.2 Summary Tables

Materialized veya scheduled summary tablolar:

- `employee_summary_by_tenant`
- `leave_balance_summary_by_employee`
- `expense_monthly_summary_by_employee`
- `performance_cycle_summary`
- `setup_readiness_summary`

Kullanim kural:

- Basit count ve sum view'da.
- Pahali cross-module metrik summary table'da.
- Kullanici form preview frontend'de; submit backend final hesaplama ile.

### 6.3 Formula Versioning

Her hesaplanmis kritik metrik icin:

- `calculation_name`
- `calculation_version`
- `input_snapshot_at`
- `calculated_at`
- `source_batch_id`

Ornek:

- `performance_overall_v1 = kpi_score * 0.7 + competency_score * 0.3`
- `expense_limit_usage_v1 = approved_current_month / monthly_limit`
- `erp_readiness_v1 = required_mappings_complete * 0.5 + employee_match_pct * 0.3 + latest_successful_sync * 0.2`

## 7. RLS ve Yetki Modeli

Rol/persona kaynaklari:

- `employees.persona_role`
- fallback: Lovable `user_roles.role`
- active persona: frontend persisted mode, UI visibility icin
- backend role: RLS ve route yetkisi icin asil kaynak

RLS scope matrisi:

| Role | Scope |
|---|---|
| employee | self |
| manager | self + direct/indirect team |
| hr_admin | tenant all, sensitive excluded unless explicit permission |
| superadmin | tenant all |
| finance | expense/payment scope |
| legal_compliance | contract/compliance scope |

V1 minimum:

- `employee`: kendi profil, izin, masraf, performans readonly.
- `manager`: kendi ekibi icin onay ve performans gorunumu.
- `hr_admin`: tenant tum operasyonel HR verisi.
- `superadmin`: tenant tum admin ve setup.

Setup route access:

- UI hub: backend role admin + activePersona manager.
- Direct route: client guard + backend data RLS.
- RLS hicbir zaman active persona'ya guvenmemeli; active persona sadece UX gorunurlugu.

## 8. Frontend Data Adapter Stratejisi

Route dosyalari dogrudan `supabase.from(...)` ile karmasik sorgu kurmamalidir.

Onerilen yapi:

```text
src/lib/data/
  core/
    employees.ts
    organization.ts
  dashboard/
    overview.ts
  leave/
    overview.ts
    requests.ts
  expense/
    overview.ts
    claims.ts
  performance/
    overview.ts
    cycles.ts
  setup/
    erp.ts
    company.ts
  contracts/
    overview.ts
```

Her adapter:

- typed response dondurur,
- Supabase error'u normalize eder,
- empty state ile error state'i ayirir,
- demo fallback'i sadece feature flag ile kullanir,
- route component'e DB tablo detayi sizdirmaz.

Demo fallback kural:

```text
if real query success + rows -> real data
if real query success + empty -> EmptyState
if real query fails -> ErrorState
if demo mode enabled -> demo fallback
```

Production'da silent demo fallback olmamalidir.

## 9. Railway erp-connector Plan

`services/erp-connector` health skeleton'dan su hale getirilmelidir:

### 9.1 Endpointler

- `GET /health`
- `POST /sync/:tenantId/:connectionId/dry-run`
- `POST /sync/:tenantId/:connectionId/run`
- `GET /sync/:tenantId/:batchId/status`
- `POST /webhooks/canias`
- `POST /mappings/validate`

### 9.2 Connector Pipeline

```text
fetch source records
  -> redact forbidden fields
  -> map fields
  -> validate required fields
  -> compute payload_hash
  -> upsert staging record
  -> upsert canonical record
  -> write sync batch result
  -> write audit event
```

### 9.3 Canias Adapter MVP

Ilk okunacak entity'ler:

- employees
- departments
- positions
- manager relationships
- employment status

Opsiyonel sonraki:

- leave balances
- expense/payment status
- cost centers

Kesinlikle alinmayacak MVP alanlari:

- salary
- TCKN
- IBAN
- health/family data

### 9.4 Credentials

API key ve credentials:

- Supabase public tabloda acik tutulmaz.
- Railway environment secret veya Supabase Vault/secret reference kullanilir.
- UI sadece masked reference gosterir.

## 10. Migration ve PR Sirasi

Devasa PR acilmamali. Onerilen sira:

### PR 1: Field Ownership Matrix

Cikti:

- `docs/data/PULS_FIELD_OWNERSHIP_MATRIX.csv`
- route/field/source/calculation owner/sensitivity/write-back matrix

Kod degisimi yok veya minimum.

### PR 2: Schema Foundation

Cikti:

- schema/prefix karari
- core canonical tablolar
- integration tablolar
- audit helper functions
- sensitive column exclusion

Test:

- migration apply
- RLS smoke
- forbidden column search

### PR 3: Leave + Expense Schema

Cikti:

- leave types, balances, requests
- expense categories, claims
- approval minimal model
- seed demo data

### PR 4: Performance + Contracts + Summary

Cikti:

- performance score/kpi/evaluation tablolar
- contracts metadata
- calculation views
- setup readiness view

### PR 5: Data Adapter Layer

Cikti:

- `src/lib/data/*`
- route'larin demo adapter'dan real adapter'a gecisi
- feature flag'li demo mode

### PR 6: Dashboard + Org Real Data

Cikti:

- dashboard overview real query
- employees/departments/positions pages real data
- setup readiness real computed

### PR 7: Leave + Expense Real Workflow

Cikti:

- izin talebi create
- masraf bildirimi create
- pending approval list
- backend final validation
- audit log

### PR 8: ERP Connector MVP

Cikti:

- health + dry-run + run
- Canias adapter interface
- mapping validation
- sync batches/staging
- canonical upsert for employee/org data

### PR 9: QA Hardening

Cikti:

- e2e auth/deep link
- RLS tests
- seed consistency tests
- mobile smoke
- no salary/TCKN/IBAN checks

## 11. Test Stratejisi

### 11.1 Static Tests

- `pnpm typecheck`
- `pnpm exec eslint src`
- `pnpm check-i18n`
- `pnpm build`
- forbidden term search:
  - `salary`
  - `maas`
  - `maaş`
  - `tckn`
  - `iban`
  - `birth_date`

Not: `salary` kelimesi `privacy.ts` gibi eski utility dosyalarinda varsa ayrica degerlendirilmeli; yeni UI ve schema default'unda olmamali.

### 11.2 Database Tests

- migration apply on clean DB
- RLS employee self
- RLS manager team
- RLS hr_admin tenant
- RLS cross-tenant deny
- setup admin route data deny for non-admin

### 11.3 Integration Tests

- dry-run no canonical write
- run creates sync batch
- invalid required field -> staging validation error
- forbidden field is redacted
- duplicate external id upsert
- source updated older than canonical -> skip or conflict policy

### 11.4 UI Smoke

- login redirect
- hard refresh protected route
- employee mode setup hidden
- manager mode setup visible for admin only
- dashboard real data
- leave empty/error/loading
- expense empty/error/loading
- mobile 360/390 no horizontal overflow

## 12. Production Rollout Plan

### Stage 0: UI Freeze

- Blocker-only UI fixes.
- No broad design refactor.

### Stage 1: New DB Sandbox

- Clean Supabase project or isolated schema.
- Migrations apply.
- Seed Mert Teknik demo.

### Stage 2: Read-only Real Data

- employees/departments/positions from canonical DB.
- dashboard from views.
- no write-back.

### Stage 3: Self-HR Workflow

- leave request.
- expense claim.
- approval queues.
- audit.

### Stage 4: ERP Dry-run

- Canias dry-run.
- mapping validation.
- sync logs.
- no production write-back.

### Stage 5: Controlled Pilot

- one tenant.
- limited user group.
- monitoring.
- manual rollback.

## 13. Open Decisions

Bu kararlar implementasyondan once netlesmeli:

1. Yeni Supabase project mi, mevcut Lovable project ustune mi?
2. Canias ilk entegrasyon endpoint listesi nedir?
3. Izin bakiyesi resmi source-of-truth kim olacak?
4. Izin onayi ERP'ye write-back olacak mi?
5. Masraf onayi muhasebe/ERP'ye write-back olacak mi?
6. Employee master PULS'te manuel editlenebilecek mi, yoksa read-only mi?
7. AI Koc V1'de tamamen disabled mi kalacak?
8. Salary alanlari yeni schema'dan tamamen cikacak mi, yoksa hidden future schema'da mi kalacak?
9. Finans ve hukuk rolleri V1 RLS'e dahil edilecek mi?

## 14. Cursor Agent Ana Prompt Taslagi

Asagidaki prompt PR 1 icin kullanilabilir:

```text
PULS veri entegrasyon fazina basliyoruz. Bu PR'da kod/migration yazma; once field ownership matrix uret.

Kaynak dokumanlar:
- CodexAnalysis/data-contract/PULS_DATA_SOURCE_CALCULATION_OWNERSHIP_CONTRACT.md
- CodexAnalysis/data-contract/PULS_TECHNICAL_IMPLEMENTATION_PLAN.md
- docs/V1 Dokumanlar/Puls_Veri_Sozlugu_v1.0.xlsx
- docs/specs/06-metrik-ve-demo-data-katalogu.csv
- mevcut route dosyalari src/routes/_app/*.tsx

Hedef:
docs/data/PULS_FIELD_OWNERSHIP_MATRIX.csv olustur.

Kolonlar:
route, screen_block, ui_label, technical_field, data_class, source_of_truth,
canonical_table, external_source, calculation_owner, calculation_formula,
persistence_strategy, sensitivity_level, rls_scope, demo_fallback,
write_back_required, notes

Kurallar:
- PULS ERP/HR replacement degildir.
- PULS raw ERP data lake kurmaz.
- MVP'de salary, TCKN, IBAN, health/family data alma.
- UI metrikleri PULS calculation layer'da sahiplenilir.
- ERP resmi external master / transaction kaynagi olabilir.
- Demo fallback production davranisi olarak yazilmasin; sadece dev/demo flag.

Bu PR sadece dokuman/CSV uretmeli.
Test olarak CSV kolonlari eksiksiz mi, salary/TCKN/IBAN hassas alanlari MVP source olarak isaretlenmemis mi kontrol et.
```

## 15. Basari Kriteri

Bu implementasyon fazi basarili sayilir eger:

- Her ekranin verisi demo adapter'a bagimli olmadan canonical DB veya view'dan okunabiliyorsa.
- ERP'den gelen veri sadece gerekli canonical fact'lere indirgeniyorsa.
- Hassas bordro/ozluk verisi alinmiyorsa.
- Her computed metrik icin owner ve formula belliyse.
- RLS self/team/all scope'u test ediliyorsa.
- ERP sync hatalari kullaniciya ve admin'e anlasilir sekilde gorunuyorsa.
- AI Koc aktif degilken sahte chat/tool-call beklentisi yaratilmiyorsa.

