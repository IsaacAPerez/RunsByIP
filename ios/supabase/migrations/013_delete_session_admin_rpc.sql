-- Admin delete for the web dashboard. Cleans every public table that
-- references public.sessions (push_log, pow_polls/votes, rsvps) before
-- deleting the session itself, so foreign-key constraints don't block it.

CREATE OR REPLACE FUNCTION public.delete_session_admin(p_session_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  n int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'push_log'
  ) THEN
    DELETE FROM public.push_log WHERE session_id = p_session_id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'pow_polls'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'pow_votes'
    ) THEN
      DELETE FROM public.pow_votes
      WHERE poll_id IN (
        SELECT id FROM public.pow_polls WHERE session_id = p_session_id
      );
    END IF;

    DELETE FROM public.pow_polls WHERE session_id = p_session_id;
  END IF;

  -- rsvps cascades on the FK; explicit delete is a no-op safeguard.
  DELETE FROM public.rsvps WHERE session_id = p_session_id;

  DELETE FROM public.sessions WHERE id = p_session_id;
  GET DIAGNOSTICS n = ROW_COUNT;

  RETURN json_build_object('ok', n > 0, 'rows', n);
END;
$$;

REVOKE ALL ON FUNCTION public.delete_session_admin(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_session_admin(uuid) TO authenticated;
