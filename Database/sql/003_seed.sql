-- 003_seed.sql
-- Optional seed data for local development. Safe to re-run (conditional inserts).

-- Seed users
INSERT INTO public.users (username, email, role)
SELECT 'demo', 'demo@example.com', 'user'
WHERE NOT EXISTS (SELECT 1 FROM public.users WHERE username = 'demo');

INSERT INTO public.users (username, email, role)
SELECT 'admin', 'admin@example.com', 'admin'
WHERE NOT EXISTS (SELECT 1 FROM public.users WHERE username = 'admin');

-- Create a demo session for 'demo' user
WITH u AS (
  SELECT id FROM public.users WHERE username = 'demo' LIMIT 1
), s AS (
  SELECT session_id FROM public.sessions WHERE user_id = (SELECT id FROM u) LIMIT 1
)
INSERT INTO public.sessions (user_id, status)
SELECT (SELECT id FROM u), 'active'
WHERE NOT EXISTS (SELECT 1 FROM s);

-- Create a prompt and a wireframe linked to the session
WITH sess AS (
  SELECT session_id, user_id
  FROM public.sessions
  WHERE user_id = (SELECT id FROM public.users WHERE username = 'demo')
  ORDER BY created_at DESC
  LIMIT 1
)
INSERT INTO public.prompts (session_id, user_id, user_input, parsed_intent)
SELECT session_id, user_id,
       'Create a dashboard with a table and a filter form',
       '{"intents":[{"type":"dashboard"},{"type":"table"},{"type":"form"}]}'
FROM sess
WHERE NOT EXISTS (
  SELECT 1 FROM public.prompts p WHERE p.session_id = (SELECT session_id FROM sess)
);

WITH sess AS (
  SELECT session_id, user_id
  FROM public.sessions
  WHERE user_id = (SELECT id FROM public.users WHERE username = 'demo')
  ORDER BY created_at DESC
  LIMIT 1
)
INSERT INTO public.wireframes (session_id, user_id, components, layout, export_options)
SELECT session_id, user_id,
       '[{"type":"table","props":{"rows":10}},{"type":"form","props":{"fields":3}}]'::jsonb,
       '{"layout":"two-column"}'::jsonb,
       '{"theme":"light"}'::jsonb
FROM sess
WHERE NOT EXISTS (
  SELECT 1 FROM public.wireframes w WHERE w.session_id = (SELECT session_id FROM sess)
);

-- Minimal audit log
INSERT INTO public.audit_logs (user_id, operation, details)
SELECT id, 'seed', '{"message":"Initial seed executed"}'
FROM public.users WHERE username = 'admin'
ON CONFLICT DO NOTHING;
