-- Completed: past calendar-day runs (America/Los_Angeles) are closed for signup.
-- Idempotent RPC clients call before reads; also locks payments when completing.

ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_status_check;

ALTER TABLE public.sessions
  ADD CONSTRAINT sessions_status_check
  CHECK (status IN ('open', 'cancelled', 'completed'));

CREATE OR REPLACE FUNCTION public.mark_past_sessions_completed()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.sessions
  SET
    status = 'completed',
    payments_open = false
  WHERE status = 'open'
    AND date < ((now() AT TIME ZONE 'America/Los_Angeles')::date);
$$;

REVOKE ALL ON FUNCTION public.mark_past_sessions_completed() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_past_sessions_completed() TO anon, authenticated, service_role;

SELECT public.mark_past_sessions_completed();

-- Reject new RSVPs when session is not open (cancelled / completed)
CREATE OR REPLACE FUNCTION public.insert_rsvp_if_capacity(
  p_session_id uuid,
  p_player_name text,
  p_player_email text,
  p_stripe_session_id text
) RETURNS TABLE(inserted boolean, confirmed_count integer, max_players integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_max integer;
  v_status text;
  v_count integer;
  v_inserted boolean := false;
BEGIN
  SELECT s.max_players, s.status INTO v_max, v_status
  FROM public.sessions s
  WHERE s.id = p_session_id
  FOR UPDATE;

  IF v_max IS NULL THEN
    RAISE EXCEPTION 'session % not found', p_session_id;
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.rsvps r
  WHERE r.session_id = p_session_id;

  IF v_status IS DISTINCT FROM 'open' THEN
    RETURN QUERY SELECT false, v_count, v_max;
    RETURN;
  END IF;

  IF v_count < v_max THEN
    INSERT INTO public.rsvps (session_id, player_name, player_email, stripe_session_id)
    VALUES (p_session_id, p_player_name, p_player_email, p_stripe_session_id);
    v_inserted := true;
    v_count := v_count + 1;
  END IF;

  RETURN QUERY SELECT v_inserted, v_count, v_max;
END;
$$;
