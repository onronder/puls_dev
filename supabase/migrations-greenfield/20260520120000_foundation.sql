-- PULS Foundation Migration (Sprint-1)
-- Supabase Postgres + RLS

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TYPE public.persona_role AS ENUM (
  'employee',
  'manager',
  'hr_admin',
  'superadmin'
);

CREATE TYPE public.erp_provider AS ENUM ('canias', 'logo', 'csv');

CREATE TABLE public.tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  legal_name TEXT NOT NULL,
  trade_name TEXT,
  tax_no TEXT,
  kvkk_active BOOLEAN NOT NULL DEFAULT TRUE,
  verbis_registered BOOLEAN NOT NULL DEFAULT FALSE,
  plan_name TEXT NOT NULL DEFAULT 'growth',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT,
  parent_id UUID REFERENCES public.departments(id),
  manager_employee_id UUID,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.positions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT,
  department_id UUID REFERENCES public.departments(id),
  level INTEGER,
  parent_position_id UUID REFERENCES public.positions(id),
  salary_min NUMERIC(18, 2),
  salary_max NUMERIC(18, 2),
  employment_type TEXT,
  norm_headcount INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.employees (
  anonymous_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  job_title TEXT,
  department_id UUID REFERENCES public.departments(id),
  position_id UUID REFERENCES public.positions(id),
  persona_role public.persona_role NOT NULL DEFAULT 'employee',
  hire_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.departments
  ADD CONSTRAINT departments_manager_fk
  FOREIGN KEY (manager_employee_id) REFERENCES public.employees(anonymous_id);

CREATE TABLE public.erp_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  provider public.erp_provider NOT NULL DEFAULT 'canias',
  display_name TEXT NOT NULL,
  base_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  sync_schedule TEXT DEFAULT '0 4 * * *',
  last_sync_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.erp_field_mappings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  connection_id UUID NOT NULL REFERENCES public.erp_connections(id) ON DELETE CASCADE,
  erp_namespace TEXT NOT NULL,
  erp_field TEXT NOT NULL,
  puls_namespace TEXT NOT NULL,
  puls_canonical_field TEXT NOT NULL,
  transform_rule JSONB DEFAULT '{}'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (connection_id, erp_field, puls_canonical_field)
);

CREATE TABLE public.erp_sync_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  connection_id UUID NOT NULL REFERENCES public.erp_connections(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  records_processed INTEGER DEFAULT 0,
  error_message TEXT,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finished_at TIMESTAMPTZ
);

CREATE TABLE public.performans_competency_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  weight NUMERIC(5, 2) DEFAULT 1,
  scale_min INTEGER DEFAULT 1,
  scale_max INTEGER DEFAULT 5,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE SCHEMA IF NOT EXISTS vault;
CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE vault.conversation_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  anonymous_employee_id UUID NOT NULL REFERENCES public.employees(anonymous_id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('user', 'ai_koc', 'system')),
  message_text TEXT NOT NULL,
  module_context TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE audit.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES public.tenants(id) ON DELETE SET NULL,
  actor_id UUID,
  action TEXT NOT NULL,
  target_object JSONB DEFAULT '{}'::jsonb,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  request_metadata JSONB DEFAULT '{}'::jsonb
);

-- Helper: current user's tenant from employees row
CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT tenant_id FROM public.employees WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.current_employee_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT anonymous_id FROM public.employees WHERE user_id = auth.uid() LIMIT 1;
$$;

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.erp_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.erp_field_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.erp_sync_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.performans_competency_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE vault.conversation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenants_select ON public.tenants
  FOR SELECT TO authenticated
  USING (id = public.current_tenant_id());

CREATE POLICY departments_tenant ON public.departments
  FOR ALL TO authenticated
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE POLICY positions_tenant ON public.positions
  FOR ALL TO authenticated
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE POLICY employees_tenant_select ON public.employees
  FOR SELECT TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE POLICY employees_self_update ON public.employees
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY erp_connections_tenant ON public.erp_connections
  FOR ALL TO authenticated
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE POLICY erp_field_mappings_tenant ON public.erp_field_mappings
  FOR ALL TO authenticated
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE POLICY erp_sync_logs_tenant ON public.erp_sync_logs
  FOR SELECT TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE POLICY competency_templates_tenant ON public.performans_competency_templates
  FOR ALL TO authenticated
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE POLICY vault_employee_select_own ON vault.conversation_messages
  FOR SELECT TO authenticated
  USING (anonymous_employee_id = public.current_employee_id());

CREATE POLICY vault_employee_insert_own ON vault.conversation_messages
  FOR INSERT TO authenticated
  WITH CHECK (anonymous_employee_id = public.current_employee_id());

CREATE POLICY audit_insert ON audit.audit_logs
  FOR INSERT TO authenticated
  WITH CHECK (tenant_id IS NULL OR tenant_id = public.current_tenant_id());

CREATE POLICY audit_select_tenant ON audit.audit_logs
  FOR SELECT TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE INDEX idx_departments_tenant ON public.departments(tenant_id);
CREATE INDEX idx_positions_tenant ON public.positions(tenant_id);
CREATE INDEX idx_employees_tenant ON public.employees(tenant_id);
CREATE INDEX idx_employees_user ON public.employees(user_id);
CREATE INDEX idx_erp_mappings_connection ON public.erp_field_mappings(connection_id);
