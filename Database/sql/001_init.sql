-- 001_init.sql
-- Initial schema for Proto Assistant PostgreSQL
-- Creates: users, sessions, chat_messages, prompts, wireframes, audit_logs
-- Safe to run multiple times with IF NOT EXISTS guards.

-- USERS
CREATE TABLE IF NOT EXISTS public.users (
  id           BIGSERIAL PRIMARY KEY,
  username     VARCHAR(64) NOT NULL UNIQUE,
  email        VARCHAR(255) NOT NULL UNIQUE,
  role         VARCHAR(32) NOT NULL DEFAULT 'user',
  password_hash TEXT, -- optional: BackendAPI should handle hashing
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- SESSIONS
CREATE TABLE IF NOT EXISTS public.sessions (
  session_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status       VARCHAR(32) NOT NULL DEFAULT 'active', -- active, expired, terminated, logged_out
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_active  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at   TIMESTAMPTZ
);

-- CHAT MESSAGES
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id           BIGSERIAL PRIMARY KEY,
  session_id   UUID NOT NULL REFERENCES public.sessions(session_id) ON DELETE CASCADE,
  sender       VARCHAR(32) NOT NULL, -- user, agent, system
  content      TEXT NOT NULL,
  status       VARCHAR(32) NOT NULL DEFAULT 'sent', -- sent, received, error
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- PROMPTS
CREATE TABLE IF NOT EXISTS public.prompts (
  id            BIGSERIAL PRIMARY KEY,
  session_id    UUID NOT NULL REFERENCES public.sessions(session_id) ON DELETE CASCADE,
  user_id       BIGINT REFERENCES public.users(id) ON DELETE SET NULL,
  user_input    TEXT NOT NULL,
  parsed_intent JSONB, -- optional canonicalized intent
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- WIREFRAMES
CREATE TABLE IF NOT EXISTS public.wireframes (
  id            BIGSERIAL PRIMARY KEY,
  session_id    UUID NOT NULL REFERENCES public.sessions(session_id) ON DELETE CASCADE,
  user_id       BIGINT REFERENCES public.users(id) ON DELETE SET NULL,
  components    JSONB NOT NULL DEFAULT '[]'::jsonb,
  layout        JSONB NOT NULL DEFAULT '{}'::jsonb,
  export_options JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- AUDIT LOGS
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT REFERENCES public.users(id) ON DELETE SET NULL,
  operation  VARCHAR(64) NOT NULL,
  details    JSONB NOT NULL DEFAULT '{}'::jsonb,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Helpful extension for UUID if missing (ignore error if not available)
DO $$
BEGIN
  -- Enable pgcrypto for gen_random_uuid if it's present
  PERFORM 1 FROM pg_extension WHERE extname = 'pgcrypto';
  IF NOT FOUND THEN
    BEGIN
      CREATE EXTENSION IF NOT EXISTS pgcrypto;
    EXCEPTION WHEN OTHERS THEN
      -- ignore - environment may not permit CREATE EXTENSION
      NULL;
    END;
  END IF;
END$$;

-- Triggers to auto-update updated_at on users
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_users_set_updated_at'
  ) THEN
    CREATE TRIGGER trg_users_set_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END$$;
