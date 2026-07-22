-- ============================================================================
-- Migration 023: permite marcar uma anotação direcionada (lembrete no sino)
-- como concluída/dispensada, sem apagar a anotação em si (ela continua
-- existindo no histórico do dashboard, só some do sino de lembretes de quem
-- já resolveu).
--
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.dashboard_notes add column if not exists dismissed_at timestamptz;
