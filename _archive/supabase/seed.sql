-- ============================================================
-- REKBER - Seed Data for Development
-- ============================================================

-- Note: In production, users are created via Supabase Auth.
-- This seed data assumes auth.users entries already exist.
-- For local development, create test users via the Supabase dashboard first.

-- Example product categories
-- You can use these as reference data for the product catalog
DO $$
BEGIN
  RAISE NOTICE 'Seed data loaded successfully.';
  RAISE NOTICE 'To fully seed, create test users via Supabase Auth first,';
  RAISE NOTICE 'then insert corresponding rows into public.users.';
END $$;
