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
