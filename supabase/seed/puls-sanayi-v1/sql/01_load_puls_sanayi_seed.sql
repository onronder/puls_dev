-- PR13.4 load: psql-local baseline loader (uses \copy meta-commands).
-- Run from pack root: supabase/seed/puls-sanayi-v1/
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/01_load_puls_sanayi_seed.sql
-- Supabase SQL Editor cannot read local CSV paths — use local psql or PR13.5 inline loader.
-- LEGACY_PUBLIC_EXCLUSION: public.* seed-demo.sql is intentionally not used.

\set ON_ERROR_STOP on

BEGIN;

-- Phase 1: tenant
CREATE TEMP TABLE st_tenant (LIKE puls_core.tenants INCLUDING DEFAULTS);
\copy st_tenant (id,name,legal_name,trade_name,tax_no,industry,timezone,locale,plan_name,kvkk_active) FROM 'csv/01_tenant.csv' CSV HEADER
INSERT INTO puls_core.tenants (id,name,legal_name,trade_name,tax_no,industry,timezone,locale,plan_name,kvkk_active)
SELECT id,name,legal_name,trade_name,tax_no,industry,timezone,locale,plan_name,kvkk_active::boolean FROM st_tenant
ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name, legal_name=EXCLUDED.legal_name, trade_name=EXCLUDED.trade_name;

-- Phase 2: erp_connections (credentials_ref omitted — remains NULL)
CREATE TEMP TABLE st_erp_conn (
  id uuid, tenant_id uuid, provider text, display_name text, connection_method text,
  base_url text, firm_code text, is_active text, sync_direction text, sync_schedule text
);
\copy st_erp_conn FROM 'csv/16_erp_connections.csv' CSV HEADER
INSERT INTO puls_integration.erp_connections (id,tenant_id,provider,display_name,connection_method,base_url,firm_code,is_active,sync_direction,sync_schedule)
SELECT id,tenant_id,provider::puls_integration.erp_provider,display_name,connection_method::puls_integration.connection_method,
  NULLIF(base_url,''),NULLIF(firm_code,''),is_active::boolean,sync_direction::puls_integration.sync_direction,NULLIF(sync_schedule,'')
FROM st_erp_conn ON CONFLICT (id) DO NOTHING;

-- Phase 3: source_namespaces
CREATE TEMP TABLE st_ns (LIKE puls_integration.source_namespaces INCLUDING DEFAULTS);
\copy st_ns (id,tenant_id,code,name,source_type,priority_rank,connection_id,is_active) FROM 'csv/18_source_namespaces.csv' CSV HEADER
INSERT INTO puls_integration.source_namespaces (id,tenant_id,code,name,source_type,priority_rank,connection_id,is_active)
SELECT id,tenant_id,code,name,source_type::puls_integration.source_type,priority_rank::int,connection_id,is_active::boolean FROM st_ns
ON CONFLICT (id) DO NOTHING;

-- Phase 4–5: legal_entities, locations
CREATE TEMP TABLE st_le (LIKE puls_core.legal_entities INCLUDING DEFAULTS);
\copy st_le (id,tenant_id,code,name,is_active) FROM 'csv/02_legal_entities.csv' CSV HEADER
INSERT INTO puls_core.legal_entities (id,tenant_id,code,name,is_active)
SELECT id,tenant_id,code,name,is_active::boolean FROM st_le ON CONFLICT (id) DO NOTHING;

CREATE TEMP TABLE st_loc (LIKE puls_core.locations INCLUDING DEFAULTS);
\copy st_loc (id,tenant_id,legal_entity_id,code,name,is_active) FROM 'csv/03_locations.csv' CSV HEADER
INSERT INTO puls_core.locations (id,tenant_id,legal_entity_id,code,name,is_active)
SELECT id,tenant_id,legal_entity_id,code,name,is_active::boolean FROM st_loc ON CONFLICT (id) DO NOTHING;

-- Phase 6: cost_centers
CREATE TEMP TABLE st_cc (LIKE puls_core.cost_centers INCLUDING DEFAULTS);
\copy st_cc (id,tenant_id,legal_entity_id,parent_cost_center_id,code,name,source_namespace_id,external_id,is_active) FROM 'csv/10_cost_centers.csv' CSV HEADER
INSERT INTO puls_core.cost_centers (id,tenant_id,legal_entity_id,parent_cost_center_id,code,name,source_namespace_id,external_id,is_active)
SELECT id,tenant_id,legal_entity_id,parent_cost_center_id,code,name,source_namespace_id,NULLIF(external_id,''),is_active::boolean
FROM st_cc ON CONFLICT (id) DO NOTHING;

-- Phase 7: departments (defer manager/cost_center FKs)
CREATE TEMP TABLE st_dept (
  id uuid, tenant_id uuid, code text, name text, parent_id text, manager_employee_id text,
  cost_center_id text, external_source text, external_department_id text, is_active text
);
\copy st_dept FROM 'csv/04_departments.csv' CSV HEADER
INSERT INTO puls_core.departments (id,tenant_id,code,name,parent_id,external_source,external_department_id,is_active)
SELECT id,tenant_id,code,name,NULLIF(parent_id,'')::uuid,NULLIF(external_source,''),NULLIF(external_department_id,''),is_active::boolean
FROM st_dept ON CONFLICT (id) DO NOTHING;

-- Phase 8–9: positions, employees
CREATE TEMP TABLE st_pos (LIKE puls_core.positions INCLUDING DEFAULTS);
\copy st_pos (id,tenant_id,code,name,department_id,level,parent_position_id,employment_type,norm_headcount,external_source,external_position_id,is_active) FROM 'csv/05_positions.csv' CSV HEADER
INSERT INTO puls_core.positions (id,tenant_id,code,name,department_id,level,parent_position_id,employment_type,norm_headcount,external_source,external_position_id,is_active)
SELECT id,tenant_id,code,name,department_id,level::int,parent_position_id,employment_type,norm_headcount::int,
  NULLIF(external_source,''),NULLIF(external_position_id,''),is_active::boolean
FROM st_pos ON CONFLICT (id) DO NOTHING;

CREATE TEMP TABLE st_emp (LIKE puls_core.employees INCLUDING DEFAULTS);
\copy st_emp (id,tenant_id,employee_code,email,full_name,job_title,department_id,position_id,persona_role,employment_status,hire_date,external_source,external_employee_id) FROM 'csv/06_employees.csv' CSV HEADER
INSERT INTO puls_core.employees (id,tenant_id,employee_code,email,full_name,job_title,department_id,position_id,persona_role,employment_status,hire_date,external_source,external_employee_id)
SELECT id,tenant_id,employee_code,email,full_name,job_title,department_id,position_id,persona_role::puls_core.persona_role,
  employment_status::puls_core.employment_status,hire_date::date,NULLIF(external_source,''),NULLIF(external_employee_id,'')
FROM st_emp ON CONFLICT (id) DO NOTHING;

-- Phase 10–13: assignments + reporting
CREATE TEMP TABLE st_rl (LIKE puls_core.employee_reporting_lines INCLUDING DEFAULTS);
\copy st_rl (id,tenant_id,employee_id,manager_employee_id,relationship_type,starts_on,is_active,source) FROM 'csv/07_employee_reporting_lines.csv' CSV HEADER
INSERT INTO puls_core.employee_reporting_lines (id,tenant_id,employee_id,manager_employee_id,relationship_type,starts_on,is_active,source)
SELECT id,tenant_id,employee_id,manager_employee_id,relationship_type::puls_core.reporting_relationship_type,starts_on::date,is_active::boolean,source FROM st_rl ON CONFLICT (id) DO NOTHING;

CREATE TEMP TABLE st_ela (LIKE puls_core.employee_legal_entity_assignments INCLUDING DEFAULTS);
\copy st_ela (id,tenant_id,employee_id,legal_entity_id,starts_on,is_active,source) FROM 'csv/08_employee_legal_entity_assignments.csv' CSV HEADER
INSERT INTO puls_core.employee_legal_entity_assignments (id,tenant_id,employee_id,legal_entity_id,starts_on,is_active,source)
SELECT id,tenant_id,employee_id,legal_entity_id,starts_on::date,is_active::boolean,source FROM st_ela ON CONFLICT (id) DO NOTHING;

CREATE TEMP TABLE st_loca (LIKE puls_core.employee_location_assignments INCLUDING DEFAULTS);
\copy st_loca (id,tenant_id,employee_id,location_id,starts_on,is_active,source) FROM 'csv/09_employee_location_assignments.csv' CSV HEADER
INSERT INTO puls_core.employee_location_assignments (id,tenant_id,employee_id,location_id,starts_on,is_active,source)
SELECT id,tenant_id,employee_id,location_id,starts_on::date,is_active::boolean,source FROM st_loca ON CONFLICT (id) DO NOTHING;

CREATE TEMP TABLE st_cca (LIKE puls_core.employee_cost_center_assignments INCLUDING DEFAULTS);
\copy st_cca (id,tenant_id,employee_id,cost_center_id,starts_on,is_active,source) FROM 'csv/11_employee_cost_center_assignments.csv' CSV HEADER
INSERT INTO puls_core.employee_cost_center_assignments (id,tenant_id,employee_id,cost_center_id,starts_on,is_active,source)
SELECT id,tenant_id,employee_id,cost_center_id,starts_on::date,is_active::boolean,source FROM st_cca ON CONFLICT (id) DO NOTHING;

-- Phase 14: post-load department updates
-- Imported departments are read-only outside import apply; this bootstrap loader
-- only enables the import-apply flag for the FK backfill phase inside this transaction.
SELECT set_config('puls.import_apply.active', 'true', true);
UPDATE puls_core.departments d SET
  manager_employee_id = NULLIF(s.manager_employee_id,'')::uuid,
  cost_center_id = NULLIF(s.cost_center_id,'')::uuid
FROM st_dept s WHERE d.id = s.id;
SELECT set_config('puls.import_apply.active', 'false', true);

-- Phase 15: approval policies + steps
CREATE TEMP TABLE st_apol (
  record_type text, target_table text, id uuid, tenant_id uuid, code text, name text, module text,
  description text, is_active text, step_order text, approver_type text, policy_id text,
  specific_employee_id text, is_required text
);
\copy st_apol FROM 'csv/13_approval_policies.csv' CSV HEADER
INSERT INTO puls_workflow.approval_policies (id,tenant_id,code,name,module,description,is_active)
SELECT id,tenant_id,code,name,module::puls_workflow.approval_module,description,is_active::boolean
FROM st_apol WHERE target_table = 'approval_policies' ON CONFLICT (id) DO NOTHING;
INSERT INTO puls_workflow.approval_policy_steps (id,tenant_id,policy_id,step_order,approver_type,specific_employee_id,is_required)
SELECT id,tenant_id,policy_id::uuid,step_order::int,approver_type::puls_workflow.approver_type,NULLIF(specific_employee_id,'')::uuid,is_required::boolean
FROM st_apol WHERE target_table = 'approval_policy_steps' ON CONFLICT (id) DO NOTHING;

-- Phase 16–18: leave types, balances, expense categories
CREATE TEMP TABLE st_lt (
  id uuid, tenant_id uuid, code text, name text, is_paid text, default_entitlement_days text,
  requires_document text, requires_approval text, show_in_calendar text, carry_over_allowed text,
  max_carry_over_days text, approval_policy_id uuid, is_active text
);
\copy st_lt (id,tenant_id,code,name,is_paid,default_entitlement_days,requires_document,requires_approval,show_in_calendar,carry_over_allowed,max_carry_over_days,approval_policy_id,is_active) FROM 'csv/12_leave_types.csv' CSV HEADER
INSERT INTO puls_workflow.leave_types (id,tenant_id,code,name,is_paid,default_entitlement_days,requires_document,requires_approval,show_in_calendar,carry_over_allowed,max_carry_over_days,approval_policy_id,is_active)
SELECT id,tenant_id,code,name,is_paid::boolean,NULLIF(default_entitlement_days,'')::numeric,requires_document::boolean,requires_approval::boolean,
  show_in_calendar::boolean,carry_over_allowed::boolean,NULLIF(max_carry_over_days,'')::numeric,approval_policy_id,is_active::boolean
FROM st_lt ON CONFLICT (id) DO NOTHING;

CREATE TEMP TABLE st_lb (LIKE puls_workflow.leave_balances INCLUDING DEFAULTS);
\copy st_lb (id,tenant_id,employee_id,leave_type_id,period_year,source,entitlement_days,carried_over_days,adjustment_days,used_days,pending_days,as_of_date) FROM 'csv/14_leave_balances.csv' CSV HEADER
INSERT INTO puls_workflow.leave_balances (id,tenant_id,employee_id,leave_type_id,period_year,source,entitlement_days,carried_over_days,adjustment_days,used_days,pending_days,as_of_date)
SELECT id,tenant_id,employee_id,leave_type_id,period_year::int,source::puls_workflow.balance_source,
  entitlement_days::numeric,carried_over_days::numeric,adjustment_days::numeric,used_days::numeric,pending_days::numeric,as_of_date
FROM st_lb ON CONFLICT (id) DO NOTHING;

CREATE TEMP TABLE st_ec (
  id uuid, tenant_id uuid, code text, name text, monthly_limit text, receipt_required_over text,
  default_vat_rate text, approval_policy_id uuid, erp_account_code text, is_active text
);
\copy st_ec (id,tenant_id,code,name,monthly_limit,receipt_required_over,default_vat_rate,approval_policy_id,erp_account_code,is_active) FROM 'csv/15_expense_categories.csv' CSV HEADER
INSERT INTO puls_workflow.expense_categories (id,tenant_id,code,name,monthly_limit,receipt_required_over,default_vat_rate,approval_policy_id,erp_account_code,is_active)
SELECT id,tenant_id,code,name,NULLIF(monthly_limit,'')::numeric,NULLIF(receipt_required_over,'')::numeric,
  NULLIF(default_vat_rate,'')::numeric,approval_policy_id,NULLIF(erp_account_code,''),is_active::boolean
FROM st_ec ON CONFLICT (id) DO NOTHING;

-- Phase 19–20: erp mappings, identity map
CREATE TEMP TABLE st_map (
  id uuid, tenant_id uuid, connection_id uuid, source_entity text, source_field text,
  target_schema text, target_table text, target_field text, transform_rule text,
  is_required text, is_sensitive text, is_active text
);
\copy st_map (id,tenant_id,connection_id,source_entity,source_field,target_schema,target_table,target_field,transform_rule,is_required,is_sensitive,is_active) FROM 'csv/17_erp_field_mappings.csv' CSV HEADER
INSERT INTO puls_integration.erp_field_mappings (id,tenant_id,connection_id,source_entity,source_field,target_schema,target_table,target_field,transform_rule,is_required,is_sensitive,is_active)
SELECT id,tenant_id,connection_id,source_entity,source_field,target_schema,target_table,target_field,transform_rule::jsonb,is_required::boolean,is_sensitive::boolean,is_active::boolean
FROM st_map ON CONFLICT (id) DO NOTHING;

CREATE TEMP TABLE st_eim (LIKE puls_integration.entity_identity_map INCLUDING DEFAULTS);
\copy st_eim (id,tenant_id,source_namespace_id,entity_type,external_id,canonical_schema,canonical_table,canonical_id,is_active) FROM 'csv/19_entity_identity_map.csv' CSV HEADER
INSERT INTO puls_integration.entity_identity_map (id,tenant_id,source_namespace_id,entity_type,external_id,canonical_schema,canonical_table,canonical_id,is_active)
SELECT id,tenant_id,source_namespace_id,entity_type::puls_integration.import_entity_type,external_id,canonical_schema,canonical_table,canonical_id,is_active::boolean
FROM st_eim ON CONFLICT (id) DO NOTHING;

-- Phase 21–22: performance + contracts
CREATE TEMP TABLE st_pc (
  id uuid, tenant_id uuid, name text, status text, starts_at text, ends_at text, scope text, kpi_frequency text
);
\copy st_pc (id,tenant_id,name,status,starts_at,ends_at,scope,kpi_frequency) FROM 'csv/20_performance_cycles.csv' CSV HEADER
INSERT INTO puls_performance.performance_cycles (id,tenant_id,name,status,starts_at,ends_at,scope,kpi_frequency)
SELECT id,tenant_id,name,status::puls_performance.performance_cycle_status,starts_at::date,ends_at::date,scope,NULLIF(kpi_frequency,'')
FROM st_pc ON CONFLICT (id) DO NOTHING;

CREATE TEMP TABLE st_p21 (
  target_table text, id uuid, tenant_id uuid, name text, description text, weight text, scale_min text, scale_max text,
  sort_order text, is_active text, category_code text, category_name text, weight_pct text, band text, label text,
  min_score text, max_score text, employee_id text, source_module text, skill_topic text, need_level text,
  priority text, status text, current_step text, target_step text, readiness_score text, missing_competencies text
);
\copy st_p21 FROM 'csv/21_performance_parameters.csv' CSV HEADER
INSERT INTO puls_performance.competency_templates (id,tenant_id,name,description,weight,scale_min,scale_max,sort_order,is_active)
SELECT id,tenant_id,name,description,weight::numeric,scale_min::int,scale_max::int,sort_order::int,is_active::boolean
FROM st_p21 WHERE target_table='competency_templates' ON CONFLICT (id) DO NOTHING;
INSERT INTO puls_performance.kpi_category_weights (id,tenant_id,category_code,category_name,weight_pct,sort_order,is_active)
SELECT id,tenant_id,category_code,category_name,weight_pct::numeric,sort_order::int,is_active::boolean
FROM st_p21 WHERE target_table='kpi_category_weights' ON CONFLICT (id) DO NOTHING;
INSERT INTO puls_performance.score_bands (id,tenant_id,band,label,min_score,max_score,sort_order,is_active)
SELECT id,tenant_id,band::puls_performance.score_band,label,min_score::numeric,max_score::numeric,sort_order::int,is_active::boolean
FROM st_p21 WHERE target_table='score_bands' ON CONFLICT (id) DO NOTHING;
INSERT INTO puls_performance.training_needs (id,tenant_id,employee_id,source_module,skill_topic,need_level,priority,status)
SELECT id,tenant_id,employee_id::uuid,source_module,skill_topic,need_level,priority::int,status::puls_performance.training_need_status
FROM st_p21 WHERE target_table='training_needs' ON CONFLICT (id) DO NOTHING;
INSERT INTO puls_performance.career_profiles (id,tenant_id,employee_id,current_step,target_step,readiness_score,missing_competencies)
SELECT id,tenant_id,employee_id::uuid,current_step,target_step,readiness_score::numeric,missing_competencies::jsonb
FROM st_p21 WHERE target_table='career_profiles' ON CONFLICT (id) DO NOTHING;

CREATE TEMP TABLE st_con (
  id uuid, tenant_id uuid, employee_id uuid, contract_type text, start_date text, end_date text,
  status text, signature_status text, risk_band text, metadata_only text, external_source text, external_contract_id text
);
\copy st_con (id,tenant_id,employee_id,contract_type,start_date,end_date,status,signature_status,risk_band,metadata_only,external_source,external_contract_id) FROM 'csv/22_contracts.csv' CSV HEADER
INSERT INTO puls_workflow.contracts (id,tenant_id,employee_id,contract_type,start_date,end_date,status,signature_status,risk_band,metadata_only,external_source,external_contract_id)
SELECT id,tenant_id,employee_id,contract_type,start_date::date,NULLIF(end_date,'')::date,
  status::puls_workflow.contract_status,signature_status::puls_workflow.contract_signature_status,
  risk_band::puls_workflow.contract_risk_band,metadata_only::boolean,NULLIF(external_source,''),NULLIF(external_contract_id,'')
FROM st_con ON CONFLICT (id) DO NOTHING;

COMMIT;
