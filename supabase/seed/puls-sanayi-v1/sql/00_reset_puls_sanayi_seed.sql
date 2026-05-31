-- PR13.4 reset: delete Puls Sanayi baseline rows from puls_* schemas only.
-- Run before reload. Targets tenant UUID below.
-- LEGACY_PUBLIC_EXCLUSION: public.* seed-demo.sql is intentionally not used.

\set ON_ERROR_STOP on
\set tenant_id 'a0000001-0001-4001-8001-000000000001'

BEGIN;

-- Defensive FK detach before delete (departments.manager_employee_id -> employees)
UPDATE puls_core.departments
SET manager_employee_id = NULL, cost_center_id = NULL
WHERE tenant_id = :'tenant_id'::uuid;

UPDATE puls_core.employees
SET manager_employee_id = NULL, legal_entity_id = NULL, location_id = NULL, cost_center_id = NULL
WHERE tenant_id = :'tenant_id'::uuid;

DELETE FROM puls_integration.entity_identity_map WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_integration.erp_field_mappings WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_integration.import_records WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_integration.import_batches WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_integration.erp_staging_records WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_integration.erp_sync_batches WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_integration.source_namespaces WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_integration.erp_connections WHERE tenant_id = :'tenant_id'::uuid;

DELETE FROM puls_workflow.contracts WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_workflow.leave_balances WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_workflow.leave_requests WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_workflow.expense_claims WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_workflow.approval_requests WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_workflow.leave_types WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_workflow.expense_categories WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_workflow.approval_policy_steps WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_workflow.approval_policies WHERE tenant_id = :'tenant_id'::uuid;

DELETE FROM puls_performance.training_needs WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_performance.career_profiles WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_performance.performance_scores WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_performance.competency_evaluations WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_performance.performance_kpis WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_performance.competency_templates WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_performance.kpi_category_weights WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_performance.score_bands WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_performance.performance_cycles WHERE tenant_id = :'tenant_id'::uuid;

DELETE FROM puls_core.employee_reporting_lines WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_core.employee_legal_entity_assignments WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_core.employee_location_assignments WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_core.employee_cost_center_assignments WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_core.employees WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_core.positions WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_core.departments WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_core.cost_centers WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_core.locations WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_core.legal_entities WHERE tenant_id = :'tenant_id'::uuid;
DELETE FROM puls_core.tenants WHERE id = :'tenant_id'::uuid;

COMMIT;
