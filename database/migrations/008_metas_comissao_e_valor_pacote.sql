-- ============================================================================
-- Migration 008: valor total do pacote, comissão com percentual/base e
-- metas (goals) por profissional/mês, para a aba de desempenho da equipe.
-- Seguro rodar mais de uma vez.
-- ============================================================================

-- Valor total combinado na venda do pacote (pode diferir do preço unitário
-- do serviço x sessões, por causa de descontos).
alter table public.packages
  add column if not exists total_price numeric(10, 2);

-- Comissão: percentual aplicado e valor base sobre o qual foi calculado.
alter table public.transactions
  add column if not exists commission_percentage numeric(5, 2);
alter table public.transactions
  add column if not exists base_amount numeric(10, 2);

-- Indicação por um integrante da equipe (distinto de indicação por outro
-- paciente). Base para eventual bônus/comissão por captação, e para contar
-- indicações de novos clientes na aba de metas.
alter table public.patients
  add column if not exists referred_by_user_id uuid references public.users (id) on delete set null;

-- Metas por profissional (ou geral da clínica, quando professional_id é nulo)
create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  professional_id uuid references public.users (id) on delete cascade,
  period_month date not null,
  target_amount numeric(10, 2) not null,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_goals_clinic_period on public.goals (clinic_id, period_month);
create index if not exists idx_goals_professional on public.goals (professional_id);

alter table public.goals drop constraint if exists goals_unique_period;
alter table public.goals add constraint goals_unique_period unique (clinic_id, professional_id, period_month);

alter table public.goals enable row level security;

drop policy if exists "goals_select" on public.goals;
create policy "goals_select" on public.goals for select
  using (
    public.auth_is_prisma_team()
    or (
      clinic_id = public.auth_clinic_id()
      and (public.auth_is_admin() or professional_id = auth.uid() or professional_id is null)
    )
  );

drop policy if exists "goals_write" on public.goals;
create policy "goals_write" on public.goals for all
  using (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()))
  with check (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()));

grant select, insert, update, delete on public.goals to authenticated;

-- ============================================================================
-- Maquininhas de cartão (taxa por parcela) + parcelamento e pagamento
-- dividido em mais de uma forma de pagamento na mesma venda.
-- ============================================================================
create table if not exists public.payment_machines (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  name text not null,
  fee_rates jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_payment_machines_clinic on public.payment_machines (clinic_id);

alter table public.payment_machines enable row level security;

drop policy if exists "payment_machines_all" on public.payment_machines;
create policy "payment_machines_all" on public.payment_machines for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

grant select, insert, update, delete on public.payment_machines to authenticated;

alter table public.transactions
  add column if not exists installments integer not null default 1;
alter table public.transactions
  add column if not exists payment_machine_id uuid references public.payment_machines (id) on delete set null;
alter table public.transactions
  add column if not exists net_amount numeric(10, 2);
alter table public.transactions
  add column if not exists sale_group_id uuid;

create index if not exists idx_transactions_sale_group on public.transactions (sale_group_id);
