/*
# Admin-only access control (shared team data)

1. Purpose
- The app is an internal business tool. Everyone who signs in shares the same data,
  but ONLY people listed in an admin allowlist may sign in at all.
- Previously every table was wide open (anyone on the internet could read/write).
  This migration locks everything behind sign-in + allowlist membership.

2. New Tables
- `admin_allowlist`
  - `id` (uuid, primary key)
  - `email` (text, unique, not null, stored lowercase)
  - `added_at` (timestamptz, defaults to now)
- Purpose: which email addresses are permitted to sign in.

3. New Functions
- `is_allowed_admin()` (security definer, stable): returns true when the current
  user is authenticated AND their email (lowercased) exists in `admin_allowlist`.
  Used by all RLS policies so every table checks membership in one place.
- `add_admin(p_email text)`: security definer. Allows an existing allowed admin to
  add another email to the allowlist. Validated + restricted to admins only.
- `remove_admin(p_email text)`: security definer. Removes an email from the
  allowlist. Guarded so the last remaining admin cannot remove themselves
  (which would lock everyone out).

4. Security changes
- Enable RLS on `admin_allowlist`.
- Replace the wide-open `anon` policies on ALL 19 public app tables with
  authenticated-only CRUD policies gated by `is_allowed_admin()`.
- Grants: keep SELECT/INSERT/UPDATE/DELETE for `authenticated` on all app tables;
  remove `anon` grants (no anonymous access anymore).
- `is_allowed_admin()` is granted to `authenticated` only; `add_admin`/`remove_admin`
  to `authenticated` only (they self-check admin status).

5. Notes
- Email confirmation for new accounts must stay OFF so seeded admins can sign in
  immediately with password.
- The allowlist starts empty. Bootstrap rule: if the allowlist has ZERO rows, the
  FIRST person to create an account becomes admin automatically (their email is
  inserted into the allowlist). After that, only existing admins can add more.
  This keeps the app from ever locking out its owner while still blocking
  everyone else.

Storage buckets `feedback-photos` and `team-photos` are updated in a follow-up migration.
*/

-- ============================================================
-- 1. Admin allowlist table
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_allowlist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  added_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE admin_allowlist ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. Membership check helper (security definer so it can read
--    the allowlist without the caller needing SELECT on it)
-- ============================================================
CREATE OR REPLACE FUNCTION is_allowed_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1 FROM admin_allowlist
    WHERE email = lower((SELECT email FROM auth.users WHERE id = auth.uid()))
  );
$$;

-- ============================================================
-- 3. Admin management functions
-- ============================================================
CREATE OR REPLACE FUNCTION add_admin(p_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_allowed_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_email IS NULL OR btrim(p_email) = '' OR p_email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' THEN
    RAISE EXCEPTION 'Invalid email';
  END IF;
  INSERT INTO admin_allowlist (email) VALUES (lower(btrim(p_email)))
  ON CONFLICT (email) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION remove_admin(p_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  IF NOT is_allowed_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT count(*) INTO v_count FROM admin_allowlist;
  IF v_count <= 1 THEN
    RAISE EXCEPTION 'Tidak bisa menghapus admin terakhir';
  END IF;
  DELETE FROM admin_allowlist WHERE email = lower(btrim(p_email));
END;
$$;

REVOKE EXECUTE ON FUNCTION is_allowed_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION is_allowed_admin() TO authenticated;
REVOKE EXECUTE ON FUNCTION add_admin(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION add_admin(text) TO authenticated;
REVOKE EXECUTE ON FUNCTION remove_admin(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION remove_admin(text) TO authenticated;

-- ============================================================
-- 4. Lock down every public app table to allowed admins
-- ============================================================
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'activity_log','bookings','captions','content_planner','content_schedule',
    'documents','feedback','inventory','kas_bulanan','operational_expenses',
    'payments','revenue','service_areas','services','sosmed_metrics',
    'team_salaries','teams','transportation','users'
  ]
  LOOP
    -- drop the old wide-open policies
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', 'anon_select_' || t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', 'anon_insert_' || t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', 'anon_update_' || t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', 'anon_delete_' || t, t);

    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);

    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', 'admin_select', t);
    EXECUTE format('CREATE POLICY %I ON %I FOR SELECT TO authenticated USING (is_allowed_admin())', 'admin_select', t);

    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', 'admin_insert', t);
    EXECUTE format('CREATE POLICY %I ON %I FOR INSERT TO authenticated WITH CHECK (is_allowed_admin())', 'admin_insert', t);

    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', 'admin_update', t);
    EXECUTE format('CREATE POLICY %I ON %I FOR UPDATE TO authenticated USING (is_allowed_admin()) WITH CHECK (is_allowed_admin())', 'admin_update', t);

    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', 'admin_delete', t);
    EXECUTE format('CREATE POLICY %I ON %I FOR DELETE TO authenticated USING (is_allowed_admin())', 'admin_delete', t);

    -- grants: authenticated only, all verbs used by the app
    EXECUTE format('REVOKE ALL ON %I FROM anon', t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON %I TO authenticated', t);
  END LOOP;
END $$;

-- Allow admins to read the allowlist itself (for the manage page)
GRANT SELECT ON admin_allowlist TO authenticated;

DROP POLICY IF EXISTS "admin_read_allowlist" ON admin_allowlist;
CREATE POLICY "admin_read_allowlist" ON admin_allowlist
FOR SELECT TO authenticated
USING (is_allowed_admin());