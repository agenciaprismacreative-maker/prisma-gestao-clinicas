-- ============================================================================
-- Migration 012: módulo de Estoque completo.
-- Adiciona limites de mínimo/máximo aos insumos (public.products, já
-- existente) e cria o histórico de movimentações (entradas, saídas e
-- ajustes), incluindo o consumo automático gerado ao concluir um
-- atendimento vinculado a um serviço com insumos cadastrados.
-- Seguro rodar mais de uma vez.
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
