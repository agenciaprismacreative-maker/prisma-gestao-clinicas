-- ============================================================================
-- Migration 005: qualificação profissional dos integrantes da equipe
-- (registro profissional, especialidades e biografia/qualificação descritiva).
-- ============================================================================

alter table public.users
  add column if not exists professional_register text,
  add column if not exists specialties text,
  add column if not exists bio text;
