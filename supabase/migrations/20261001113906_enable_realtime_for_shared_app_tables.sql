/*
# Enable realtime synchronization for Dampingcare

## Overview
Enables Supabase Realtime for every existing table in the public schema so changes made on one phone or laptop are delivered to all other open devices.

## Database changes
- Adds every existing public table to the `supabase_realtime` publication.
- No rows, columns, policies, or existing data are changed.

## Security
- Existing RLS policies remain unchanged and continue to control which rows each device can read.
- This app is intentionally shared and does not have a sign-in screen, so its existing anon + authenticated policies remain in place.

## Important notes
1. Realtime only updates devices while the app is open and connected.
2. When the app is reopened, each page still loads the latest data from Supabase.
3. Storage files continue using their existing storage policies.
*/

DO $$
DECLARE
  table_record record;
BEGIN
  FOR table_record IN
    SELECT schemaname, tablename
    FROM pg_tables
    WHERE schemaname = 'public'
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I.%I', table_record.schemaname, table_record.tablename);
    EXCEPTION
      WHEN duplicate_object THEN NULL;
    END;
  END LOOP;
END $$;