-- Expose the database-backed session price default to clients.
-- The source of truth remains public.sessions.price_cents DEFAULT; this RPC
-- lets admin clients prefill creation forms without hardcoded dollar amounts.

CREATE OR REPLACE FUNCTION public.default_session_price_cents()
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_price_cents integer;
BEGIN
  SELECT (pg_get_expr(d.adbin, d.adrelid))::integer
  INTO v_price_cents
  FROM pg_attribute a
  JOIN pg_class c ON c.oid = a.attrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
  WHERE n.nspname = 'public'
    AND c.relname = 'sessions'
    AND a.attname = 'price_cents'
    AND NOT a.attisdropped;

  IF v_price_cents IS NULL THEN
    RAISE EXCEPTION 'public.sessions.price_cents default is not configured';
  END IF;

  RETURN v_price_cents;
END;
$$;

COMMENT ON FUNCTION public.default_session_price_cents()
  IS 'Returns the public.sessions.price_cents column default; use as the Supabase-backed admin creation default.';

REVOKE ALL ON FUNCTION public.default_session_price_cents() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.default_session_price_cents() TO anon, authenticated, service_role;
