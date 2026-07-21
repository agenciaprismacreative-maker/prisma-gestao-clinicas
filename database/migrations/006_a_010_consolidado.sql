-- ============================================================================
-- Consolidado das migrations 006 a 010. Cole este arquivo inteiro no SQL
-- Editor do Supabase e rode de uma vez. É seguro rodar mais de uma vez
-- (todos os comandos usam "if not exists" / "drop ... if exists" antes de
-- criar de novo), e também é seguro mesmo que parte dele já tenha rodado
-- antes isoladamente.
-- ============================================================================

-- ============================================================================
-- 006: papéis (Esteticista / Atendente / Administrador) + trava de segurança
-- ============================================================================
update public.users set role = 'esteticista' where role = 'profissional';
update public.users set role = 'atendente' where role = 'recepcao';
update public.users set role = 'administrador' where role in ('gestor', 'financeiro');

alter table public.users drop constraint if exists users_role_check;
alter table public.users add constraint users_role_check check (
  role in ('esteticista', 'atendente', 'administrador', 'equipe_prisma')
);

create or replace function public.auth_is_admin()
returns boolean
language sql
security definer
stable
as $$
  select coalesce(
    (select role in ('administrador', 'equipe_prisma') from public.users where id = auth.uid()),
    false
  );
$$;

create or replace function public.protect_role_change()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.role is distinct from old.role then
    if not public.auth_is_admin() then
      raise exception 'Apenas administradores podem alterar o papel de um usuário.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_role_change on public.users;
create trigger trg_protect_role_change
before update on public.users
for each row execute function public.protect_role_change();

-- ============================================================================
-- 007: insumos vinculados a serviços + reagendamento
-- ============================================================================
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  name text not null,
  unit_cost numeric(10, 2),
  unit_of_measure text,
  barcode text,
  stock_quantity numeric(10, 2),
  created_at timestamptz not null default now()
);

create table if not exists public.service_products (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references public.services (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  quantity_used numeric(10, 3) not null default 1,
  created_at timestamptz not null default now()
);

create index if not exists idx_service_products_service on public.service_products (service_id);
create index if not exists idx_products_clinic on public.products (clinic_id);

alter table public.products enable row level security;
alter table public.service_products enable row level security;

drop policy if exists "products_all" on public.products;
create policy "products_all" on public.products for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

drop policy if exists "service_products_all" on public.service_products;
create policy "service_products_all" on public.service_products for all
  using (exists (
    select 1 from public.services s
    where s.id = service_products.service_id
      and (s.clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  ))
  with check (exists (
    select 1 from public.services s
    where s.id = service_products.service_id
      and (s.clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  ));

grant select, insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on public.service_products to authenticated;

alter table public.appointments
  add column if not exists rescheduled_count integer not null default 0;

-- ============================================================================
-- 008: valor total do pacote, comissão (percentual/base), metas por
-- profissional, indicação por integrante da equipe, maquininhas e
-- parcelamento
-- ============================================================================
alter table public.packages
  add column if not exists total_price numeric(10, 2);

alter table public.transactions
  add column if not exists commission_percentage numeric(5, 2);
alter table public.transactions
  add column if not exists base_amount numeric(10, 2);

alter table public.patients
  add column if not exists referred_by_user_id uuid references public.users (id) on delete set null;

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

-- ============================================================================
-- 009: Venda de Planos (carrinho com múltiplos serviços, aprovação)
-- ============================================================================
create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  status text not null default 'pendente' check (status in ('pendente', 'aprovada', 'cancelada')),
  origin text,
  validity_months integer,
  total_amount numeric(10, 2) not null default 0,
  payment_method text,
  installments integer not null default 1,
  payment_machine_id uuid references public.payment_machines (id) on delete set null,
  created_by uuid references public.users (id) on delete set null,
  approved_at timestamptz,
  approved_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales (id) on delete cascade,
  service_id uuid not null references public.services (id),
  quantity integer not null default 1,
  unit_price numeric(10, 2) not null default 0,
  discount_percentage numeric(5, 2) not null default 0,
  is_courtesy boolean not null default false,
  line_total numeric(10, 2) not null default 0,
  package_id uuid references public.packages (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_sales_clinic_status on public.sales (clinic_id, status);
create index if not exists idx_sales_patient on public.sales (patient_id);
create index if not exists idx_sale_items_sale on public.sale_items (sale_id);

alter table public.sales enable row level security;
alter table public.sale_items enable row level security;

drop policy if exists "sales_all" on public.sales;
create policy "sales_all" on public.sales for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

drop policy if exists "sale_items_all" on public.sale_items;
create policy "sale_items_all" on public.sale_items for all
  using (exists (
    select 1 from public.sales s
    where s.id = sale_items.sale_id
      and (s.clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  ))
  with check (exists (
    select 1 from public.sales s
    where s.id = sale_items.sale_id
      and (s.clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  ));

grant select, insert, update, delete on public.sales to authenticated;
grant select, insert, update, delete on public.sale_items to authenticated;

-- ============================================================================
-- 010: anotações manuais do dashboard
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
