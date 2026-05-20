-- Puls product tables on top of existing Lovable auth schema.
-- Safe to run when public.tenants, profiles, user_tenants, user_roles already exist.
-- Do NOT run 20260520120000_foundation.sql on the same database.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$ BEGIN
  CREATE TYPE public.persona_role AS ENUM (
    'employee', 'manager', 'hr_admin', 'superadmin'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.erp_provider AS ENUM ('canias', 'logo', 'csv');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Extend Lovable tenants with Puls-specific columns (non-breaking)
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS legal_name TEXT;
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS trade_name TEXT;
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS tax_no TEXT;
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS kvkk_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS verbis_registered BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS plan_name TEXT;

UPDATE public.tenants
SET
  legal_name = COALESCE(legal_name, name),
  trade_name = COALESCE(trade_name, name),
  tax_no = COALESCE(tax_no, vkn),
  plan_name = COALESCE(plan_name, plan)
WHERE legal_name IS NULL OR trade_name IS NULL OR tax_no IS NULL OR plan_name IS NULL;

CREATE TABLE IF NOT EXISTS public.departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT,
  parent_id UUID REFERENCES public.departments(id),
  manager_employee_id UUID,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.positions (
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

CREATE TABLE IF NOT EXISTS public.employees (
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

DO $$ BEGIN
  ALTER TABLE public.departments
    ADD CONSTRAINT departments_manager_fk
    FOREIGN KEY (manager_employee_id) REFERENCES public.employees(anonymous_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.erp_connections (
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

CREATE TABLE IF NOT EXISTS public.erp_field_mappings (
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

CREATE TABLE IF NOT EXISTS public.erp_sync_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  connection_id UUID NOT NULL REFERENCES public.erp_connections(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  records_processed INTEGER DEFAULT 0,
  error_message TEXT,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finished_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.performans_competency_templates (
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

CREATE TABLE IF NOT EXISTS vault.conversation_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  anonymous_employee_id UUID NOT NULL REFERENCES public.employees(anonymous_id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('user', 'ai_koc', 'system')),
  message_text TEXT NOT NULL,
  module_context TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE IF NOT EXISTS audit.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES public.tenants(id) ON DELETE SET NULL,
  actor_id UUID,
  action TEXT NOT NULL,
  target_object JSONB DEFAULT '{}'::jsonb,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  request_metadata JSONB DEFAULT '{}'::jsonb
);

-- Tenant resolution: employees row OR Lovable user_tenants default
CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT tenant_id FROM public.employees WHERE user_id = auth.uid() LIMIT 1),
    (SELECT tenant_id FROM public.user_tenants WHERE user_id = auth.uid() AND is_default IS TRUE LIMIT 1),
    (SELECT tenant_id FROM public.user_tenants WHERE user_id = auth.uid() ORDER BY joined_at ASC NULLS LAST LIMIT 1)
  );
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

-- Map Lovable app_role → Puls persona (adjust enum values if your DB differs)
CREATE OR REPLACE FUNCTION public.current_persona_role()
RETURNS public.persona_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT persona_role FROM public.employees WHERE user_id = auth.uid() LIMIT 1),
    (
      SELECT CASE ur.role::text
        WHEN 'superadmin' THEN 'superadmin'::public.persona_role
        WHEN 'owner' THEN 'hr_admin'::public.persona_role
        WHEN 'admin' THEN 'hr_admin'::public.persona_role
        WHEN 'hr_admin' THEN 'hr_admin'::public.persona_role
        WHEN 'hr' THEN 'hr_admin'::public.persona_role
        WHEN 'manager' THEN 'manager'::public.persona_role
        ELSE 'employee'::public.persona_role
      END
      FROM public.user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.tenant_id = public.current_tenant_id()
      LIMIT 1
    ),
    'employee'::public.persona_role
  );
$$;

ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.erp_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.erp_field_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.erp_sync_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.performans_competency_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE vault.conversation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS departments_tenant ON public.departments;
CREATE POLICY departments_tenant ON public.departments
  FOR ALL TO authenticated
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS positions_tenant ON public.positions;
CREATE POLICY positions_tenant ON public.positions
  FOR ALL TO authenticated
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS employees_tenant_select ON public.employees;
CREATE POLICY employees_tenant_select ON public.employees
  FOR SELECT TO authenticated
  USING (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS employees_self_update ON public.employees;
CREATE POLICY employees_self_update ON public.employees
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS erp_connections_tenant ON public.erp_connections;
CREATE POLICY erp_connections_tenant ON public.erp_connections
  FOR ALL TO authenticated
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS erp_field_mappings_tenant ON public.erp_field_mappings;
CREATE POLICY erp_field_mappings_tenant ON public.erp_field_mappings
  FOR ALL TO authenticated
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS erp_sync_logs_tenant ON public.erp_sync_logs;
CREATE POLICY erp_sync_logs_tenant ON public.erp_sync_logs
  FOR SELECT TO authenticated
  USING (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS competency_templates_tenant ON public.performans_competency_templates;
CREATE POLICY competency_templates_tenant ON public.performans_competency_templates
  FOR ALL TO authenticated
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS vault_employee_select_own ON vault.conversation_messages;
CREATE POLICY vault_employee_select_own ON vault.conversation_messages
  FOR SELECT TO authenticated
  USING (anonymous_employee_id = public.current_employee_id());

DROP POLICY IF EXISTS vault_employee_insert_own ON vault.conversation_messages;
CREATE POLICY vault_employee_insert_own ON vault.conversation_messages
  FOR INSERT TO authenticated
  WITH CHECK (anonymous_employee_id = public.current_employee_id());

DROP POLICY IF EXISTS audit_insert ON audit.audit_logs;
CREATE POLICY audit_insert ON audit.audit_logs
  FOR INSERT TO authenticated
  WITH CHECK (tenant_id IS NULL OR tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS audit_select_tenant ON audit.audit_logs;
CREATE POLICY audit_select_tenant ON audit.audit_logs
  FOR SELECT TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE INDEX IF NOT EXISTS idx_departments_tenant ON public.departments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_positions_tenant ON public.positions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_employees_tenant ON public.employees(tenant_id);
CREATE INDEX IF NOT EXISTS idx_employees_user ON public.employees(user_id);
CREATE INDEX IF NOT EXISTS idx_erp_mappings_connection ON public.erp_field_mappings(connection_id);

-- Link existing auth user to tenant via profiles + user_tenants (optional bootstrap)
CREATE OR REPLACE FUNCTION public.ensure_employee_from_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant UUID;
  v_profile RECORD;
BEGIN
  SELECT id, email, full_name INTO v_profile FROM public.profiles WHERE id = NEW.user_id;
  IF v_profile IS NULL THEN
    RETURN NEW;
  END IF;

  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.employees (tenant_id, user_id, email, full_name, persona_role)
  VALUES (
    v_tenant,
    NEW.user_id,
    COALESCE(v_profile.email, ''),
    COALESCE(v_profile.full_name, 'Kullanıcı'),
    public.current_persona_role()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    persona_role = EXCLUDED.persona_role;

  RETURN NEW;
END;
$$;

-- Run once for users already in user_tenants (idempotent)
INSERT INTO public.employees (tenant_id, user_id, email, full_name, persona_role)
SELECT
  ut.tenant_id,
  p.id,
  COALESCE(p.email, ''),
  COALESCE(p.full_name, 'Kullanıcı'),
  COALESCE(
    (SELECT CASE ur.role::text
      WHEN 'superadmin' THEN 'superadmin'::public.persona_role
      WHEN 'owner' THEN 'hr_admin'::public.persona_role
      WHEN 'admin' THEN 'hr_admin'::public.persona_role
      WHEN 'hr_admin' THEN 'hr_admin'::public.persona_role
      WHEN 'hr' THEN 'hr_admin'::public.persona_role
      WHEN 'manager' THEN 'manager'::public.persona_role
      ELSE 'employee'::public.persona_role
    END
    FROM public.user_roles ur
    WHERE ur.user_id = p.id AND ur.tenant_id = ut.tenant_id
    LIMIT 1),
    'employee'::public.persona_role
  )
FROM public.user_tenants ut
JOIN public.profiles p ON p.id = ut.user_id
WHERE NOT EXISTS (
  SELECT 1 FROM public.employees e WHERE e.user_id = p.id
);
