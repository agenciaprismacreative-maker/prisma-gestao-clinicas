-- ============================================================================
-- Migration 009: Venda de Planos — carrinho com múltiplos serviços por venda,
-- desconto por item e fluxo de aprovação (pendente -> aprovada/cancelada).
-- Só na aprovação (pagamento confirmado) é que a venda gera os pacotes de
-- sessão do paciente e o lançamento no financeiro, evitando "fuga de caixa".
-- Seguro rodar mais de uma vez.
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
