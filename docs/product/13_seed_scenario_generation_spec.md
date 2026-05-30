# PR13.3 — Seed Scenario Generation Specification

Workflow, performance, contract, and dashboard **scenario-generated** data for the **Puls Sanayi A.Ş.** demo tenant — applied after baseline seed (PR13.4) via PR13.5 bootstrap/scenario scripts.

**Documentation-only.** Scenarios are executed in PR13.5; this spec defines required narrative coverage for packaging proof with `VITE_PULS_DEMO_MODE=false`.

The canonical V1 demo company is DB-backed, source-aware, resettable, and large enough to exercise real product workflows.

## Executive summary

Baseline seed alone is **not enough** for V1 packaging proof. Scenario scripts must generate workflow artifacts that exercise:

- Leave and expense lifecycles across statuses
- Approval engine edge cases (**self-approval forbidden**, non-approver forbidden)
- Setup lifecycle (deactivate/restore) with PULS-owned vs imported row behavior
- Performance evaluation richness
- Contract risk variety
- Dashboard KPIs and work queues from real DB state

Prefer **app/RPC contracts** from [`../data/12_app_api_boundary_inventory.md`](../data/12_app_api_boundary_inventory.md) (17 mutations, 7 RPCs). Direct insert allowed only for bootstrap-only tables. All scenario writes must be **reset-friendly**. **No Canias writes.**

## Scenario generation method

| Rule | Detail |
|------|--------|
| Primary path | RPC: `create_leave_request`, `create_expense_claim`, `decide_approval_request`, lifecycle RPCs |
| Secondary path | Direct insert only where no RPC exists and table is bootstrap/scenario-only |
| Reset | Scenarios replayable from PR13.4 baseline + this spec |
| ERP | **No Canias runtime**; **no automatic destructive ERP writes** |
| Demo mode | Scenarios must produce `source: real` reads — **`source: demo is not packaging proof`** |
| Owner PR | **PR13.5** executes; **PR13.4** may pre-stage static rows where RPC-only is insufficient |

## Leave request lifecycle

Target: **20–40** `puls_workflow.leave_requests` with linked `puls_workflow.approval_requests`.

| Scenario | Status / behavior | Proof |
|----------|-------------------|-------|
| pending | Awaiting manager decision | `/izin` queue, dashboard work items |
| approved | Manager approved via `decide_approval_request` | Calendar + balance consumption |
| rejected | Manager rejected with reason | Rejection UX |
| delegated | `delegate_employee_id` set | Delegation display |
| half-day | Partial day / half-day flag if schema supports | **half-day** edge in list/detail |
| insufficient balance | Request exceeds remaining balance | Create blocker or warning |
| inactive leave type historical label | Request references deactivated leave type | **inactive leave type historical label** on historical rows |

## Expense claim lifecycle

Target: **20–40** `puls_workflow.expense_claims` with approval linkage.

| Scenario | Status / behavior | Proof |
|----------|-------------------|-------|
| pending | Awaiting approval | `/masraf` queue |
| approved | Approved claim | Overview totals |
| rejected | Rejected claim | Rejection reason |
| VAT included | KDV dahil line items | Tax display |
| VAT excluded | KDV hariç line items | Tax display |
| category limit warning | Amount near/over category limit | Limit warning banner |
| missing cost center blocker | Employee without cost-center assignment | Create readiness blocker |
| inactive category historical label | Claim on deactivated category | **inactive category historical label** |

## Approval decisions

| Scenario | Expected outcome |
|----------|-------------------|
| Manager approver | Assigned manager can `decide_approval_request` approve/reject |
| Non-approver forbidden | Non-assigned employee cannot decide |
| **self-approval forbidden** | Requester cannot approve own request |
| Decide fixture-aware fallback | If no pending approver in test env, document honest fixture-aware behavior per existing contract smoke |

## Setup lifecycle

| Scenario | Method | Proof |
|----------|--------|-------|
| Deactivate leave type | RPC `deactivate_leave_type` | `/izin-tanimlari` inactive state + lifecycle event |
| Restore leave type | RPC `restore_leave_type` | Reactivated type |
| Deactivate expense category | RPC `deactivate_expense_category` | `/masraf-kategorileri` inactive state |
| Restore expense category | RPC `restore_expense_category` | Reactivated category |
| PULS-owned editable | Create/update department or position | `/departmanlar`, `/pozisyonlar` CRUD |
| Imported read-only | Attempt edit on Canias-sourced row | Read-only enforcement |

## Performance scenarios

Target: **80+** combined `puls_performance.performance_scores` and `competency_evaluations`.

| Scenario | Detail |
|----------|--------|
| Draft cycle | One `performance_cycles` row in draft status |
| Active cycle | One active cycle with open evaluations |
| Manager scores | Manager-submitted scores for direct reports |
| Self / manager evaluations | Where schema supports competency_evaluations |
| Performance parameters populated | Templates, weights, bands visible on `/performans-parametreleri` |

Objects: **puls_performance.performance_cycles**, **puls_performance.performance_scores**.

## Contract scenarios

Target: **15–30** `puls_workflow.contracts` with risk variety.

| Scenario | Detail |
|----------|--------|
| Signed | Executed contract |
| Pending signature | Awaiting signature |
| Expiring soon | End date within warning window |
| Low / medium / high **contract risk** | Risk tier examples for contract risk explainer (PR13.6) |

Proof route: `/sozlesmeler` via `puls_calc.contracts_overview`.

## Dashboard scenarios

| Requirement | Detail |
|-------------|--------|
| Non-zero KPIs | Employee counts, pending approvals, leave/expense totals from calc views |
| Work queue items | Pending leave/expense approvals visible |
| ERP readiness visible | Inactive **Canias** connection + mapping completeness on dashboard/ERP surfaces |
| No fake activity | Recent activity only if backed by DB rows (requests, claims, lifecycle events) |

Proof: `puls_calc.dashboard_overview` with **`VITE_PULS_DEMO_MODE=false`**.

## Profile / account scenarios

| Scenario | Detail |
|----------|--------|
| Linked employee | Auth persona with full employee row — `/profil` shows leave/expense/performance summaries |
| Tenant without employee | Auth user in tenant but no employee link — honest empty/partial UX |
| No-tenant | Handled honestly if included in smoke scope |

## Acceptance criteria

1. **`VITE_PULS_DEMO_MODE=false`** (or unset)
2. Route smoke passes for `/dashboard`, `/izin`, `/masraf`, `/sozlesmeler`, `/performans`, `/sirket-kurulum`
3. No embedded demo fallback on scenario-covered surfaces
4. Scenario data **resettable** via PR13.5 bootstrap
5. Workflow objects populated: **puls_workflow.leave_requests**, **puls_workflow.expense_claims**, **puls_workflow.approval_requests**

## PR13.4–13.5 handoff

| PR | Role |
|----|------|
| **PR13.4** | Baseline seed artifacts; optional static contract/performance rows if RPC-only insufficient |
| **PR13.5** | Scenario script runner, reset, route smoke, packaging signoff |

## References

- [`13_synthetic_company_seed_spec.md`](./13_synthetic_company_seed_spec.md)
- [`13_seed_table_coverage_manifest.md`](./13_seed_table_coverage_manifest.md)
- [`../data/12_app_api_boundary_inventory.md`](../data/12_app_api_boundary_inventory.md)
- [`13_packaging_proof_demo_guardrails.md`](./13_packaging_proof_demo_guardrails.md)
