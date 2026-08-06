-- 028: restringe o acesso entre clínicas da equipe Prisma a dados de
-- paciente/saúde (LGPD) e adiciona um jeito seguro de comparar faturamento
-- entre clínicas sem expor dado nenhum de paciente.
--
-- Contexto: auth_is_prisma_team() dava à equipe_prisma acesso de leitura E
-- escrita a TODAS as clínicas, em TODAS as tabelas, sem distinção. Isso
-- nasceu como um atalho de suporte, mas não tem sentido do ponto de vista da
-- LGPD: a Prisma administra o ACESSO das clínicas à plataforma (contas,
-- login, plano, cobrança), não deveria enxergar ficha de paciente, prontuário,
-- foto de evolução, agenda, vendas ou histórico financeiro de clínica
-- nenhuma. Dado de saúde é dado sensível (LGPD art. 5º, II) e o acesso tem
-- que ser o mínimo necessário para a finalidade (princípio da necessidade,
-- art. 6º, III).
--
-- Este arquivo remove "or auth_is_prisma_team()" só das tabelas que guardam
-- dado de paciente/saúde/financeiro-por-paciente. Tabelas de configuração e
-- conta (clinics, users, services, products, clinic_settings, metas,
-- despesas, etc.) continuam com acesso da Prisma, porque isso é exatamente
-- o que o painel administrativo precisa para gerenciar acesso e assinatura.
--
-- Em vez de acesso direto aos dados, quem precisar comparar desempenho entre
-- clínicas usa prisma_clinic_revenue_ranking(): uma function que devolve só
-- o total somado por clínica no mês, nunca uma linha de transação ou
-- qualquer coisa vinculada a paciente.

-- ----------------------------------------------------------------------------
-- 1. Tabelas de paciente/saúde/financeiro-por-paciente: remove o acesso
--    entre clínicas da equipe Prisma. Continuam 100% funcionais para cada
--    clínica ver e editar os próprios dados -- só o "ou é da equipe Prisma"
--    sai da regra.
-- ----------------------------------------------------------------------------
drop policy if exists "patients_all" on public.patients;
create policy "patients_all" on public.patients for all
  using (clinic_id = public.auth_clinic_id())
  with check (clinic_id = public.auth_clinic_id());

drop policy if exists "medical_records_all" on public.medical_records;
create policy "medical_records_all" on public.medical_records for all
  using (clinic_id = public.auth_clinic_id())
  with check (clinic_id = public.auth_clinic_id());

drop policy if exists "patient_photos_all" on public.patient_photos;
create policy "patient_photos_all" on public.patient_photos for all
  using (clinic_id = public.auth_clinic_id())
  with check (clinic_id = public.auth_clinic_id());

drop policy if exists "appointments_all" on public.appointments;
create policy "appointments_all" on public.appointments for all
  using (clinic_id = public.auth_clinic_id())
  with check (clinic_id = public.auth_clinic_id());

drop policy if exists "packages_all" on public.packages;
create policy "packages_all" on public.packages for all
  using (clinic_id = public.auth_clinic_id())
  with check (clinic_id = public.auth_clinic_id());

drop policy if exists "sales_all" on public.sales;
create policy "sales_all" on public.sales for all
  using (clinic_id = public.auth_clinic_id())
  with check (clinic_id = public.auth_clinic_id());

drop policy if exists "sale_items_all" on public.sale_items;
create policy "sale_items_all" on public.sale_items for all
  using (exists (
    select 1 from public.sales s
    where s.id = sale_items.sale_id and s.clinic_id = public.auth_clinic_id()
  ))
  with check (exists (
    select 1 from public.sales s
    where s.id = sale_items.sale_id and s.clinic_id = public.auth_clinic_id()
  ));

drop policy if exists "transactions_all" on public.transactions;
create policy "transactions_all" on public.transactions for all
  using (clinic_id = public.auth_clinic_id())
  with check (clinic_id = public.auth_clinic_id());

drop policy if exists "leads_all" on public.leads;
create policy "leads_all" on public.leads for all
  using (clinic_id = public.auth_clinic_id())
  with check (clinic_id = public.auth_clinic_id());

drop policy if exists "communications_log_all" on public.communications_log;
create policy "communications_log_all" on public.communications_log for all
  using (clinic_id = public.auth_clinic_id())
  with check (clinic_id = public.auth_clinic_id());

drop policy if exists "dashboard_notes_all" on public.dashboard_notes;
create policy "dashboard_notes_all" on public.dashboard_notes for all
  using (clinic_id = public.auth_clinic_id())
  with check (clinic_id = public.auth_clinic_id());

-- ----------------------------------------------------------------------------
-- 2. Ranking de faturamento entre clínicas, sem expor dado de paciente.
--    Function em vez de tabela/view: roda com privilégio elevado (security
--    definer) só para SOMAR transactions.amount por clínica, e nunca
--    devolve uma linha individual. Continua checando explicitamente que
--    quem chama é da equipe Prisma -- não é a policy de RLS de transactions
--    (que acabou de ficar restrita) que protege isso, é a checagem abaixo.
-- ----------------------------------------------------------------------------
create or replace function public.prisma_clinic_revenue_ranking(period_month text)
returns table (clinic_id uuid, clinic_name text, total_revenue numeric)
language plpgsql
security definer
stable
as $$
begin
  if not public.auth_is_prisma_team() then
    raise exception 'not authorized';
  end if;

  return query
    select c.id, c.name, coalesce(sum(t.amount), 0)::numeric
    from public.clinics c
    left join public.transactions t
      on t.clinic_id = c.id
      and t.type in ('pagamento_procedimento', 'venda_pacote')
      and t.transaction_date is not null
      and to_char(t.transaction_date::date, 'YYYY-MM') = period_month
    where c.status <> 'cancelado'
    group by c.id, c.name
    order by 3 desc;
end;
$$;

grant execute on function public.prisma_clinic_revenue_ranking(text) to authenticated;

-- ----------------------------------------------------------------------------
-- 3. Registro de "parabéns" enviados, só para não mandar duas vezes no
--    mesmo mês e para ter histórico de relacionamento com o cliente.
-- ----------------------------------------------------------------------------
create table if not exists public.clinic_shoutouts (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  period_month text not null,
  rank int,
  channel text,
  message text,
  sent_by uuid references public.users (id) on delete set null,
  sent_at timestamptz not null default now()
);

comment on table public.clinic_shoutouts is 'Histórico de mensagens de parabéns/reconhecimento enviadas pela Prisma às clínicas que se destacaram em faturamento no mês.';

alter table public.clinic_shoutouts enable row level security;

create policy "clinic_shoutouts_all" on public.clinic_shoutouts for all
  using (public.auth_is_prisma_team())
  with check (public.auth_is_prisma_team());

grant select, insert on public.clinic_shoutouts to authenticated;
