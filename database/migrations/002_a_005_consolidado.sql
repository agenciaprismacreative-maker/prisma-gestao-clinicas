-- ============================================================================
-- Rodar no SQL Editor do Supabase. Seguro rodar mais de uma vez (idempotente):
-- cada comando primeiro remove/verifica o que já existe antes de recriar.
-- ============================================================================

-- 002: corrige o erro "new row violates row-level security policy for table users"
drop policy if exists "users_insert" on public.users;
create policy "users_insert" on public.users for insert
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

drop policy if exists "users_update" on public.users;
create policy "users_update" on public.users for update
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

-- 003: bloqueios de agenda
create table if not exists public.schedule_blocks (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  professional_id uuid references public.users (id) on delete cascade,
  start_at timestamptz not null,
  end_at timestamptz not null,
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists idx_schedule_blocks_clinic_date on public.schedule_blocks (clinic_id, start_at);

alter table public.schedule_blocks enable row level security;

drop policy if exists "schedule_blocks_all" on public.schedule_blocks;
create policy "schedule_blocks_all" on public.schedule_blocks for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

grant select, insert, update, delete on public.schedule_blocks to authenticated;

-- 004: ficha de paciente completa
alter table public.patients
  add column if not exists rg text,
  add column if not exists rg_orgao_emissor text,
  add column if not exists rg_data_emissao date,
  add column if not exists phone2 text,
  add column if not exists landline text,
  add column if not exists instagram text,
  add column if not exists facebook text,
  add column if not exists address_cep text,
  add column if not exists address_street text,
  add column if not exists address_number text,
  add column if not exists address_neighborhood text,
  add column if not exists address_complement text,
  add column if not exists address_city text,
  add column if not exists address_state text,
  add column if not exists lead_source text,
  add column if not exists referred_by_patient_id uuid references public.patients (id) on delete set null,
  add column if not exists referred_by_name text,
  add column if not exists legal_guardian_name text,
  add column if not exists legal_guardian_cpf text,
  add column if not exists legal_guardian_notes text,
  add column if not exists naturality text,
  add column if not exists father_name text,
  add column if not exists mother_name text,
  add column if not exists profession text,
  add column if not exists workplace text,
  add column if not exists record_number text,
  add column if not exists gender text,
  add column if not exists marital_status text,
  add column if not exists blood_type text,
  add column if not exists client_type text default 'particular';

-- 005: qualificação profissional da equipe
alter table public.users
  add column if not exists professional_register text,
  add column if not exists specialties text,
  add column if not exists bio text;
