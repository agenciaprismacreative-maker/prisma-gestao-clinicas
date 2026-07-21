-- ============================================================================
-- Migration 003: bloqueios de agenda (feriados, folgas, manutenção de sala etc.)
-- Usado pelo menu de contexto (clique direito) da agenda: "Bloquear horário"
-- e "Gerenciar bloqueios".
-- ============================================================================

create table public.schedule_blocks (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  professional_id uuid references public.users (id) on delete cascade,
  start_at timestamptz not null,
  end_at timestamptz not null,
  reason text,
  created_at timestamptz not null default now()
);

create index idx_schedule_blocks_clinic_date on public.schedule_blocks (clinic_id, start_at);

alter table public.schedule_blocks enable row level security;

create policy "schedule_blocks_all" on public.schedule_blocks for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

-- Tabelas criadas via SQL Editor não recebem GRANT automático para o role
-- authenticated (só RLS não é suficiente, como já visto em bugs anteriores).
grant select, insert, update, delete on public.schedule_blocks to authenticated;
