-- Server-side chat write gate: stores a bcrypt hash only (no plaintext).
-- iOS (authenticated) calls public.verify_chat_write_gate(p_attempt).
--
-- Rotate password in SQL Editor (Dashboard → SQL):
--   UPDATE chat_write_gate
--   SET password_hash = extensions.crypt('your-new-secret', extensions.gen_salt('bf'))
--   WHERE id = 1;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS chat_write_gate (
  id SMALLINT PRIMARY KEY CHECK (id = 1),
  password_hash TEXT NOT NULL
);

ALTER TABLE chat_write_gate ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE chat_write_gate FROM PUBLIC;
REVOKE ALL ON TABLE chat_write_gate FROM anon;
REVOKE ALL ON TABLE chat_write_gate FROM authenticated;
GRANT ALL ON TABLE chat_write_gate TO service_role;

-- Placeholder matches initial client docs; change via UPDATE after deploy.
INSERT INTO chat_write_gate (id, password_hash)
VALUES (
  1,
  extensions.crypt('REPLACE_WITH_YOUR_PASSPHRASE', extensions.gen_salt('bf'))
)
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.verify_chat_write_gate(p_attempt TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  stored TEXT;
  attempt TEXT;
BEGIN
  attempt := trim(p_attempt);
  IF attempt IS NULL OR attempt = '' THEN
    RETURN FALSE;
  END IF;

  SELECT c.password_hash INTO stored FROM public.chat_write_gate c WHERE c.id = 1;
  IF stored IS NULL OR stored = '' THEN
    RETURN FALSE;
  END IF;

  RETURN extensions.crypt(attempt, stored) = stored;
END;
$$;

REVOKE ALL ON FUNCTION public.verify_chat_write_gate(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_chat_write_gate(TEXT) TO authenticated;
