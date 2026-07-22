-- ============================================================================
-- Consolidado 015 a 019: lote de melhorias — marca/descrição em produtos,
-- dados fiscais da clínica, módulo de custos e folha (despesas + salário),
-- faixas de comissão por atingimento de meta, motivo de cancelamento de
-- venda, função/status (ativo-inativo) do integrante da equipe, e motivo da
-- troca de profissional num remanejamento.
--
-- Junta as migrations 015, 016, 017, 018 e 019 num arquivo só, pra facilitar
-- rodar tudo de uma vez. Todas são idempotentes (seguro rodar mais de uma
-- vez, mesmo que alguma parte já tenha sido aplicada antes).
-- ============================================================================

-- ---------- 015: marca/descrição em produtos, dados fiscais, custos/folha ----------

-- ============================================================================
-- Migration 015: lote de pequenas melhorias — marca/descrição em produtos,
-- dados fiscais da clínica para o comprovante, e a base do módulo de custos
-- e folha (despesas fixas da clínica + salário por funcionário).
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.products
  add column if not exists brand text;
alter table public.products
  add column if not exists description text;

create index if not exists idx_products_brand on public.products (brand);

-- ============================================================================
-- Dados fiscais da clínica, usados no comprovante/recibo de venda em PDF
-- (razão social, CNPJ e endereço). Ficam em clinic_settings (1 linha por
-- clínica) por ser configuração administrativa, editável em Configurações.
-- ============================================================================
alter table public.clinic_settings
  add column if not exists legal_name text;
alter table public.clinic_settings
  add column if not exists cnpj text;
alter table public.clinic_settings
  add column if not exists company_address text;

-- ============================================================================
-- Módulo de custos e folha: salário por funcionário (para compor a folha de
-- pagamento) e despesas fixas/pontuais da clínica (aluguel, contas, etc.),
-- para alimentar o dashboard de custos, faturamento e lucro no BI.
-- ============================================================================
alter table public.users
  add column if not exists salary numeric(10, 2);

create table if not exists public.clinic_expenses (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  description text not null,
  category text not null default 'outros' check (
    category in ('aluguel', 'contas', 'marketing', 'manutencao', 'fornecedores', 'impostos', 'outros')
  ),
  amount numeric(10, 2) not null default 0,
  is_recurring boolean not null default false,
  expense_date date not null default current_date,
  notes text,
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_clinic_expenses_clinic on public.clinic_expenses (clinic_id);
create index if not exists idx_clinic_expenses_date on public.clinic_expenses (expense_date);

alter table public.clinic_expenses enable row level security;

drop policy if exists "clinic_expenses_all" on public.clinic_expenses;
create policy "clinic_expenses_all" on public.clinic_expenses for all
  using (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()))
  with check (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()));

grant select, insert, update, delete on public.clinic_expenses to authenticated;

-- ---------- 016: faixas de comissão por atingimento de meta ----------

-- ============================================================================
-- Migration 016: faixas de comissão por atingimento de meta (tiers).
-- Uma tabela de regras compartilhada pela clínica: "se atingiu X% da meta,
-- comissão é Y%". Usada no BI (aba Metas da equipe) para sugerir a comissão
-- de cada integrante com base no % de meta batido no mês.
-- Seguro rodar mais de uma vez.
-- ============================================================================

create table if not exists public.commission_tiers (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  min_achievement_pct numeric(6, 2) not null,
  commission_percentage numeric(5, 2) not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_commission_tiers_clinic on public.commission_tiers (clinic_id);

alter table public.commission_tiers enable row level security;

drop policy if exists "commission_tiers_select" on public.commission_tiers;
create policy "commission_tiers_select" on public.commission_tiers for select
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

drop policy if exists "commission_tiers_write" on public.commission_tiers;
create policy "commission_tiers_write" on public.commission_tiers for all
  using (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()))
  with check (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()));

grant select, insert, update, delete on public.commission_tiers to authenticated;

-- ---------- 017: motivo do cancelamento de uma venda ----------

-- ============================================================================
-- Migration 017: motivo do cancelamento de uma venda.
-- Guarda a descrição de por que uma venda pendente foi cancelada, exibida
-- depois na tela de Vendas ao abrir os detalhes de uma venda cancelada.
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.sales add column if not exists cancel_reason text;

-- ---------- 018: função (cargo) e status ativo/inativo do integrante ----------

-- ============================================================================
-- Migration 018: função (cargo) separada do papel de acesso, e status
-- ativo/inativo do integrante.
--
-- job_function guarda o cargo do dia a dia (esteticista/atendente),
-- independente de a pessoa também ter (ou não) acesso de administrador —
-- isso permite conceder/remover admin sem perder de vista qual é a função
-- real da pessoa na clínica.
--
-- is_active permite "remover" um integrante sem apagar o histórico dele
-- (vendas, comissões, atendimentos continuam intactos): a pessoa só deixa
-- de conseguir entrar no sistema.
--
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.users add column if not exists job_function text;
alter table public.users add column if not exists is_active boolean not null default true;

-- Preenche job_function para quem já existe, a partir do papel atual (só
-- faz sentido para quem não é administrador nem equipe_prisma).
update public.users
set job_function = role
where job_function is null and role in ('atendente', 'esteticista');

-- ---------- 019: motivo da troca de profissional num remanejamento ----------

-- ============================================================================
-- Migration 019: motivo da troca de profissional num remanejamento.
-- Quando um atendimento é remanejado e o profissional responsável muda
-- (não só o horário), guarda o motivo dessa troca, exibido futuramente no
-- histórico do agendamento/paciente.
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.appointments add column if not exists reassign_reason text;
