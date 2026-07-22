-- ============================================================================
-- Migration 019: motivo da troca de profissional num remanejamento.
-- Quando um atendimento é remanejado e o profissional responsável muda
-- (não só o horário), guarda o motivo dessa troca, exibido futuramente no
-- histórico do agendamento/paciente.
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.appointments add column if not exists reassign_reason text;
