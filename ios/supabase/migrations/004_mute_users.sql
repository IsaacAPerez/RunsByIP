-- Add mute column to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_muted BOOLEAN NOT NULL DEFAULT false;

-- Allow admins to update is_muted on any profile
CREATE POLICY "Admins can mute users"
  ON profiles FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Recreate messages_with_profiles view (preserve existing definition)
CREATE OR REPLACE VIEW messages_with_profiles AS
SELECT
  m.id,
  m.user_id,
  COALESCE(p.display_name, m.display_name, '') AS display_name,
  p.avatar_url,
  m.content,
  m.message_type,
  m.attachment_path,
  m.created_at
FROM messages m
LEFT JOIN profiles p ON p.id = m.user_id;

-- Ensure PostgREST can read the updated view
GRANT SELECT ON messages_with_profiles TO anon, authenticated;
