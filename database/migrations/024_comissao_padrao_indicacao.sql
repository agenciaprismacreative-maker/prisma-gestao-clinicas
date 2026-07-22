-- ============================================================================
-- Migration 024: comissão padrão de indicação por funcionário. Definida pelo
-- administrador em Equipe (Gerenciamento), preenche automaticamente o campo
-- "Comissão da indicação (%)" em Vendas quando esse funcionário é escolhido
-- como quem indicou a venda, em vez de depender de digitação manual.
--
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.users add column if not exists default_referral_commission_percentage numeric(5, 2);
