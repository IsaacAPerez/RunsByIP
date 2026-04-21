-- Tighten RLS on sessions + rsvps, and add an atomic capacity guard for the
-- payment webhook so two concurrent successful payments can't overbook.

-- =============================================================================
-- SESSIONS: admin-only INSERT / UPDATE / DELETE (anyone can still read)
-- =============================================================================
DROP POLICY IF EXISTS "Authenticated can insert sessions" ON sessions;
DROP POLICY IF EXISTS "Authenticated can update sessions" ON sessions;
DROP POLICY IF EXISTS "Admin can manage sessions" ON sessions;

CREATE POLICY "Admins can insert sessions" ON sessions
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Admins can update sessions" ON sessions
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Admins can delete sessions" ON sessions
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- =============================================================================
-- RSVPS: hide player_email from anon; allow admin deletes
-- =============================================================================
DROP POLICY IF EXISTS "RSVPs are publicly readable" ON rsvps;

CREATE POLICY "Authenticated can read rsvps" ON rsvps
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Admins can delete rsvps" ON rsvps
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- =============================================================================
-- session_rsvp_count RPC: lets the public marketing page show a confirmed
-- count without exposing player_email. SECURITY DEFINER so it reads through
-- the authenticated-only SELECT policy on rsvps.
-- =============================================================================
CREATE OR REPLACE FUNCTION session_rsvp_count(p_session_id uuid)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COUNT(*)::integer FROM rsvps WHERE session_id = p_session_id;
$$;

REVOKE EXECUTE ON FUNCTION session_rsvp_count(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION session_rsvp_count(uuid) TO anon, authenticated;

-- =============================================================================
-- insert_rsvp_if_capacity: atomic capacity check + insert.
-- SELECT ... FOR UPDATE on the session row serializes concurrent webhooks,
-- closing the TOCTOU race that would otherwise let two simultaneous payment
-- confirmations both pass a 14<15 check and both INSERT.
-- Returns `inserted=false` when the session filled up in between, so the
-- webhook can refund the PaymentIntent.
-- =============================================================================
CREATE OR REPLACE FUNCTION insert_rsvp_if_capacity(
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
  v_count integer;
  v_inserted boolean := false;
BEGIN
  SELECT s.max_players INTO v_max
  FROM sessions s
  WHERE s.id = p_session_id
  FOR UPDATE;

  IF v_max IS NULL THEN
    RAISE EXCEPTION 'session % not found', p_session_id;
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM rsvps r
  WHERE r.session_id = p_session_id;

  IF v_count < v_max THEN
    INSERT INTO rsvps (session_id, player_name, player_email, stripe_session_id)
    VALUES (p_session_id, p_player_name, p_player_email, p_stripe_session_id);
    v_inserted := true;
    v_count := v_count + 1;
  END IF;

  RETURN QUERY SELECT v_inserted, v_count, v_max;
END;
$$;

REVOKE EXECUTE ON FUNCTION insert_rsvp_if_capacity(uuid, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION insert_rsvp_if_capacity(uuid, text, text, text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION insert_rsvp_if_capacity(uuid, text, text, text) TO service_role;

-- =============================================================================
-- device_tokens: redundant permissive INSERT policy; tighter one already covers
-- the real caller.
-- =============================================================================
DROP POLICY IF EXISTS "Anyone can register token" ON device_tokens;
