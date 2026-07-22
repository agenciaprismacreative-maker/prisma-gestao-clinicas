-- ============================================================================
-- Migration 015: lote de pequenas melhorias — marca/descrição em produtos,
-- dados fiscais da clínica para o comprovante, e a base do módulo de custos
-- e folha (despesas fixas da clínica + salário por funcionário).
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.products
  add column if not exists brand text;
alter table public.products
  add column if not exists description text;

create index if not exists idx_products_brand on public.products (brand);

-- ============================================================================
-- Dados fiscais da clínica, usados no comprovante/recibo de venda em PDF
-- (razão social, CNPJ e endereço). Ficam em clinic_settings (1 linha por
-- clínica) por ser configuração administrativa, editável em Configurações.
-- ============================================================================
alter table public.clinic_settings
  add column if not exists legal_name text;
alter table public.clinic_settings
  add column if not exists cnpj text;
alter table public.clinic_settings
  add column if not exists company_address text;

-- ============================================================================
-- Módulo de custos e folha: salário por funcionário (para compor a folha de
-- pagamento) e despesas fixas/pontuais da clínica (aluguel, contas, etc.),
-- para alimentar o dashboard de custos, faturamento e lucro no BI.
-- ============================================================================
alter table public.users
  add column if not exists salary numeric(10, 2);

create table if not exists public.clinic_expenses (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  description text not null,
  category text not null default 'outros' check (
    category in ('aluguel', 'contas', 'marketing', 'manutencao', 'fornecedores', 'impostos', 'outros')
  ),
  amount numeric(10, 2) not null default 0,
  is_recurring boolean not null default false,
  expense_date date not null default current_date,
  notes text,
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_clinic_expenses_clinic on public.clinic_expenses (clinic_id);
create index if not exists idx_clinic_expenses_date on public.clinic_expenses (expense_date);

alter table public.clinic_expenses enable row level security;

drop policy if exists "clinic_expenses_all" on public.clinic_expenses;
create policy "clinic_expenses_all" on public.clinic_expenses for all
  using (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()))
  with check (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()));

grant select, insert, update, delete on public.clinic_expenses to authenticated;
