-- ============================================================================
-- Consolidado 011 a 014: junta as 4 migrations pendentes num arquivo só, para
-- rodar de uma vez só no SQL Editor do Supabase. Todas as instruções são
-- idempotentes (if not exists / drop ... if exists antes de recriar), então
-- é seguro rodar mesmo que uma dessas 4 já tenha sido aplicada antes.
--
-- Contém, em ordem:
--   011 · desconto e forma de pagamento combinada em vendas, indicação com
--        comissão automática, modelos de pacote reutilizáveis, anotações do
--        dashboard direcionáveis e tabela clinic_settings (Configurações).
--   012 · módulo de Estoque: min/max de insumos + histórico de movimentações.
--   013 · senha do gerente para o Desempenho, cores da marca e limite de
--        desconto em clinic_settings, e vínculo de foto ao atendimento.
--   014 · separação de Insumos e Produtos de revenda, validade para alertas
--        de vencimento, e vendas com itens de produto além de serviço.
-- ============================================================================


-- ============================================================================
-- 011 · vendas, indicação, pacotes, modelo de notas
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

alter table public.dashboard_notes
  add column if not exists target_user_id uuid references public.users (id) on delete cascade;

create index if not exists idx_dashboard_notes_target on public.dashboard_notes (target_user_id);

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


-- ============================================================================
-- 012 · módulo de Estoque (min/max + stock_movements)
-- ============================================================================

alter table public.products
  add column if not exists min_stock_quantity numeric(10, 2);
alter table public.products
  add column if not exists max_stock_quantity numeric(10, 2);

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  movement_type text not null check (movement_type in ('entrada', 'saida', 'ajuste')),
  quantity numeric(10, 3) not null,
  unit_cost numeric(10, 2),
  reason text,
  appointment_id uuid references public.appointments (id) on delete set null,
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_stock_movements_product on public.stock_movements (product_id);
create index if not exists idx_stock_movements_clinic on public.stock_movements (clinic_id);
create index if not exists idx_stock_movements_created_at on public.stock_movements (created_at);

alter table public.stock_movements enable row level security;

drop policy if exists "stock_movements_all" on public.stock_movements;
create policy "stock_movements_all" on public.stock_movements for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

grant select, insert, update, delete on public.stock_movements to authenticated;


-- ============================================================================
-- 013 · senha do gerente p/ Desempenho, cores da marca, limite de desconto
-- ============================================================================

alter table public.clinic_settings
  add column if not exists manager_password_for_performance boolean not null default false;
alter table public.clinic_settings
  add column if not exists primary_color text;
alter table public.clinic_settings
  add column if not exists accent_color text;
alter table public.clinic_settings
  add column if not exists max_discount_percentage numeric(5, 2);

alter table public.patient_photos
  add column if not exists appointment_id uuid references public.appointments (id) on delete set null;

create index if not exists idx_patient_photos_appointment on public.patient_photos (appointment_id);


-- ============================================================================
-- 014 · Insumos x Produtos de revenda, validade, vendas com itens de produto
-- ============================================================================

alter table public.products
  add column if not exists product_type text not null default 'insumo' check (product_type in ('insumo', 'revenda'));
alter table public.products
  add column if not exists sale_price numeric(10, 2);
alter table public.products
  add column if not exists expiry_date date;

alter table public.sale_items alter column service_id drop not null;
alter table public.sale_items
  add column if not exists product_id uuid references public.products (id) on delete restrict;

alter table public.sale_items drop constraint if exists sale_items_service_or_product_check;
alter table public.sale_items
  add constraint sale_items_service_or_product_check
  check (
    (service_id is not null and product_id is null) or
    (service_id is null and product_id is not null)
  );

create index if not exists idx_sale_items_product on public.sale_items (product_id);

alter table public.stock_movements
  add column if not exists sale_id uuid references public.sales (id) on delete set null;

create index if not exists idx_stock_movements_sale on public.stock_movements (sale_id);
