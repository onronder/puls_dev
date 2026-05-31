# PR13.3A — Data Dictionary Seed Alignment

Aligns [`Puls_Veri_Sozlugu_v1.0.xlsx`](../V1%20Dokümanlar/Puls_Veri_Sozlugu_v1.0.xlsx) with current Supabase/Postgres + adapter architecture and PR13.3 **Puls Sanayi A.Ş.** seed spec — bridge before PR13.4 CSV/SQL artifacts.

**Documentation-only.** No CSV/SQL, no `supabase/seed/**`, no DB writes in this PR.

Production-facing product behavior must not depend on embedded TypeScript business fixtures.

Data dictionary microservice labels are future service-boundary hints, not MVP deployment requirements.

PR13.4 seed artifacts must follow the data dictionary alignment crosswalk.

## Executive summary

| Source | Role |
|--------|------|
| **Workbook** | Business/UI field vocabulary (494 technical fields across 21 domain sheets) |
| **Migrations + adapters** | Implementation truth (`puls_*` tables, RPC, calc views) |
| **PR13.3 seed spec** | Row targets, scenarios, **Puls Sanayi A.Ş.**, 120 employees |
| Crosswalk JSON | Machine-readable domain crosswalk for PR13.4 generator — **`baselineSeedArtifacts`** (PR13.4) vs **`scenarioSeedArtifacts`** (PR13.5) |

**Not every dictionary field becomes a DB seed column.** Crosswalk uses domain-level defaults plus **representative field exceptions** (ERP `api_key`, AI `conversations[]`, computed KPI cards, workflow requests).

Embedded TypeScript (`fetchDemo*`, `puls-demo-data.ts`) is **never** a valid seed source — see PR13.2 guardrails.

## Workbook inventory

| Metric | Value |
|--------|------:|
| Workbook path | `docs/V1 Dokümanlar/Puls_Veri_Sozlugu_v1.0.xlsx` |
| Total sheets | 25 |
| Meta sheets (excluded from domain crosswalk) | Kapak, Sütun Açıklamaları, Namespace Mapping, Mikroservis Haritası |
| Domain sheets | **21** |
| Technical fields (`Teknik Alan Adı`) | **494** (currently observed) |
| Canonical demo tenant | **Puls Sanayi A.Ş.** |

### Domain sheets (plain names)

Ortak Alanlar · KPI Hedefleri · Performans · Eğitim Analizi · Kariyer Haritası · İş Değerleme · Görev Tanımı · İş Tanımı · İş Analizi · **Tatil** · **Cüzdan** · **Belge** · **Koç** · Şirket Kurulum · Departmanlar · Pozisyonlar · Çalışanlar · **İzin Tipleri** · **Masraf Kategorileri** · Performans Param · ERP Entegrasyon

Workbook sheet titles include emoji prefixes and parentheticals (e.g. `🌴 Tatil (İzin)`, `🤖 Koç (AI)`).

## Status taxonomy

| Status | Meaning | PR13.4 generator |
|--------|---------|------------------|
| `covered_by_seed` | Baseline rows in PR13.4 CSV/SQL | Generate if DB column exists |
| `derived_calc` | From `puls_calc.*` views | Seed underlying tables only |
| `scenario_generated` | PR13.5 workflow scripts | Do not baseline-seed narrative rows |
| `future_not_v1` | Out of V1 packaging scope | Skip |
| `sensitive_system` | Secrets, vault, audit | **Never seed** |
| `configuration_static` | UI/config, filters, static hub | Skip unless explicit DB home |
| `not_current_route` | No V1 route surface | Skip or document only |
| `needs_mapping_review` | Ambiguous field↔column | Human review before PR13.4 |

## Route alias table

Dictionary URLs use legacy `/kurulum/*`, `/tatil/*`, `/cuzdan/*` prefixes. Current app routes:

| Dictionary URL | Current route(s) |
|----------------|------------------|
| `/kurulum/sirket` | `/sirket-kurulum` |
| `/kurulum/departmanlar` | `/departmanlar` |
| `/kurulum/pozisyonlar` | `/pozisyonlar` |
| `/kurulum/izin-tipleri` | `/izin-tanimlari` |
| `/kurulum/masraf-kategorileri` | `/masraf-kategorileri` |
| `/kurulum/performans-parametreleri` | `/performans-parametreleri` |
| `/kurulum/erp-entegrasyon` | `/erp` |
| `/calisanlar` | `/calisanlar`, `/profil` |
| `/tatil/izin-yonetimi` | `/izin` |
| `/cuzdan/masraf` | `/masraf` |
| `/belge/sozlesmeler` | `/sozlesmeler` |
| `/koc/mesajlar` | `/ai-koc` |
| `/performans/degerlendirme` | `/performans` |
| `/okul/ihtiyac-analizi` | `/egitim` |
| `/kariyer/harita` | `/kariyer` |
| `/kpi-hedefleri` | `not_current_route` |
| `/kale/is-degerleme` | `/is-degerleme` |
| `/gorev-tanimi`, `/is-tanimi`, `/is-analizi` | `future_not_v1` / partial via `/pozisyonlar` |

## Domain alignment matrix

| Workbook sheet | Namespace | Current route/surface | Current DB/adapters | PR13.3 seed posture | Crosswalk status | Notes |
|----------------|-----------|----------------------|---------------------|---------------------|------------------|-------|
| Ortak Alanlar | cross-cutting | all routes | shared field defs | cross-domain metadata | `configuration_static` | 36 shared fields; not one CSV |
| KPI Hedefleri | kpi | none dedicated | optional `performance_kpis` | empty-ok / future | `future_not_v1` | **kpi-svc** label; `/kpi-hedefleri` not routed |
| Performans | performans | `/performans` | `performance_cycles`, `performance_scores`, `competency_evaluations`, `puls_calc.performance_overview` | baseline + scenario | `covered_by_seed` + `scenario_generated` | **performans-svc** → adapters |
| Eğitim Analizi | okul | `/egitim` | `training_needs` | 10–20 rows | `covered_by_seed` | **training-svc** → `training_needs` |
| Kariyer Haritası | kariyer | `/kariyer` | `career_profiles` | 15–30 rows | `covered_by_seed` | **career-svc** |
| İş Değerleme | kale | `/is-degerleme` | none on real path | placeholder | `future_not_v1` | job-eval-svc; teaser only |
| Görev Tanımı | gorev-tanimi | none | partial `positions` | not V1 depth | `future_not_v1` | position-svc aspirational |
| İş Tanımı | is-tanimi | `/pozisyonlar` partial | `puls_core.positions` | position seed | `needs_mapping_review` | overlaps Pozisyonlar sheet |
| İş Analizi | is-analizi | none | partial `positions` | not V1 depth | `future_not_v1` | Q&A form future |
| Tatil | tatil | `/izin` | `leave_types`, `leave_balances`, `leave_requests`, `puls_calc.leave_overview` | baseline + scenario | `covered_by_seed` + `scenario_generated` | Dictionary **Tatil**; leave-svc label |
| Cüzdan | cuzdan | `/masraf` | `expense_categories`, `expense_claims`, `puls_calc.expense_overview` | baseline + scenario | `covered_by_seed` + `scenario_generated` | Dictionary **Cüzdan**; expense-svc label |
| Belge | belge | `/sozlesmeler` | `puls_workflow.contracts`, `puls_calc.contracts_overview` | 15–30 contracts | `covered_by_seed` | Dictionary **Belge**; contract-svc label |
| Koç | koc | `/ai-koc` | static teaser; `puls_vault` future | context only PR13.6 | `sensitive_system` / `future_not_v1` | Dictionary **Koç**; **AI Coach**; **llm-gateway** |
| Şirket Kurulum | tenant | `/sirket-kurulum` | `tenants`, `legal_entities`, `locations`, `setup_readiness_summary` | full baseline | `covered_by_seed` | 3 locations, 1 legal entity |
| Departmanlar | identity | `/departmanlar` | `departments`, `organization_overview` | 12 depts mixed source | `covered_by_seed` | **identity-svc** label |
| Pozisyonlar | is-tanimi | `/pozisyonlar` | `positions`, `organization_overview` | 35–50 positions | `covered_by_seed` | **position-svc** label |
| Çalışanlar | identity | `/calisanlar`, `/profil` | `employees`, `employee_list_overview` | **120 employees** | `covered_by_seed` | **identity-svc**; Puls Sanayi roster |
| İzin Tipleri | tatil | `/izin-tanimlari` | `leave_types`, `approval_policies` | 6–10 types | `covered_by_seed` | setup domain for **Tatil** |
| Masraf Kategorileri | cuzdan | `/masraf-kategorileri` | `expense_categories`, cost-center readiness | 8–15 categories | `covered_by_seed` | setup domain for **Cüzdan** |
| Performans Param | performans | `/performans-parametreleri` | `competency_templates`, `kpi_category_weights`, `score_bands` | params populated | `covered_by_seed` | **performans-svc** setup |
| ERP Entegrasyon | erp-config | `/erp` | `erp_connections`, `erp_field_mappings` | metadata only | `covered_by_seed` | **erp-connector**; **Canias connector** PR13.7; no credentials |

## Seed coverage decisions

| Domain | Seed decision |
|--------|---------------|
| identity / **Çalışanlar** | `puls_core.employees` + assignments — 120 **Puls Sanayi A.Ş.** rows; not `fetchDemo*` |
| tenant / **Şirket Kurulum** | `tenants`, `legal_entities`, `locations`, location assignments |
| **Tatil** / **İzin Tipleri** | `leave_types`, `leave_balances` baseline; `leave_requests` → `scenario_generated` |
| **Cüzdan** / **Masraf Kategorileri** | `expense_categories` baseline; `expense_claims` → `scenario_generated` |
| performans / **Performans Param** | cycles, templates, weights, bands; scores/evals scenario |
| **Belge** | `contracts` metadata — no e-sign runtime in PR13.4 |
| erp-config / **ERP Entegrasyon** | inactive Canias connection + mappings — **metadata seed only**; **`api_key` → `sensitive_system`** |
| **Koç** | AI context sources for PR13.6 — **`conversations[]` / vault → `sensitive_system`**; no autonomous AI |
| kale / gorev / is-* | mostly **`future_not_v1`** unless represented by `/pozisyonlar` columns today |
| KPI | **`derived_calc`** / **`future_not_v1`** — computed cards not direct seed |

Current MVP stack: **Supabase/Postgres + RLS/RPC/views + src/lib/data adapters** (`future_service_boundary` labels in workbook ≠ deploy units).

## PR13.4 generator requirements

1. **Must read** [`13_data_dictionary_seed_crosswalk.json`](./13_data_dictionary_seed_crosswalk.json)
2. Honor `defaultStatus` and `exceptions[]` per domain
3. Use **`baselineSeedArtifacts`** (owner `baselineSeedArtifactOwner`, default **PR13.4**) for baseline CSV/SQL — logical package names, not final filenames
4. Use **`scenarioSeedArtifacts`** (owner `scenarioSeedArtifactOwner`, default **PR13.5**) for workflow narrative — do **not** put scenario rows in baseline packs (e.g. `performance_scores` is scenario-generated per PR13.3 manifest)
5. **Do not seed** `sensitive_system` fields (ERP secrets, AI vault/conversations)
6. **Do not infer** non-existent DB columns from dictionary fields
7. **Do not treat** dictionary microservice labels as runtime service requirements (`physicalMicroservicesInMvp: false`)
8. Map logical packages to PR13.3 [`13_seed_table_coverage_manifest.md`](./13_seed_table_coverage_manifest.md) row targets
9. Reject embedded TS fixtures as seed source
10. **Ortak Alanlar** uses `namespace: cross-cutting`, `dictionaryUrl: shared` — not a routable domain; skip special-case empty metadata

## Known gaps

| Gap | Mitigation |
|-----|------------|
| Dictionary URL ≠ current route | Route alias table + `currentRoutes` in JSON |
| Microservice labels aspirational | [`13_data_dictionary_architecture_notes.md`](./13_data_dictionary_architecture_notes.md) |
| **Koç** richer than `/ai-koc` teaser | Context seed only until PR13.6 |
| Job evaluation / job description / analysis | `future_not_v1` or partial via positions |
| Public API / SDK / CRM | Not implied by dictionary or PR13.3A |
| 494 fields vs ~40 DB seed tables | Domain status + exceptions — not 494-row JSON |

## References

- [`13_data_dictionary_seed_crosswalk.json`](./13_data_dictionary_seed_crosswalk.json)
- [`13_data_dictionary_architecture_notes.md`](./13_data_dictionary_architecture_notes.md)
- [`13_synthetic_company_seed_spec.md`](./13_synthetic_company_seed_spec.md)
- [`13_seed_table_coverage_manifest.md`](./13_seed_table_coverage_manifest.md)
- [`13_embedded_demo_retirement_plan.md`](./13_embedded_demo_retirement_plan.md)
