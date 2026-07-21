-- ============================================================================
-- Prisma · Migration 001: ficha de paciente completa
-- Adiciona CPF e anamnese estruturada (perguntas de sim/não com detalhe),
-- mantendo a coluna "anamnesis" já existente como observações livres
-- complementares. Rodar uma vez no SQL Editor, depois do schema.sql.
-- ============================================================================

alter table public.patients
  add column if not exists cpf text,
  add column if not exists anamnesis_answers jsonb not null default '{}'::jsonb;
