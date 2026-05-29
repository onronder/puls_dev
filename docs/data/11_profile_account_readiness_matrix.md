# PR11.8 — Profile Account Readiness Matrix

Reference: [11_sidebar_data_api_inventory.md](./11_sidebar_data_api_inventory.md), [11_employees_foundation_matrix.md](./11_employees_foundation_matrix.md)

## Executive summary

PR11.8 hardens `/profil` as a **read-only, production-partial** auth→employee/account surface. It does not open profile editing, security settings, or notification preference writes. It adds WithMeta source honesty, explicit employee-link readiness states, and verify guards.

**Quality bar:** auth→employee truth, demo transparency, no app mutations.

**No migration in PR11.8.**

## Surface table

| Surface | Behavior | PR11.8 |
|---------|----------|--------|
| Header identity | Display name, role, tenant, status | tenant from adapter; trim-aware display name |
| Personal info | Email, department, position, tenant, persona | bind `profile.tenantName` |
| Self HR metrics | Leave, expense, performance summaries | preserve calc reads when linked |
| Recent activity | Demo fixture only on demo path | real path stays `[]`; document gap |
| Edit / security | Disabled actions | preserve |
| Logout | Existing `signOut` | preserve; only auth action |

## Auth→employee source matrix

| Source | Schema | Adapter usage | PR11.8 |
|--------|--------|---------------|--------|
| Supabase auth user | auth | session `user.id` input | preserve |
| Tenant membership | `public.user_tenants` | `resolveTenantContext` fallback | document `tenant_without_employee` |
| Lovable role | `public.user_roles` | persona when no employee row | preserve |
| Employee link | `puls_core.employees.user_id` | primary path | readiness metadata |
| Leave summary | `puls_calc.leave_overview` | when `ctx.employeeId` | preserve |
| Expense summary | `puls_calc.expense_overview` | when linked | preserve |
| Performance summary | `puls_calc.performance_overview` | when linked | preserve |
| Pending expense count | `puls_workflow.expense_claims` | when linked | preserve |

## Employee-link readiness states

| State | Condition | Demo fallback | UI |
|-------|-----------|---------------|-----|
| `linked_employee` | `employees.user_id` maps to auth user | no (real data) | success readiness |
| `tenant_without_employee` | `user_tenants` tenant, no employee row | **no** — stays real | warning readiness card |
| `no_tenant` | no tenant context | yes when demo mode on | neutral/warning copy |
| demo source | `isProfileOverviewEmpty` + demo mode | rich demo fixture | demo pill |

**Critical:** only `no_tenant` triggers `isProfileOverviewEmpty` / demo fallback. `tenant_without_employee` must not mask into demo.

## Demo fallback and WithMeta honesty

| Adapter | Real empty | Demo | PR11.8 |
|---------|------------|------|--------|
| `fetchProfileOverview` | empty when `no_tenant` only | demo fixture | `fetchProfileOverviewWithMeta` + demo pill |

## Mutation inventory

| Operation | App-exposed | PR11.8 |
|-----------|-------------|--------|
| Profile edit | no (disabled UI) | preserve |
| Security settings | no (disabled UI) | preserve |
| Logout | yes (`signOut`) | preserve existing auth action |
| Employee CRUD | no | verify forbids employee module changes |

## Follow-ups

- Profile edit, password/security settings, notification preferences
- Real recent activity feed (audit/workflow events)
- Broader demo guard (PR11.9)
- `/ayarlar` account readiness (same series owner, separate PR)

## Surface matrix (minimum)

| Surface | Source | Adapter | Demo | PR11.8 |
|---------|--------|---------|------|--------|
| Overview | core + calc reads | `fetchProfileOverviewWithMeta` | fallback | WithMeta + pill |
| Account link | `resolveTenantContext` | `buildProfileAccountLinkStatus` | linked demo metadata | explicit states |
| Activity | none (real) | `recentActivities: []` | demo fixture | documented gap |
