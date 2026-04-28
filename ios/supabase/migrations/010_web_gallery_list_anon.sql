-- Allow the marketing site (anon key) to list objects in the public `gallery`
-- bucket so the homepage hero can mirror the iOS scrolling strip. Object reads
-- are already public via getPublicURL; this only exposes filenames in that bucket.

CREATE POLICY "Anon can list gallery for web hero"
  ON storage.objects
  FOR SELECT
  TO anon
  USING (bucket_id = 'gallery');
