-- ============================================================================
-- 034: catálogo de planos, central de avisos e trilha de auditoria
-- Painel interno da Prisma -- módulos derivados da análise do documento
-- Prisma-CRM-Manual-Administração.pdf (ver analise-modelo-operacional-painel-prisma.md).
-- A visão global de usuários não precisa de tabela nova, é só uma consulta
-- em public.users já existente.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Catálogo de planos
-- clinics.plan_name/plan_value continuam sendo o valor efetivamente cobrado
-- (permite personalizar preço por clínica). plan_id é uma referência opcional
-- a partir de qual plano do catálogo aquele valor foi originado -- usado só
-- como atalho de preenchimento no painel, não como fonte única de verdade.
-- ----------------------------------------------------------------------------
create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price numeric(10, 2),
  billing_cycle text not null default 'mensal' check (billing_cycle in ('mensal', 'anual')),
  description text,
  features text[] not null default '{}',
  is_active boolean not null default true,
  display_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.clinics
  add column if not exists plan_id uuid references public.plans (id) on delete set null;

alter table public.plans enable row level security;

drop policy if exists plans_prisma_all on public.plans;
create policy plans_prisma_all on public.plans
  for all
  using (public.auth_is_prisma_team())
  with check (public.auth_is_prisma_team());

-- ----------------------------------------------------------------------------
-- 2. Central de avisos
-- Campanhas publicadas pela Prisma e exibidas no sino de lembretes de cada
-- clínica (js/topbar.js). target_status vazio/nulo = todas as clínicas.
-- Renderizadas sempre como texto puro (x-text), nunca innerHTML -- ver seção
-- 4 da análise anexa sobre o XSS armazenado do sistema de referência.
-- ----------------------------------------------------------------------------
create table if not exists public.admin_notices (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  message text not null,
  severity text not null default 'info' check (severity in ('info', 'warning', 'urgent')),
  target_status text[] not null default '{}',
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_notice_dismissals (
  notice_id uuid not null references public.admin_notices (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  dismissed_at timestamptz not null default now(),
  primary key (notice_id, user_id)
);

alter table public.admin_notices enable row level security;
alter table public.admin_notice_dismissals enable row level security;

drop policy if exists admin_notices_prisma_all on public.admin_notices;
create policy admin_notices_prisma_all on public.admin_notices
  for all
  using (public.auth_is_prisma_team())
  with check (public.auth_is_prisma_team());

-- Qualquer usuário autenticado (lado da clínica) só enxerga avisos ativos --
-- é o que alimenta o sino de lembretes em todas as páginas.
drop policy if exists admin_notices_read_active on public.admin_notices;
create policy admin_notices_read_active on public.admin_notices
  for select
  to authenticated
  using (is_active = true);

drop policy if exists admin_notice_dismissals_own on public.admin_notice_dismissals;
create policy admin_notice_dismissals_own on public.admin_notice_dismissals
  for all
  using (user_id = auth.uid() or public.auth_is_prisma_team())
  with check (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 3. Trilha de auditoria
-- Somente inserção e leitura -- nenhuma policy de update/delete, log é
-- append-only por desenho. Cobre as ações administrativas sensíveis do
-- painel Prisma: mudança de status/plano de clínica, pagamento manual,
-- ativação/desativação de acesso, redefinição de senha, e as mutações do
-- catálogo de planos e da central de avisos.
-- ----------------------------------------------------------------------------
create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.users (id) on delete set null,
  actor_name text,
  action text not null,
  target_type text not null,
  target_id uuid,
  target_label text,
  details jsonb,
  created_at timestamptz not null default now()
);

alter table public.admin_audit_log enable row level security;

drop policy if exists admin_audit_log_prisma_read on public.admin_audit_log;
create policy admin_audit_log_prisma_read on public.admin_audit_log
  for select
  using (public.auth_is_prisma_team());

drop policy if exists admin_audit_log_prisma_insert on public.admin_audit_log;
create policy admin_audit_log_prisma_insert on public.admin_audit_log
  for insert
  with check (public.auth_is_prisma_team());

create index if not exists idx_admin_audit_log_created_at on public.admin_audit_log (created_at desc);
create index if not exists idx_admin_notices_active on public.admin_notices (is_active);
