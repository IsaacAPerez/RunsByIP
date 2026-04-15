-- Adds a `platform` column so a session can be targeted to one client app
-- (web, iOS) or all of them. Existing sessions default to 'all' so nothing
-- changes for current users. The iOS app filters in ('all','ios'); the web
-- app filters in ('all','web'). Admin UIs show every row regardless.

ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS platform TEXT NOT NULL DEFAULT 'all';

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'sessions_platform_check'
  ) THEN
    ALTER TABLE sessions
      ADD CONSTRAINT sessions_platform_check
      CHECK (platform IN ('all', 'web', 'ios'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS sessions_platform_idx ON sessions (platform);
