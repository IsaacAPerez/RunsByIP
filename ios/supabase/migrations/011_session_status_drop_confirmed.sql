-- Session workflow uses only `open` and `cancelled`. Legacy `confirmed` rows
-- behave like `open` in app logic; normalize them for a single source of truth.
UPDATE public.sessions
SET status = 'open'
WHERE status = 'confirmed';
