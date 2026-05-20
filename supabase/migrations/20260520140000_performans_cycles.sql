-- Performans review cycles (Sprint-2 follow-up)

DO $$ BEGIN
  CREATE TYPE public.performans_cycle_status AS ENUM ('draft', 'active', 'closed');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.performans_cycles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  status public.performans_cycle_status NOT NULL DEFAULT 'draft',
  starts_at DATE NOT NULL,
  ends_at DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_at >= starts_at)
);

ALTER TABLE public.performans_cycles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS performans_cycles_tenant ON public.performans_cycles;
CREATE POLICY performans_cycles_tenant ON public.performans_cycles
  FOR ALL TO authenticated
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE INDEX IF NOT EXISTS idx_performans_cycles_tenant ON public.performans_cycles(tenant_id);
