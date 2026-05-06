-- Move RunsByIP session pricing to $12 / 1200 cents.
-- Checkout reads public.sessions.price_cents, so keep both existing open runs
-- and the database default aligned with the new price.

UPDATE public.sessions
SET price_cents = 1200
WHERE status = 'open'
  AND price_cents <> 1200;

ALTER TABLE public.sessions
  ALTER COLUMN price_cents SET DEFAULT 1200;
