-- ============================================================================
-- Migration 010: anotações manuais do dashboard (bloco de post-its da
-- clínica). Seguro rodar mais de uma vez.
-- ============================================================================

create table if not exists public.dashboard_notes (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  author_id uuid references public.users (id) on delete set null,
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_dashboard_notes_clinic on public.dashboard_notes (clinic_id, created_at);

alter table public.dashboard_notes enable row level security;

drop policy if exists "dashboard_notes_all" on public.dashboard_notes;
create policy "dashboard_notes_all" on public.dashboard_notes for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

grant select, insert, update, delete on public.dashboard_notes to authenticated;
