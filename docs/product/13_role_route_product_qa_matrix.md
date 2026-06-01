# PR13.11 — Role Route Product QA Matrix

This document defines the QA gate that must pass before PR14 ERP/runtime work starts. PR13.10 proved a demo-off route smoke. PR13.11 expands that into role, route, data, and function coverage for the Puls Teknik A.S. test tenant.

## QA Goal

The goal is to make the current product usable and trustworthy with DB-backed demo data before ERP integration is added. ERP integration should connect into a product surface whose route access, tenant scoping, seeded data, empty states, and action boundaries are already understood.

PR13.11 is not a replacement for customer UAT. It is an internal product QA gate for the development environment.

## Test Context

| Field | Value |
|-------|-------|
| Environment | Remote Supabase development |
| Tenant | Puls Teknik A.S. |
| Tenant UUID | `a0000001-0001-4001-8001-000000000001` |
| App mode | `VITE_PULS_DEMO_MODE=false` |
| Browser target | `http://localhost:3000` |
| Data baseline | PR13.4 baseline + PR13.5 scenarios + PR13.9 remote posture |
| Auth baseline | Remote `05_link_auth_personas_template.sql` and `06_jwt_mutation_proof_smoke.sql` passed |

## Personas

Passwords are entered manually by the project owner. QA artifacts must not record passwords, tokens, or auth UUIDs.

| Persona | Email | Expected app role | Mode coverage |
|---------|-------|-------------------|---------------|
| Anonymous | none | unauthenticated | protected route redirect |
| Employee | `calisan@puls.demo` | employee | employee self-service |
| Manager | `yonetici@puls.demo` | manager | employee mode + manager mode |
| HR admin | `ik@puls.demo` | hr_admin | employee mode + manager mode |
| Admin | `admin@puls.demo` | superadmin or hr_admin | employee mode + manager mode |
| Incomplete setup | configured test user if present | no linked employee | tenant/no-employee edge |

## Access Matrix

| Route | Anonymous | Employee mode | Manager mode | HR/Admin manager mode | Expected result |
|-------|-----------|---------------|--------------|-----------------------|-----------------|
| `/dashboard` | redirect login | allow | allow | allow | Tenant KPIs, no demo pill |
| `/sirket-kurulum` | redirect login | redirect `/ayarlar` | redirect `/ayarlar` unless setup admin | allow | Setup readiness, direct URL works |
| `/calisanlar` | redirect login | manager-only message | allow | allow | Employee directory, no demo pill |
| `/departmanlar` | redirect login | redirect `/ayarlar` | redirect `/ayarlar` unless setup admin | allow | Departments and source labels |
| `/pozisyonlar` | redirect login | redirect `/ayarlar` | redirect `/ayarlar` unless setup admin | allow | Positions and source labels |
| `/izin-tanimlari` | redirect login | redirect `/ayarlar` | redirect `/ayarlar` unless setup admin | allow | Leave types and lifecycle controls |
| `/izin` | redirect login | allow | allow | allow | Self-service + approval queue visibility |
| `/masraf-kategorileri` | redirect login | redirect `/ayarlar` | redirect `/ayarlar` unless setup admin | allow | Categories and cost-center readiness |
| `/masraf` | redirect login | allow | allow | allow | Self-service + approval queue visibility |
| `/performans` | redirect login | allow read path | manager controls | manager controls | Performance overview and cycle controls |
| `/performans-parametreleri` | redirect login | redirect `/ayarlar` | redirect `/ayarlar` unless setup admin | allow | Parameter setup read/edit surface |
| `/kariyer` | redirect login | allow partial | allow partial | allow partial | Representative career surface |
| `/egitim` | redirect login | allow partial | allow partial | allow partial | Representative training surface |
| `/is-degerleme` | redirect login | allow placeholder | allow placeholder | allow placeholder | Explicit future placeholder |
| `/sozlesmeler` | redirect login | allow metadata | allow metadata | allow metadata | Contract metadata surface; HR/admin should see seeded contract rows |
| `/profil` | redirect login | allow linked profile | allow linked profile | allow linked profile | Correct email/tenant/persona |
| `/ayarlar` | redirect login | personal settings | personal or admin settings by mode | admin settings | Settings visibility by role/mode |
| `/erp` | redirect login | redirect `/ayarlar` | redirect `/ayarlar` unless setup admin | allow | Metadata only; no sync/write |
| `/ai-koc` | redirect login | allow teaser/context | allow teaser/context | allow teaser/context | DB context, guardrails, no chat |
| `/menu` | redirect login | employee nav | manager nav | admin nav | Navigation matches persona |

## Function checks

## Functional QA Checklist

| Area | Required checks |
|------|-----------------|
| Auth | Protected routes redirect anonymous users; sign-out returns to login; linked personas show correct email, tenant, and persona label. |
| Tenant scoping | Every real route shows Puls Teknik context; no Mert Teknik data appears on the Puls Teknik smoke path. |
| Demo fallback | No visible demo source pill with `VITE_PULS_DEMO_MODE=false`; no route silently falls to embedded fixture data. |
| Setup access | Setup routes are inaccessible to employee mode and accessible to setup admins in manager mode; direct deep links work. |
| Navigation | Sidebar/bottom/menu items match active persona; hidden routes stay blocked even if URL is typed. |
| Read models | Counts and labels match PR13.9 remote proof: 120 employees, 12 departments, 36 positions, 8 leave types, 10 expense categories, 30 leave requests, 30 expense claims, 45 scores, 45 evaluations, 20 contracts. |
| Source labels | Canias/imported rows are visible where expected and treated as read-only/source-aware. |
| Workflow forms | Leave and expense create sheets open, validate required fields, and do not show demo data. Approval buttons are only actionable for approver personas. |
| Setup forms | Department, position, leave type, expense category, and performance setup sheets open; validation is shown for invalid input; destructive lifecycle actions require explicit action. |
| ERP | Shows Canias metadata readiness, field mappings, inactive connection posture; no sync/write is enabled. |
| AI Coach | Shows context readiness and guardrails; no live chat input, no autonomous action language. |
| Placeholder/partial routes | Career, training, settings, ERP, AI Coach, and job evaluation clearly communicate accepted limitations without looking broken. |
| Errors | No uncaught UI error, blank page, login loop, cross-tenant leak, or console-visible fatal failure during route passes. |

## QA Execution Order

1. Run read-only DB QA SQL `11_validate_role_route_product_qa.sql`.
2. Run static verify `verify-13-role-route-product-qa.sh`.
3. Browser pass: anonymous route redirects.
4. Browser pass: employee persona.
5. Browser pass: manager persona in employee mode and manager mode.
6. Browser pass: HR/admin persona in employee mode and manager mode.
7. Optional browser pass: incomplete setup persona if user exists.
8. Record all findings in `13_role_route_product_qa_results.md`.
9. Fix P0/P1 blockers before PR14 starts.

## Severity Model

| Severity | Meaning | PR14 gate |
|----------|---------|-----------|
| P0 | Data leak, auth bypass, destructive wrong action, route crash, or login loop | Must fix |
| P1 | Core route/function does not work for expected persona | Must fix or explicitly descope |
| P2 | Misleading copy, incomplete empty state, non-core action gap | Track; fix when low risk |
| P3 | Polish or future-product depth | Backlog |

## Completion Rule

PR13.11 is complete only when the QA results document says whether PR14 can start, with all P0/P1 findings resolved or explicitly moved out of V1 demo scope by product decision.
