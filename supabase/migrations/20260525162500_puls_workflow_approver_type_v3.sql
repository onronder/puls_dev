-- 09 PR5 — approver_type enum extension (enum-only split; no functions or enum-typed DML)
-- New values first used in 20260525163000_puls_workflow_resolver_v3.sql

ALTER TYPE puls_workflow.approver_type ADD VALUE IF NOT EXISTS 'finance_pool';
ALTER TYPE puls_workflow.approver_type ADD VALUE IF NOT EXISTS 'hr_pool';
ALTER TYPE puls_workflow.approver_type ADD VALUE IF NOT EXISTS 'legal_pool';
ALTER TYPE puls_workflow.approver_type ADD VALUE IF NOT EXISTS 'cost_center_owner';
