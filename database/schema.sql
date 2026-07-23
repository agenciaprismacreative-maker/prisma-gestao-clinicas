-- ============================================================================
-- Prisma · Sistema de Gestão para Clínicas de Estética
-- Schema completo do banco de dados (seção 4 da especificação)
-- Rodar uma única vez no SQL Editor do Supabase, no projeto já criado.
-- ============================================================================

create extension if not exists pgcrypto;

-- ============================================================================
-- 1. CLINICS
-- ============================================================================
create table public.clinics (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  cnpj text,
  address text,
  specialty text,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 2. USERS (perfil de negócio vinculado ao auth.users do Supabase)
-- ============================================================================
create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  clinic_id uuid references public.clinics (id) on delete set null,
  full_name text not null,
  email text,
  role text not null check (
    role in ('esteticista', 'atendente', 'administrador', 'equipe_prisma')
  ),
  job_function text,
  is_active boolean not null default true,
  professional_register text,
  specialties text,
  bio text,
  salary numeric(10, 2),
  default_referral_commission_percentage numeric(5, 2),
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 3. SERVICES (catálogo de procedimentos)
-- ============================================================================
create table public.services (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  name text not null,
  default_duration_minutes integer not null default 60,
  price numeric(10, 2),
  return_interval_days integer,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 4. PATIENTS
-- ============================================================================
create table public.patients (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  full_name text not null,
  cpf text,
  phone text,
  email text,
  birth_date date,
  anamnesis text,
  anamnesis_answers jsonb not null default '{}'::jsonb,
  allergies text,
  lgpd_consent_at timestamptz,
  lgpd_consent_text text,

  -- documentos
  rg text,
  rg_orgao_emissor text,
  rg_data_emissao date,

  -- contato expandido
  phone2 text,
  landline text,
  instagram text,
  facebook text,

  -- endereço
  address_cep text,
  address_street text,
  address_number text,
  address_neighborhood text,
  address_complement text,
  address_city text,
  address_state text,

  -- origem do lead / indicação
  lead_source text,
  referred_by_patient_id uuid references public.patients (id) on delete set null,
  referred_by_name text,
  referred_by_user_id uuid references public.users (id) on delete set null,

  -- responsável legal (paciente menor de idade ou dependente)
  legal_guardian_name text,
  legal_guardian_cpf text,
  legal_guardian_notes text,

  -- dados complementares
  naturality text,
  father_name text,
  mother_name text,
  profession text,
  workplace text,
  record_number text,
  gender text,
  marital_status text,
  blood_type text,
  client_type text default 'particular',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- 5. PACKAGES (pacotes de sessões pré-pagos)
-- ============================================================================
create table public.packages (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  service_id uuid references public.services (id),
  total_sessions integer not null,
  used_sessions integer not null default 0,
  total_price numeric(10, 2),
  purchased_at date not null default current_date,
  expires_at date,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 6. APPOINTMENTS
-- ============================================================================
create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  professional_id uuid references public.users (id),
  service_id uuid references public.services (id),
  package_id uuid references public.packages (id),
  scheduled_at timestamptz not null,
  duration_minutes integer not null default 60,
  status text not null default 'agendado' check (
    status in ('agendado', 'confirmado', 'em_atendimento', 'concluido', 'faltou', 'cancelado')
  ),
  cancel_reason text,
  reassign_reason text,
  room_or_equipment text,
  rescheduled_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- 7. MEDICAL_RECORDS (evolução clínica por sessão)
-- ============================================================================
create table public.medical_records (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  appointment_id uuid references public.appointments (id) on delete set null,
  patient_id uuid not null references public.patients (id) on delete cascade,
  professional_id uuid references public.users (id),
  protocol text,
  notes text,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 8. PATIENT_PHOTOS (fotos de evolução)
-- ============================================================================
create table public.patient_photos (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  session_date date not null default current_date,
  storage_path text not null,
  marketing_consent boolean not null default false,
  appointment_id uuid references public.appointments (id) on delete set null,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 9. TASKS (tarefas internas da equipe)
-- ============================================================================
create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  assigned_to uuid references public.users (id),
  title text not null,
  description text,
  due_date timestamptz,
  status text not null default 'pendente' check (
    status in ('pendente', 'em_andamento', 'concluida')
  ),
  patient_id uuid references public.patients (id),
  appointment_id uuid references public.appointments (id),
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 10. TRANSACTIONS (financeiro)
-- ============================================================================
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  patient_id uuid references public.patients (id),
  appointment_id uuid references public.appointments (id),
  package_id uuid references public.packages (id),
  professional_id uuid references public.users (id),
  type text not null check (
    type in ('pagamento_procedimento', 'venda_pacote', 'comissao_profissional')
  ),
  amount numeric(10, 2) not null,
  commission_percentage numeric(5, 2),
  base_amount numeric(10, 2),
  payment_method text,
  installments integer not null default 1,
  payment_machine_id uuid,
  net_amount numeric(10, 2),
  sale_group_id uuid,
  gateway_provider text,
  gateway_transaction_id text,
  transaction_date date not null default current_date,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 11. LEADS (captação, pré-paciente)
-- ============================================================================
create table public.leads (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  name text,
  phone text,
  source_campaign text,
  source_channel text,
  source_creative text,
  funnel_status text not null default 'novo' check (
    funnel_status in ('novo', 'em_conversa', 'agendado', 'convertido', 'perdido')
  ),
  notes text,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 12. COMMUNICATIONS_LOG (histórico de mensagens WhatsApp)
-- ============================================================================
create table public.communications_log (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  patient_id uuid references public.patients (id),
  appointment_id uuid references public.appointments (id),
  channel text not null default 'whatsapp',
  message_type text check (
    message_type in ('confirmacao', 'lembrete', 'reativacao', 'pesquisa_satisfacao')
  ),
  direction text not null check (direction in ('enviada', 'recebida')),
  content text,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 13. SCHEDULE_BLOCKS (bloqueios de agenda: feriado, folga, manutenção etc.)
-- ============================================================================
create table public.schedule_blocks (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  professional_id uuid references public.users (id) on delete cascade,
  start_at timestamptz not null,
  end_at timestamptz not null,
  reason text,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 14. PRODUCTS (insumos / matéria-prima, base de precificação dos serviços)
-- ============================================================================
create table public.products (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  name text not null,
  unit_cost numeric(10, 2),
  unit_of_measure text,
  barcode text,
  stock_quantity numeric(10, 2),
  min_stock_quantity numeric(10, 2),
  max_stock_quantity numeric(10, 2),
  product_type text not null default 'insumo' check (product_type in ('insumo', 'revenda')),
  sale_price numeric(10, 2),
  expiry_date date,
  brand text,
  description text,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 15. SERVICE_PRODUCTS (insumos consumidos por serviço, com quantidade)
-- ============================================================================
create table public.service_products (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references public.services (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  quantity_used numeric(10, 3) not null default 1,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 15.1 STOCK_MOVEMENTS (histórico de entradas, saídas e ajustes de estoque;
-- saídas por atendimento são geradas automaticamente ao concluir um
-- atendimento vinculado a um serviço com insumos cadastrados)
-- ============================================================================
create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  movement_type text not null check (movement_type in ('entrada', 'saida', 'ajuste')),
  quantity numeric(10, 3) not null,
  unit_cost numeric(10, 2),
  reason text,
  appointment_id uuid references public.appointments (id) on delete set null,
  sale_id uuid references public.sales (id) on delete set null,
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 16. GOALS (metas por profissional/mês, ou geral da clínica quando
-- professional_id é nulo — alimenta a aba de desempenho da equipe no BI)
-- ============================================================================
create table public.goals (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  professional_id uuid references public.users (id) on delete cascade,
  period_month date not null,
  target_amount numeric(10, 2) not null,
  notes text,
  created_at timestamptz not null default now()
);

-- meta coletiva/por unidade: totalmente independente de goals (individual)
-- acima, nunca somada nem misturada com ela. Uma linha por clínica por mês.
create table public.collective_goals (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  period_month date not null,
  target_amount numeric(10, 2) not null,
  created_at timestamptz not null default now(),
  unique (clinic_id, period_month)
);

-- ============================================================================
-- 17. PAYMENT_MACHINES (maquininhas de cartão, com taxa por parcela)
-- ============================================================================
create table public.payment_machines (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  name text not null,
  fee_rates jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.transactions
  add constraint transactions_payment_machine_fk foreign key (payment_machine_id)
  references public.payment_machines (id) on delete set null;

-- ============================================================================
-- 18. SALES (venda de planos: carrinho com múltiplos serviços por venda,
-- fluxo pendente -> aprovada/cancelada. Só a aprovação gera pacotes de
-- sessão e lançamento financeiro, evitando "fuga de caixa")
-- ============================================================================
create table public.sales (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  status text not null default 'pendente' check (status in ('pendente', 'aprovada', 'cancelada')),
  cancel_reason text,
  origin text,
  validity_months integer,
  discount_percentage numeric(5, 2) not null default 0,
  total_amount numeric(10, 2) not null default 0,
  payment_method text,
  installments integer not null default 1,
  payment_machine_id uuid references public.payment_machines (id) on delete set null,
  payment_lines jsonb,
  referred_by_patient_id uuid references public.patients (id) on delete set null,
  referred_by_user_id uuid references public.users (id) on delete set null,
  referral_commission_percentage numeric(5, 2),
  created_by uuid references public.users (id) on delete set null,
  approved_at timestamptz,
  approved_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 19. SALE_ITEMS (linhas da venda: um serviço, quantidade de sessões e
-- desconto por linha; package_id é preenchido quando a venda é aprovada)
-- ============================================================================
create table public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales (id) on delete cascade,
  service_id uuid references public.services (id),
  product_id uuid references public.products (id) on delete restrict,
  quantity integer not null default 1,
  unit_price numeric(10, 2) not null default 0,
  discount_percentage numeric(5, 2) not null default 0,
  is_courtesy boolean not null default false,
  line_total numeric(10, 2) not null default 0,
  package_id uuid references public.packages (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint sale_items_service_or_product_check check (
    (service_id is not null and product_id is null) or
    (service_id is null and product_id is not null)
  )
);

-- ============================================================================
-- 20. DASHBOARD_NOTES (anotações manuais / post-its da clínica; podem ser
-- públicas para a clínica inteira ou direcionadas a um funcionário)
-- ============================================================================
create table public.dashboard_notes (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  author_id uuid references public.users (id) on delete set null,
  target_user_id uuid references public.users (id) on delete cascade,
  content text not null,
  dismissed_at timestamptz,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 21. PLAN_TEMPLATES / PLAN_TEMPLATE_ITEMS (modelos de pacote reutilizáveis:
-- descrevem o que um pacote oferece, sem preço nem pagamento — isso só
-- existe na venda em si, montada em cima de um modelo ou do zero)
-- ============================================================================
create table public.plan_templates (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

create table public.plan_template_items (
  id uuid primary key default gen_random_uuid(),
  plan_template_id uuid not null references public.plan_templates (id) on delete cascade,
  service_id uuid not null references public.services (id),
  quantity integer not null default 1,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 22. CLINIC_SETTINGS (aba Configurações: identidade visual, tema, regras de
-- agendamento, senha do gerente e permissão de visualização do desempenho)
-- ============================================================================
create table public.clinic_settings (
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
  manager_password_for_performance boolean not null default false,
  primary_color text,
  accent_color text,
  max_discount_percentage numeric(5, 2),
  legal_name text,
  cnpj text,
  company_address text,
  address_cep text,
  enable_individual_goal boolean not null default true,
  enable_collective_goal boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- CLINIC_EXPENSES (custos e folha): despesas fixas/pontuais da clínica
-- (aluguel, contas, etc.). O salário de cada funcionário fica em users.salary
-- e é somado à parte, sem duplicar aqui.
-- ============================================================================
create table public.clinic_expenses (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  description text not null,
  category text not null default 'outros' check (
    category in ('aluguel', 'contas', 'marketing', 'manutencao', 'fornecedores', 'impostos', 'outros')
  ),
  amount numeric(10, 2) not null default 0,
  is_recurring boolean not null default false,
  duration_months integer,
  expense_date date not null default current_date,
  notes text,
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- COMMISSION_TIERS (faixas de comissão por atingimento de meta, ex.: 100% da
-- meta = 5%, 120% = 7%, 150% = 10%). Compartilhada pela clínica inteira.
-- ============================================================================
create table public.commission_tiers (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  min_achievement_pct numeric(6, 2) not null,
  commission_percentage numeric(5, 2) not null,
  goal_scope text not null default 'individual' check (goal_scope in ('individual', 'coletiva')),
  created_at timestamptz not null default now()
);

-- ============================================================================
-- ÍNDICES (consultas mais comuns: por clínica e por data)
-- ============================================================================
create index idx_patients_clinic on public.patients (clinic_id);
create index idx_appointments_clinic_date on public.appointments (clinic_id, scheduled_at);
create index idx_appointments_patient on public.appointments (patient_id);
create index idx_tasks_clinic_status on public.tasks (clinic_id, status);
create index idx_transactions_clinic_date on public.transactions (clinic_id, transaction_date);
create index idx_leads_clinic_status on public.leads (clinic_id, funnel_status);
create index idx_communications_patient on public.communications_log (patient_id);
create index idx_schedule_blocks_clinic_date on public.schedule_blocks (clinic_id, start_at);
create index idx_service_products_service on public.service_products (service_id);
create index idx_products_clinic on public.products (clinic_id);
create index idx_products_brand on public.products (brand);
create index idx_clinic_expenses_clinic on public.clinic_expenses (clinic_id);
create index idx_clinic_expenses_date on public.clinic_expenses (expense_date);
create index idx_commission_tiers_clinic on public.commission_tiers (clinic_id);
create index idx_stock_movements_product on public.stock_movements (product_id);
create index idx_stock_movements_clinic on public.stock_movements (clinic_id);
create index idx_stock_movements_created_at on public.stock_movements (created_at);
create index idx_stock_movements_sale on public.stock_movements (sale_id);
create index idx_patient_photos_appointment on public.patient_photos (appointment_id);
create index idx_goals_clinic_period on public.goals (clinic_id, period_month);
create index idx_goals_professional on public.goals (professional_id);
alter table public.goals add constraint goals_unique_period unique (clinic_id, professional_id, period_month);
create index idx_payment_machines_clinic on public.payment_machines (clinic_id);
create index idx_transactions_sale_group on public.transactions (sale_group_id);
create index idx_sales_clinic_status on public.sales (clinic_id, status);
create index idx_sales_patient on public.sales (patient_id);
create index idx_sale_items_sale on public.sale_items (sale_id);
create index idx_sale_items_product on public.sale_items (product_id);
create index idx_dashboard_notes_clinic on public.dashboard_notes (clinic_id, created_at);
create index idx_dashboard_notes_target on public.dashboard_notes (target_user_id);
create index idx_sales_referred_patient on public.sales (referred_by_patient_id);
create index idx_sales_referred_user on public.sales (referred_by_user_id);
create index idx_plan_templates_clinic on public.plan_templates (clinic_id);
create index idx_plan_template_items_template on public.plan_template_items (plan_template_id);
create unique index idx_clinic_settings_clinic on public.clinic_settings (clinic_id);

-- ============================================================================
-- FUNÇÕES AUXILIARES PARA AS POLÍTICAS DE RLS
-- ============================================================================
create or replace function public.auth_clinic_id()
returns uuid
language sql
security definer
stable
as $$
  select clinic_id from public.users where id = auth.uid();
$$;

create or replace function public.auth_is_prisma_team()
returns boolean
language sql
security definer
stable
as $$
  select coalesce(
    (select role = 'equipe_prisma' from public.users where id = auth.uid()),
    false
  );
$$;

-- Confirma se quem está logado é Administrador (ou equipe Prisma). Usada
-- para restringir quem pode alterar o papel de outro usuário.
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

-- Bloqueia qualquer UPDATE que mude a coluna role, a menos que quem faça a
-- alteração seja administrador/equipe Prisma (mesmo contornando a tela).
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

-- ============================================================================
-- ROW LEVEL SECURITY
-- Regra geral: cada usuário só vê e edita dados da própria clínica.
-- A equipe Prisma (role = 'equipe_prisma') enxerga o consolidado de todas.
-- ============================================================================
alter table public.clinics enable row level security;
alter table public.users enable row level security;
alter table public.services enable row level security;
alter table public.patients enable row level security;
alter table public.packages enable row level security;
alter table public.appointments enable row level security;
alter table public.medical_records enable row level security;
alter table public.patient_photos enable row level security;
alter table public.tasks enable row level security;
alter table public.transactions enable row level security;
alter table public.leads enable row level security;
alter table public.communications_log enable row level security;
alter table public.schedule_blocks enable row level security;
alter table public.products enable row level security;
alter table public.service_products enable row level security;
alter table public.stock_movements enable row level security;
alter table public.goals enable row level security;
alter table public.collective_goals enable row level security;
alter table public.payment_machines enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.dashboard_notes enable row level security;
alter table public.plan_templates enable row level security;
alter table public.plan_template_items enable row level security;
alter table public.clinic_settings enable row level security;

-- clinics: qualquer usuário autenticado enxerga apenas a própria clínica
create policy "clinics_select" on public.clinics for select
  using (id = public.auth_clinic_id() or public.auth_is_prisma_team());

-- clinics: só administrador da própria clínica edita os dados dela
-- (nome, etc.). Sem essa policy o update roda sem erro e sem efeito, porque
-- a checagem de RLS descarta a linha antes de gravar.
create policy "clinics_update" on public.clinics for update
  using (id = public.auth_clinic_id() and public.auth_is_admin())
  with check (id = public.auth_clinic_id() and public.auth_is_admin());

-- users: cada usuário vê os colegas da própria clínica
create policy "users_select" on public.users for select
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

-- users: vincular (insert) e editar (update) integrantes da própria clínica
create policy "users_insert" on public.users for insert
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "users_update" on public.users for update
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create trigger trg_protect_role_change
before update on public.users
for each row execute function public.protect_role_change();

-- Bloco repetido para as tabelas operacionais: select, insert, update, delete
-- restritos à clínica do usuário autenticado, com acesso total para a equipe Prisma.

create policy "services_all" on public.services for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "patients_all" on public.patients for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "packages_all" on public.packages for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "appointments_all" on public.appointments for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "medical_records_all" on public.medical_records for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "patient_photos_all" on public.patient_photos for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "tasks_all" on public.tasks for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "transactions_all" on public.transactions for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "leads_all" on public.leads for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "communications_log_all" on public.communications_log for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "schedule_blocks_all" on public.schedule_blocks for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "products_all" on public.products for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

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

create policy "stock_movements_all" on public.stock_movements for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

-- goals: leitura liberada para o próprio profissional (ou metas gerais da
-- clínica, quando professional_id é nulo); escrita (criar/editar/remover)
-- restrita a administradores.
create policy "goals_select" on public.goals for select
  using (
    public.auth_is_prisma_team()
    or (
      clinic_id = public.auth_clinic_id()
      and (public.auth_is_admin() or professional_id = auth.uid() or professional_id is null)
    )
  );

create policy "goals_write" on public.goals for all
  using (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()))
  with check (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()));

create policy "collective_goals_select" on public.collective_goals for select
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "collective_goals_write" on public.collective_goals for all
  using (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()))
  with check (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()));

create policy "payment_machines_all" on public.payment_machines for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "sales_all" on public.sales for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

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

create policy "dashboard_notes_all" on public.dashboard_notes for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "plan_templates_all" on public.plan_templates for all
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

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

-- clinic_settings: qualquer integrante da clínica lê (a agenda e o tema
-- dependem disso para todo mundo), só administrador escreve.
create policy "clinic_settings_select" on public.clinic_settings for select
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "clinic_settings_write" on public.clinic_settings for all
  using (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()))
  with check (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()));

-- clinic_expenses: só administrador (ou equipe Prisma) lê e escreve —
-- despesas e folha são informação financeira sensível.
alter table public.clinic_expenses enable row level security;

create policy "clinic_expenses_all" on public.clinic_expenses for all
  using (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()))
  with check (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()));

-- commission_tiers: só administrador (ou equipe Prisma) lê e escreve.
alter table public.commission_tiers enable row level security;

create policy "commission_tiers_select" on public.commission_tiers for select
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "commission_tiers_write" on public.commission_tiers for all
  using (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()))
  with check (public.auth_is_prisma_team() or (clinic_id = public.auth_clinic_id() and public.auth_is_admin()));

-- ============================================================================
-- STORAGE: bucket para fotos de evolução dos pacientes
-- ============================================================================
insert into storage.buckets (id, name, public)
values ('patient-photos', 'patient-photos', false)
on conflict (id) do nothing;

create policy "patient_photos_storage_select" on storage.objects for select
  using (bucket_id = 'patient-photos' and auth.role() = 'authenticated');

create policy "patient_photos_storage_insert" on storage.objects for insert
  with check (bucket_id = 'patient-photos' and auth.role() = 'authenticated');

-- ============================================================================
-- STORAGE: bucket público para logo e outros assets visuais da clínica
-- ============================================================================
insert into storage.buckets (id, name, public)
values ('clinic-assets', 'clinic-assets', true)
on conflict (id) do nothing;

create policy "clinic_assets_storage_select" on storage.objects for select
  using (bucket_id = 'clinic-assets');

create policy "clinic_assets_storage_insert" on storage.objects for insert
  with check (bucket_id = 'clinic-assets' and auth.role() = 'authenticated');

create policy "clinic_assets_storage_update" on storage.objects for update
  using (bucket_id = 'clinic-assets' and auth.role() = 'authenticated');

-- ============================================================================
-- Fim do schema. Próximo passo: criar a clínica e o primeiro usuário de teste
-- (arquivo database/seed.sql), depois conectar o front-end com a Project URL
-- e a anon key deste projeto.
-- ============================================================================
