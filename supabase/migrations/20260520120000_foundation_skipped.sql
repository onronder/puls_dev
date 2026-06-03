-- Greenfield foundation SQL lives in supabase/migrations-greenfield/.
-- Lovable-linked projects: mark this version applied (repair) or let it no-op, then push 20260520130000.
--
-- Local Supabase reset starts from an empty database, while the following
-- migrations extend a Lovable-style public schema. Keep this migration
-- idempotent: existing remote public tables remain untouched, and fresh local
-- databases get the minimal compatibility baseline needed by later migrations.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS public.tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL DEFAULT 'PULS Local Tenant',
  legal_name TEXT,
  trade_name TEXT,
  vkn TEXT,
  tax_no TEXT,
  sector TEXT,
  timezone TEXT NOT NULL DEFAULT 'Europe/Istanbul',
  locale TEXT NOT NULL DEFAULT 'tr-TR',
  plan TEXT,
  plan_name TEXT,
  kvkk_active BOOLEAN NOT NULL DEFAULT TRUE,
  verbis_registered BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.user_tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'employee',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, tenant_id, role)
);

CREATE INDEX IF NOT EXISTS idx_public_user_tenants_user_default
  ON public.user_tenants (user_id, is_default);

CREATE INDEX IF NOT EXISTS idx_public_user_roles_user_tenant
  ON public.user_roles (user_id, tenant_id);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'profiles'
  ) THEN
    RAISE NOTICE 'Lovable auth schema detected — skipping greenfield foundation';
  END IF;
END $$;
