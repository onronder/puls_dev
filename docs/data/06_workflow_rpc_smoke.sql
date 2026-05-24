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
