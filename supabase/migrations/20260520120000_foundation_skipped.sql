-- Greenfield foundation SQL lives in supabase/migrations-greenfield/.
-- Lovable-linked projects: mark this version applied (repair) or let it no-op, then push 20260520130000.

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
