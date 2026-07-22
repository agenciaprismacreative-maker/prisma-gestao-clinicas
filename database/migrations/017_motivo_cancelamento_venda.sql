-- ============================================================================
-- Migration 017: motivo do cancelamento de uma venda.
-- Guarda a descrição de por que uma venda pendente foi cancelada, exibida
-- depois na tela de Vendas ao abrir os detalhes de uma venda cancelada.
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.sales add column if not exists cancel_reason text;
