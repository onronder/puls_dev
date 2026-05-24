-- 07 Org Authority Foundation — manual SQL smoke checklist
-- Run after supabase db push through 20260524150000 on staging.

-- 1) Demo org: single-root GM; non-top employees have active primary reporting line
-- SELECT e.full_name, e.manager_employee_id,
--        (SELECT rl.manager_employee_id FROM puls_core.employee_reporting_lines rl
--         WHERE rl.employee_id = e.id AND rl.is_active AND rl.relationship_type = 'primary_manager') AS line_mgr
-- FROM puls_core.employees e
-- WHERE e.legacy_public_employee_id LIKE '44444444%'
-- ORDER BY e.full_name;

-- 2) Cache matches reporting line
-- Assert: employees.manager_employee_id = active primary_manager line for all non-GM demo employees

-- 3) Cycle insert rejected by trigger (service_role only — expect ERROR)
-- Direct INSERT with A→B→A cycle must fail

-- 3b) Backfill skips invalid rows without aborting migration (check NOTICE/WARNING)
-- After 20260524140000: look for puls_org_backfill: inserted=N skipped=M in migration logs

-- 4) Cross-tenant reporting line rejected (expect ERROR)
-- INSERT with manager from different tenant

-- 5) resolve_approver V2 uses org graph when policy step approver_type = manager
-- SELECT puls_workflow.resolve_approver(tenant_id, requester_id, 'leave', leave_type.approval_policy_id)
-- Expect: primary manager from reporting line, NOT arbitrary persona fallback

-- 6) Assigned approver reads requester name (RLS via can_read_employee)
-- As yonetici@mertteknik.demo: SELECT id, full_name FROM puls_core.employees
-- WHERE id = (SELECT requester_employee_id FROM puls_workflow.approval_requests
--             WHERE approver_employee_id = puls_core.current_employee_id() AND status = 'pending' LIMIT 1);
-- Expect: row visible with full_name

-- 7) Management chain: GM sees indirect report leave via can_read_workflow_parent
-- GM logged in → SELECT * FROM puls_workflow.leave_requests WHERE employee_id = demo_calisan_id;

-- 8) Unrelated peer manager denied
-- Another manager not in chain → no rows for unrelated employee's leave_requests

-- 9) Self-approval blocked (unchanged from 06)
-- SELECT puls_workflow.decide_approval_request(... own pending ...); → PULS_SELF_APPROVAL

-- 10) Cross-tenant denial unchanged

-- 11) Performance: EXPLAIN ANALYZE on manager-scoped employee list
-- NOTE: is_management_chain_member() may need closure table for large tenants (>500 reports)

-- 12) Extend 06 scenario 14 — approval tab requester name not '—' for assigned approver

-- Live accounts: o.onder@fittechs.com, yonetici@mertteknik.demo, calisan@mertteknik.demo
