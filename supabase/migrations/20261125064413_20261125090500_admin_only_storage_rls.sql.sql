/*
# Lock storage buckets to authenticated admins

1. Security changes
- Replace wide-open (anon + authenticated) storage policies for the
  `feedback-photos` and `team-photos` buckets with authenticated-only policies
  gated by `is_allowed_admin()`.
- Unauthenticated visitors can no longer read, upload, or delete photos.
- No data is removed; only access rules change.
*/

DROP POLICY IF EXISTS "anon_read_feedback_photos" ON storage.objects;
DROP POLICY IF EXISTS "anon_upload_feedback_photos" ON storage.objects;
DROP POLICY IF EXISTS "anon_delete_feedback_photos" ON storage.objects;
DROP POLICY IF EXISTS "anon_read_team_photos" ON storage.objects;
DROP POLICY IF EXISTS "anon_upload_team_photos" ON storage.objects;
DROP POLICY IF EXISTS "anon_delete_team_photos" ON storage.objects;

CREATE POLICY "admin_read_feedback_photos"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'feedback-photos' AND is_allowed_admin());

CREATE POLICY "admin_insert_feedback_photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'feedback-photos' AND is_allowed_admin());

CREATE POLICY "admin_update_feedback_photos"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'feedback-photos' AND is_allowed_admin())
WITH CHECK (bucket_id = 'feedback-photos' AND is_allowed_admin());

CREATE POLICY "admin_delete_feedback_photos"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'feedback-photos' AND is_allowed_admin());

CREATE POLICY "admin_read_team_photos"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'team-photos' AND is_allowed_admin());

CREATE POLICY "admin_insert_team_photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'team-photos' AND is_allowed_admin());

CREATE POLICY "admin_update_team_photos"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'team-photos' AND is_allowed_admin())
WITH CHECK (bucket_id = 'team-photos' AND is_allowed_admin());

CREATE POLICY "admin_delete_team_photos"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'team-photos' AND is_allowed_admin());