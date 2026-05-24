-- 06a Manual SQL smoke checklist (run after supabase db push on staging)
-- Requires authenticated session with employee + tenant context.

-- 1) Happy path: create leave → pending approval visible → approve → used_days increases
-- SELECT puls_workflow.create_leave_request(
--   '<annual_leave_type_id>'::uuid,
--   CURRENT_DATE + 7,
--   CURRENT_DATE + 9,
--   false, NULL, 'smoke test'
-- );

-- 2) Rollback path: deliberately invalid approver scenario should leave zero rows
-- Count before/after in same transaction using a test that raises PULS_NO_APPROVER
-- Assert: no leave_requests / approval_requests / audit_logs persisted on failure

-- 3) decide idempotency: second decide on same approval → PULS_APPROVAL_ALREADY_DECIDED

-- 4) Cross-tenant: approval from another tenant id → PULS_APPROVAL_NOT_FOUND

-- 5) Self-approval: requester decides own approval → PULS_SELF_APPROVAL

-- 6) Expense create with limit exceed → policy_status = warning, status = pending

-- 7) requires_document leave type → PULS_DOCUMENT_REQUIRED (sick/maternity blocked until upload V2)

-- 8) Cross-year leave (Dec 30 – Jan 2) → PULS_CROSS_YEAR_LEAVE

-- 9) Balance year: create leave with start_date in next calendar year locks that year's balance row

-- 10) Hotfix: hr_admin with manager_employee_id IS NULL creates leave/expense
--     → resolve_approver picks tenant manager persona (approver != requester)

-- 11) Hotfix: approval overview for requester shows zero self-approval rows
--     (approver_employee_id = me AND requester_employee_id != me)

-- 12) Hotfix 2: after 20260524130000, workflow create RPC inserts audit_logs with puls_core.tenant_id
--     Confirm: create_leave_request / create_expense_claim succeed, audit row present, full rollback on failure

-- 13) Hotfix 3: assigned approver (yonetici@mertteknik.demo) reads parent leave/expense via RLS
--     approval_requests visible AND leave_requests/expense_claims parent detail visible
--     Onay bekleyenler tab count > 0; pending-only (decided approvals need future history policy)

-- 14) 07 org authority: assigned approver reads requester full_name via can_read_employee RLS
--     After 20260524143000, approval tab shows requester name (not em dash)
