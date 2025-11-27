-- 002_indexes.sql
-- Indexes to speed up frequent lookups, sorting, and filtering.

-- Sessions
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON public.sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON public.sessions(status);
CREATE INDEX IF NOT EXISTS idx_sessions_created_at ON public.sessions(created_at);
CREATE INDEX IF NOT EXISTS idx_sessions_last_active ON public.sessions(last_active);

-- Chat messages
CREATE INDEX IF NOT EXISTS idx_chat_messages_session_id_created_at
  ON public.chat_messages(session_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON public.chat_messages(sender);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages(created_at);

-- Prompts
CREATE INDEX IF NOT EXISTS idx_prompts_session_id_created_at
  ON public.prompts(session_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_prompts_user_id ON public.prompts(user_id);
CREATE INDEX IF NOT EXISTS idx_prompts_created_at ON public.prompts(created_at);
CREATE INDEX IF NOT EXISTS idx_prompts_parsed_intent_gin ON public.prompts USING GIN (parsed_intent);

-- Wireframes
CREATE INDEX IF NOT EXISTS idx_wireframes_session_id_created_at
  ON public.wireframes(session_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wireframes_user_id ON public.wireframes(user_id);
CREATE INDEX IF NOT EXISTS idx_wireframes_created_at ON public.wireframes(created_at);
CREATE INDEX IF NOT EXISTS idx_wireframes_components_gin ON public.wireframes USING GIN (components);
CREATE INDEX IF NOT EXISTS idx_wireframes_layout_gin ON public.wireframes USING GIN (layout);

-- Audit logs
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id_created_at
  ON public.audit_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_operation ON public.audit_logs(operation);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at);
