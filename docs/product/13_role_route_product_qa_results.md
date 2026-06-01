# PR13.11 — Role Route Product QA Results

This file records the actual role/route/function QA run. It starts as an execution log and becomes the go/no-go record before PR14 ERP/runtime work.

## Run Summary

| Field | Value |
|-------|-------|
| Status | Complete — P0/P1/P2 QA findings closed for PR13.11 scope |
| Started | 2026-06-01 |
| Environment | Remote Supabase development |
| Tenant | Puls Teknik A.S. |
| App mode | `VITE_PULS_DEMO_MODE=false` |
| Browser target | `http://localhost:3000` |

## DB QA

| Check | Status | Notes |
|-------|--------|-------|
| `11_validate_role_route_product_qa.sql` | Passed | Remote DB read-only validation passed on 2026-06-01. |

## Browser QA Passes

| Pass | Persona | Status | Notes |
|------|---------|--------|-------|
| Anonymous protected route redirect | none | Partial | Protected route redirects to login, but redirect query nesting bug found. |
| Employee route/function pass | `calisan@puls.demo` | Passed after fix | Route access correct; leave/expense create sheets no longer show false missing-manager warnings; dashboard no longer shows approval queue copy in employee mode. |
| Manager employee-mode pass | `yonetici@puls.demo` | Passed after fix | Employee-mode recheck: dashboard active employee 1, no approval queue copy, leave/expense approval tabs hidden, no manager performance action. |
| Manager manager-mode pass | `yonetici@puls.demo` | Passed | Manager routes and key surfaces checked; no open PR13.11 P2 findings remain. |
| HR admin employee-mode pass | `ik@puls.demo` | Passed after fix | Employee-mode recheck: dashboard active employee 1, no approval queue copy, leave/expense approval tabs hidden, performance scope 1 and no manager action. |
| HR admin manager-mode pass | `ik@puls.demo` | Passed | Setup/admin routes, sheets, and ERP metadata checked; department manager metadata copy clarified. |
| Admin manager-mode pass | `admin@puls.demo` | Passed | 20-route sweep completed in browser; contracts empty-state copy clarified for self-scope. |
| Incomplete setup pass | configured user | Skipped | Optional edge; not required for PR13.11 go/no-go because the four linked Puls Teknik personas passed DB and browser coverage. |

## Findings

| ID | Severity | Area | Finding | Status | Resolution |
|----|----------|------|---------|--------|------------|
| QA-001 | P1 | QA coverage | PR13.10 was route smoke, not full role/function QA. | Resolved | PR13.11 matrix, DB validation, browser execution log, and findings record added. |
| QA-002 | P1 | `/sozlesmeler` | Remote DB contains 20 seeded contracts and `contracts_overview` rows, but `admin@puls.demo` browser view shows `Sözleşme kaydı yok`. HR/admin contract metadata is expected to show seeded rows before ERP runtime starts. | Resolved | Root cause was a PostgREST cross-schema embed miss (`contracts -> employees`). Adapter now queries contracts and employee names separately. HR browser recheck shows 20 active contract rows, no demo pill. |
| QA-003 | P1 | Auth redirect | Anonymous `/dashboard` redirect reaches login, but URL contains recursively nested `redirect` parameters after sign-out/protected-route navigation. | Resolved | `buildRedirectPath` now normalizes through `resolveSafeRedirect`; unit test covers login redirect nesting. |
| QA-004 | P2 | `/dashboard` | Immediately after employee login, `/dashboard` briefly rendered `Tenant bağlantısı yok — seed-demo.sql çalıştırın`; reload later showed Puls Teknik data correctly. | Resolved | Empty cached dashboard data is shown as loading while refetching; browser recheck no longer shows seed-demo copy during the transition. |
| QA-005 | P1 | Leave/expense request creation | `calisan@puls.demo` is PS-023 and has a seeded primary reporting line to PS-021, but both leave and expense create sheets warn `Birincil yönetici atanmamış`. | Resolved | Assignment readiness now treats `employees.manager_employee_id` as enough for manager-positive readiness when manager detail rows are hidden by RLS. Browser recheck: leave and expense sheets open without the missing-manager warning. |
| QA-006 | P2 | `/sozlesmeler` | Employee self-view may legitimately have no own contract, but empty copy says tenant has no active contract metadata. | Resolved | Empty-state copy now distinguishes self-scoped employee view from tenant-wide contract metadata. |
| QA-007 | P1 | Persona mode / data scope | `yonetici@puls.demo` and `ik@puls.demo` with `Çalışan Modu` selected still show manager/admin-scoped data (`AKTİF ÇALIŞAN 16/120`, leave approval queue, performance tenant scope). | Resolved | Dashboard, leave, expense, and performance routes now filter visible employee-mode scope by active persona. Browser rechecks passed for `yonetici@puls.demo` and `ik@puls.demo`. |
| QA-008 | P2 | `/departmanlar` | HR/admin setup shows `YÖNETİCİ ATANAN 0` and `BOŞ YÖNETİCİ 12` while reporting lines are seeded and setup readiness is 100%. | Resolved | Kept department manager assignment as `departments.manager_employee_id` metadata, and clarified metric labels/hints so reporting-line approval managers are not conflated with department-manager metadata. |

## Route Result Matrix

| Route | Employee | Manager mode | HR/Admin manager mode | Function checks | Status |
|-------|----------|--------------|-----------------------|-----------------|--------|
| `/dashboard` | Passed | Passed | Passed | KPI/readiness/actions | Partial |
| `/sirket-kurulum` | Passed | Passed | Passed | setup readiness/deep link | Partial |
| `/calisanlar` | Passed | Passed | Passed | filters/detail/readiness | Partial |
| `/departmanlar` | Passed | Passed | Passed | source labels/create/edit sheet | Partial |
| `/pozisyonlar` | Passed | Passed | Passed | source labels/create/edit sheet | Partial |
| `/izin-tanimlari` | Passed | Passed | Passed | create/edit/lifecycle controls | Partial |
| `/izin` | Passed | Passed | Passed | create sheet/validation/approval queue | Partial |
| `/masraf-kategorileri` | Passed | Passed | Passed | create/edit/lifecycle/cost-center detail | Partial |
| `/masraf` | Passed | Passed | Passed | create sheet/validation/approval queue | Partial |
| `/performans` | Passed | Passed | Passed | cycle sheet/status actions | Partial |
| `/performans-parametreleri` | Passed | Passed | Passed | parameter read surface | Partial |
| `/kariyer` | Passed | Passed | Passed | partial surface/CTA sheet | Partial |
| `/egitim` | Passed | Passed | Passed | partial surface | Partial |
| `/is-degerleme` | Passed | Passed | Passed | placeholder clarity | Partial |
| `/sozlesmeler` | Passed | Passed | Passed | detail/reminder sheets | Partial |
| `/profil` | Passed | Passed | Passed | profile identity/sign-out | Partial |
| `/ayarlar` | Passed | Passed | Passed | settings visibility/sheets | Partial |
| `/erp` | Passed | Passed | Passed | mappings/no sync write | Partial |
| `/ai-koc` | Passed | Passed | Passed | context domains/guardrails/no chat | Partial |
| `/menu` | Passed | Passed | Passed | persona nav/sign-out | Partial |

## Go / No-Go

PR14 ERP/runtime work is **approved** for planning and connector-readiness work. P0/P1/P2 findings from this QA gate are closed for the PR13.11 product QA scope. PR14 connector-preflight work should keep the canonical model/provider-agnostic connector boundary explicit: Canias is the first provider, not the product abstraction.
