-- Lower-priority advisor cleanups.

-- =============================================================================
-- pow_votes: require authentication (iOS app is the only caller and is always
-- signed in when voting). Previous WITH CHECK (true) let anyone with the
-- anon key cast votes.
-- =============================================================================
DROP POLICY IF EXISTS "Anyone can vote" ON pow_votes;

CREATE POLICY "Authenticated users can vote" ON pow_votes
  FOR INSERT TO authenticated
  WITH CHECK (auth.role() = 'authenticated');

-- =============================================================================
-- Storage: drop anon list access on public buckets.
-- Public buckets serve downloads via the CDN at /storage/v1/object/public/...
-- regardless of RLS, so dropping these SELECT policies does NOT break image
-- display through getPublicURL(). It only blocks list() calls from anon.
-- =============================================================================

-- avatars & chat-media: iOS never enumerates these, just uploads and displays
-- via public URL. Drop listing entirely.
DROP POLICY IF EXISTS "Avatars are publicly accessible" ON storage.objects;
DROP POLICY IF EXISTS "Public can read chat media" ON storage.objects;

-- gallery: iOS admin calls .list() to populate the home hero strip. Keep list
-- capability but require auth (all app users are signed in).
DROP POLICY IF EXISTS "Public gallery read" ON storage.objects;

CREATE POLICY "Authenticated can list gallery" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'gallery');
