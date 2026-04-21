-- RSVPs only exist after Stripe confirms payment. No more pending/cash/waitlist.
-- The stripe-webhook function is the sole creator of rsvp rows.

-- Clean up abandoned pending rows (any pre-existing non-paid state).
DELETE FROM rsvps WHERE payment_status IN ('pending', 'waitlist');

-- Drop the now-unused public_rsvps view so we can drop the column it depends on.
DROP VIEW IF EXISTS public_rsvps;

-- The webhook used to UPDATE pending → paid. With paid-only it just INSERTs,
-- so UPDATE policies are dead weight.
DROP POLICY IF EXISTS "Service role can update rsvps" ON rsvps;
DROP POLICY IF EXISTS "Admin can update rsvps" ON rsvps;

ALTER TABLE rsvps DROP COLUMN payment_status;

-- Idempotency guard: if Stripe retries a webhook for an already-written RSVP,
-- the INSERT hits this constraint and we treat it as success.
ALTER TABLE rsvps
  ADD CONSTRAINT rsvps_stripe_session_id_key UNIQUE (stripe_session_id);
