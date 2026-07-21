-- ============================================================================
-- Migration 007: insumos vinculados a serviços (para precificação) e
-- rastreio de reagendamento por agendamento. Seguro rodar mais de uma vez.
-- ============================================================================

-- Insumos / matéria-prima da clínica
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

-- Relação N:N: quais insumos (e em que quantidade) um serviço consome
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

-- Reagendamento: conta quantas vezes um agendamento teve o horário alterado
alter table public.appointments
  add column if not exists rescheduled_count integer not null default 0;
