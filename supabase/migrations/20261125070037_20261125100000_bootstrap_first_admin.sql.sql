/*
# Bootstrap first admin automatically

1. Purpose
- Fixes the missing bootstrap rule: when the admin allowlist is completely empty,
  the first person who creates an account must automatically become an admin.
  Without this, a new sign-up can never pass the `is_allowed_admin()` check and
  the app appears locked ("pendaftar pertama" could not get in).

2. New Functions
- `bootstrap_first_admin()` (trigger function, security definer): after a new
  auth user is created, if `admin_allowlist` has ZERO rows, that user's email is
  inserted into the allowlist. Later sign-ups are NOT auto-added — only existing
  admins can add more people via `add_admin()`.

3. New Triggers
- `bootstrap_first_admin_trigger` on `auth.users` (AFTER INSERT) runs the function
  above for every new account.

4. Backfill
- If someone already signed up while the rule was missing (allowlist empty but
  auth users exist), their email(s) are inserted into the allowlist now, so
  existing accounts are not lost.

5. Security notes
- The trigger function is SECURITY DEFINER with a fixed search_path; it only
  writes to `admin_allowlist` and only when the allowlist is empty, so it cannot
  be abused to grant admin to arbitrary later sign-ups.
- No existing data is modified beyond allowlist rows described above.
*/

CREATE OR REPLACE FUNCTION bootstrap_first_admin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (SELECT count(*) FROM admin_allowlist) = 0 THEN
    INSERT INTO admin_allowlist (email)
    VALUES (lower(NEW.email))
    ON CONFLICT (email) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS bootstrap_first_admin_trigger ON auth.users;
CREATE TRIGGER bootstrap_first_admin_trigger
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION bootstrap_first_admin();

-- Backfill: if accounts already exist and the allowlist is still empty,
-- allow every existing account (they were created before this rule existed).
DO $$
BEGIN
  IF (SELECT count(*) FROM admin_allowlist) = 0 THEN
    INSERT INTO admin_allowlist (email)
    SELECT DISTINCT lower(u.email) FROM auth.users u
    WHERE u.email IS NOT NULL
    ON CONFLICT (email) DO NOTHING;
  END IF;
END $$;