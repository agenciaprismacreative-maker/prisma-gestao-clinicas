-- ============================================================================
-- Migration 011: desconto e forma de pagamento combinada em vendas.sales,
-- indicação (paciente ou funcionário) com comissão automática, modelos de
-- pacote reutilizáveis (Financeiro > Cadastrar pacotes) e anotações do
-- dashboard direcionáveis a um funcionário específico.
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.sales
  add column if not exists discount_percentage numeric(5, 2) not null default 0;
alter table public.sales
  add column if not exists payment_lines jsonb;
alter table public.sales
  add column if not exists referred_by_patient_id uuid references public.patients (id) on delete set null;
alter table public.sales
  add column if not exists referred_by_user_id uuid references public.users (id) on delete set null;
alter table public.sales
  add column if not exists referral_commission_percentage numeric(5, 2);

create index if not exists idx_sales_referred_patient on public.sales (referred_by_patient_id);
create index if not exists idx_sales_referred_user on public.sales (referred_by_user_id);

-- ============================================================================
-- Modelos de pacote (Financeiro > Cadastrar pacotes): descrevem o que um
-- pacote oferece (serviços + quantidades) para reuso rápido na Nova Venda.
-- Não têm preço nem forma de pagamento — isso só existe na venda em si.
-- ============================================================================
create table if not exists public.plan_templates (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.plan_template_items (
  id uuid primary key default gen_random_uuid(),
  plan_template_id uuid not null references public.plan_templates (id) on delete cascade,
  service_id uuid not null references public.services (id),
  quantity integer not null default 1,
  created_at timestamptz not null default now()
);

create index if not exists idx_plan_templates_clinic on public.plan_templates (clinic_id);
create index if not exists idx_plan_template_items_template on public.plan_template_items (plan_template_id);

alter table public.plan_templates enable row level security;
alter table public.plan_template_items enable row level security;

drop policy if exists "plan_templates_all" on public.plan_templates;
create policy "plan_templates_all" on public.plan_templates for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

drop policy if exists "plan_template_items_all" on public.plan_template_items;
create policy "plan_template_items_all" on public.plan_template_items for all
  using (exists (
    select 1 from public.plan_templates t
    where t.id = plan_template_items.plan_template_id
      and (t.clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  ))
  with check (exists (
    select 1 from public.plan_templates t
    where t.id = plan_template_items.plan_template_id
      and (t.clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  ));

grant select, insert, update, delete on public.plan_templates to authenticated;
grant select, insert, update, delete on public.plan_template_items to authenticated;

-- ============================================================================
-- Anotações do dashboard: agora podem ser públicas (target_user_id nulo,
-- todo mundo vê) ou direcionadas a um funcionário específico.
-- ============================================================================
alter table public.dashboard_notes
  add column if not exists target_user_id uuid references public.users (id) on delete cascade;

create index if not exists idx_dashboard_notes_target on public.dashboard_notes (target_user_id);

-- ============================================================================
-- Configurações da clínica (aba Configurações): identidade visual, tema,
-- regras de agendamento, senha do gerente e permissão de visualização do
-- desempenho pela equipe. Uma linha por clínica.
-- ============================================================================
create table if not exists public.clinic_settings (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null unique references public.clinics (id) on delete cascade,
  logo_url text,
  theme text not null default 'claro' check (theme in ('claro', 'escuro')),
  prevent_double_booking boolean not null default true,
  agenda_name_format text not null default 'completo' check (agenda_name_format in ('completo', 'primeiro', 'nome_sobrenome')),
  manager_password text,
  manager_password_for_discount boolean not null default false,
  manager_password_for_courtesy boolean not null default false,
  show_performance_to_staff boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.clinic_settings enable row level security;

drop policy if exists "clinic_settings_select" on public.clinic_settings;
create policy "clinic_settings_select" on public.clinic_settings for select
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

drop policy if exists "clinic_settings_write" on public.clinic_settings;
create policy "clinic_settings_write" on public.clinic_settings for all
  using (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()))
  with check (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()));

grant select, insert, update, delete on public.clinic_settings to authenticated;

insert into storage.buckets (id, name, public)
values ('clinic-assets', 'clinic-assets', true)
on conflict (id) do nothing;

drop policy if exists "clinic_assets_storage_select" on storage.objects;
create policy "clinic_assets_storage_select" on storage.objects for select
  using (bucket_id = 'clinic-assets');

drop policy if exists "clinic_assets_storage_insert" on storage.objects;
create policy "clinic_assets_storage_insert" on storage.objects for insert
  with check (bucket_id = 'clinic-assets' and auth.role() = 'authenticated');

drop policy if exists "clinic_assets_storage_update" on storage.objects;
create policy "clinic_assets_storage_update" on storage.objects for update
  using (bucket_id = 'clinic-assets' and auth.role() = 'authenticated');
