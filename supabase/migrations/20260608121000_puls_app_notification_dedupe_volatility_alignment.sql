-- PR16.10.9 idempotent volatility alignment for databases that already
-- applied the first runtime hardening migration while the normalizer was
-- marked IMMUTABLE. The function uses regexp/operator evaluation that the
-- Supabase linter classifies as STABLE.

ALTER FUNCTION puls_app.normalize_app_notification_dedupe_key(TEXT, TEXT, TEXT)
  STABLE;
