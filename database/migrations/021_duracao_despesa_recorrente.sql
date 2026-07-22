-- ============================================================================
-- Migration 021: duração (em meses) de uma despesa recorrente.
--
-- Até aqui, marcar uma despesa como recorrente era só um rótulo na lista:
-- ela nunca entrava sozinha nos meses seguintes, só no mês exato em que foi
-- cadastrada (bug de origem, não intencional). duration_months corrige isso
-- e de quebra permite dar um prazo à recorrência (ex.: financiamento de
-- equipamento em 12x): a despesa passa a contar todo mês a partir de
-- expense_date e para de contar sozinha depois de duration_months meses.
-- Deixar em branco (null) mantém a recorrência sem data de término, como
-- aluguel.
--
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.clinic_expenses add column if not exists duration_months integer;
