-- 08 Approval Policy Engine — manual SQL smoke checklist
-- Run after supabase db push through 20260524153000 on staging.

-- Pre-merge verification (from repo root):
--   git fetch origin cursor/08-approval-policy-engine-b5b2
--   ./scripts/verify-08-policy-engine-migration.sh origin/cursor/08-approval-policy-engine-b5b2
--   git show origin/cursor/08-approval-policy-engine-b5b2:supabase/migrations/20260524153000_puls_workflow_policy_engine.sql | sed -n '1290,1320p'
-- Expense intermediate approve is ~1296+ (line ~1271 is legacy-null audit log, not decide chain).

-- Prerequisites: 07 org authority applied; demo tenant Mert Teknik seeded.

-- ---------------------------------------------------------------------------
-- 1) Single-step leave regression (annual/default types unchanged)
-- As calisan@mertteknik.demo: create_leave_request with annual leave type.
-- Expect: one pending approval_requests row, step_order = 1, parent approval_policy_id set.
-- Approve as manager → parent approved, balance finalized, { final: true }.

-- SELECT lr.id, lr.approval_policy_id, lr.current_approval_step, lr.status
-- FROM puls_workflow.leave_requests lr
-- ORDER BY lr.created_at DESC LIMIT 1;

-- ---------------------------------------------------------------------------
-- 2) Two-step via dedicated smoke policy only (do NOT rewire annual/travel/meal)
-- Run the isolated seed block below once per tenant for manual testing:

/*
DO $$
DECLARE
  v_tenant_id uuid;
  v_policy_id uuid;
  v_leave_type_id uuid;
  v_expense_category_id uuid;
BEGIN
  SELECT id INTO v_tenant_id FROM puls_core.tenants WHERE legacy_public_tenant_id = '44444444-4444-4444-4444-444444444444';

  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module, description)
  VALUES (v_tenant_id, 'leave_smoke_two_step', 'Smoke — İzin İki Adım', 'leave', '08 smoke only')
  ON CONFLICT (tenant_id, code) DO UPDATE SET name = EXCLUDED.name, is_active = TRUE
  RETURNING id INTO v_policy_id;

  DELETE FROM puls_workflow.approval_policy_steps WHERE policy_id = v_policy_id;
  INSERT INTO puls_workflow.approval_policy_steps (tenant_id, policy_id, step_order, approver_type, is_required)
  VALUES
    (v_tenant_id, v_policy_id, 1, 'manager', TRUE),
    (v_tenant_id, v_policy_id, 2, 'hr_admin', TRUE);

  INSERT INTO puls_workflow.leave_types (tenant_id, code, name, default_entitlement_days, approval_policy_id)
  VALUES (v_tenant_id, 'smoke_two_step', 'Smoke Two-Step Leave', 5, v_policy_id)
  ON CONFLICT (tenant_id, code) DO UPDATE SET approval_policy_id = EXCLUDED.approval_policy_id, is_active = TRUE
  RETURNING id INTO v_leave_type_id;

  RAISE NOTICE 'smoke leave_type_id=% policy_id=%', v_leave_type_id, v_policy_id;
END $$;
*/

-- Step 1 approve → { final: false, next_approval_request_id, current_step_order: 2 }
-- Step 2 approve → { final: true }, parent approved

-- ---------------------------------------------------------------------------
-- 3) Reject step 1 / step 2 → balance released (leave)
-- pending_days restored; no further pending approval rows

-- ---------------------------------------------------------------------------
-- 4) Duplicate decide → PULS_APPROVAL_ALREADY_DECIDED

-- ---------------------------------------------------------------------------
-- 5) NULL policy fallback still works
-- Temporarily set leave_types.approval_policy_id = NULL for a test type (not annual in prod).
-- create_leave_request → approval_policy_id NULL on parent; org fallback approver.

-- ---------------------------------------------------------------------------
-- 6) Non-null missing/inactive policy → PULS_POLICY_NOT_FOUND
-- Point leave type to random UUID or deactivate policy → create fails cleanly.

-- 6b) Cross-module policy binding → PULS_POLICY_NOT_FOUND
-- Bind leave_types.approval_policy_id to an expense-module policy (or vice versa).
-- create_leave_request / create_expense_claim must fail; engine must not silently run.

-- ---------------------------------------------------------------------------
-- 7) Required step unresolved → no partial finalization
-- Policy step with unresolvable specific_employee → PULS_POLICY_STEP_UNRESOLVED at create/decide.

-- ---------------------------------------------------------------------------
-- 8) Expense two-step mirror
-- Mirror smoke policy for expense module; intermediate + final approve paths.

-- ---------------------------------------------------------------------------
-- 9) Assigned approver sees current step only (RLS unchanged)

-- ---------------------------------------------------------------------------
-- 10) Self-approve blocked → PULS_SELF_APPROVAL

-- ---------------------------------------------------------------------------
-- 11) Duplicate preflight / index creation succeeds on clean DB
-- Re-run migration on clean DB; unique indexes created without opaque failure.

-- ---------------------------------------------------------------------------
-- 12) Legacy NULL-policy pending row: approve finalizes parent (no step 2)
-- Rows created before 08 have approval_policy_id NULL on parent.
-- decide approve → { final: true }; no next approval row inserted.

-- ---------------------------------------------------------------------------
-- 13) Optional step 1 + required step 2: first row uses step_order = 2
/*
DO $$
DECLARE
  v_tenant_id uuid;
  v_policy_id uuid;
BEGIN
  SELECT id INTO v_tenant_id FROM puls_core.tenants LIMIT 1;

  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module)
  VALUES (v_tenant_id, 'leave_optional_step1_smoke', 'Smoke Optional Step 1', 'leave')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE
  RETURNING id INTO v_policy_id;

  DELETE FROM puls_workflow.approval_policy_steps WHERE policy_id = v_policy_id;
  INSERT INTO puls_workflow.approval_policy_steps (tenant_id, policy_id, step_order, approver_type, is_required)
  VALUES
    (v_tenant_id, v_policy_id, 1, 'manager', FALSE),
    (v_tenant_id, v_policy_id, 2, 'manager', TRUE);
END $$;
-- create with linked type → approval_requests.step_order = 2, current_approval_step = 2
*/

-- Live accounts: o.onder@fittechs.com, yonetici@mertteknik.demo, calisan@mertteknik.demo
