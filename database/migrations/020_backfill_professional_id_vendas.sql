-- ============================================================================
-- Migration 020: conserta vendas aprovadas ANTES da correção que passou a
-- gravar o profissional responsável (professional_id) no lançamento
-- financeiro de uma venda.
--
-- Até essa correção, toda venda aprovada gerava o lançamento em
-- transactions sem professional_id — por isso nenhuma venda, de ninguém,
-- nunca contava pra meta, ranking ou comissão de quem vendeu. A correção em
-- si só vale pra vendas aprovadas dali pra frente; esta migration conserta
-- retroativamente as que já foram aprovadas antes.
--
-- transactions.sale_group_id é sempre igual ao id da venda em sales (ver
-- vendas.html, approveSale()), o que permite recuperar quem criou a venda
-- (sales.created_by) e preencher o professional_id que ficou nulo.
--
-- Seguro rodar mais de uma vez: só atualiza linhas com professional_id
-- ainda nulo.
-- ============================================================================

update public.transactions t
set professional_id = s.created_by
from public.sales s
where t.sale_group_id = s.id
  and t.type = 'venda_pacote'
  and t.professional_id is null
  and s.created_by is not null;
