-- ============================================================================
-- Migration 025: metas independentes (individual x coletiva/por unidade).
--
-- A meta individual já existia (tabela goals, uma linha por profissional por
-- mês). Esta migration cria a trilha coletiva como algo totalmente separado:
-- nunca somada nem misturada com a individual, com sua própria tabela
-- (collective_goals, uma linha por clínica por mês) e sua própria faixa de
-- comissão (goal_scope em commission_tiers). clinic_settings ganha os dois
-- interruptores que ligam/desligam cada trilha independentemente.
--
-- Seguro rodar mais de uma vez.
-- ============================================================================

create table if not exists public.collective_goals (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  period_month date not null,
  target_amount numeric(10, 2) not null,
  created_at timestamptz not null default now(),
  unique (clinic_id, period_month)
);

alter table public.collective_goals enable row level security;

drop policy if exists "collective_goals_select" on public.collective_goals;
create policy "collective_goals_select" on public.collective_goals for select
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

drop policy if exists "collective_goals_write" on public.collective_goals;
create policy "collective_goals_write" on public.collective_goals for all
  using (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()))
  with check (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()));

alter table public.commission_tiers add column if not exists goal_scope text not null default 'individual';
alter table public.commission_tiers drop constraint if exists commission_tiers_goal_scope_check;
alter table public.commission_tiers add constraint commission_tiers_goal_scope_check check (goal_scope in ('individual', 'coletiva'));

alter table public.clinic_settings add column if not exists enable_individual_goal boolean not null default true;
alter table public.clinic_settings add column if not exists enable_collective_goal boolean not null default false;
