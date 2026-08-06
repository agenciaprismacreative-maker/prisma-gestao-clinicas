-- 027: painel administrativo da Prisma (visão da agência sobre as clínicas
-- clientes da plataforma)
--
-- Até aqui, "clinics" só guardava dados da própria clínica (nome, CNPJ,
-- endereço). Não existia lugar nenhum para a Prisma controlar o ciclo de
-- vida comercial de cada cliente da plataforma: em qual plano está, se está
-- em dia, quando vence a próxima cobrança, se é um trial, etc. Também não
-- existia como alguém pedir acesso à plataforma sem já ter uma conta -- toda
-- clínica precisava ser criada manualmente direto no banco.
--
-- Este arquivo adiciona:
--   1. Colunas de ciclo de vida/assinatura em clinics.
--   2. clinic_payments: ficha (ledger) manual de pagamentos por clínica --
--      controlada pela Prisma, não é uma cobrança automática (não há
--      integração com gateway de pagamento ainda; isso é o registro do que
--      já foi combinado/recebido, para acompanhar inadimplência).
--   3. clinic_signup_requests: pedidos de acesso vindos da página pública
--      solicitar-acesso.html, com ou sem login por Google já feito.
--   4. Corrige clinics_update (faltava considerar equipe_prisma) e cria
--      clinics_insert (não existia -- só a Prisma pode criar clínica nova).
--
-- auth_is_prisma_team() já existe desde o schema original e já é usada em
-- praticamente todas as outras tabelas para dar à equipe_prisma acesso de
-- suporte entre clínicas; aqui só estendemos a mesma regra para as tabelas
-- e colunas novas.

-- ----------------------------------------------------------------------------
-- 1. Ciclo de vida e assinatura em clinics
-- ----------------------------------------------------------------------------
alter table public.clinics
  add column if not exists status text not null default 'trial'
    check (status in ('trial', 'ativo', 'inadimplente', 'suspenso', 'cancelado')),
  add column if not exists plan_name text,
  add column if not exists plan_value numeric(10, 2),
  add column if not exists billing_cycle text default 'mensal'
    check (billing_cycle in ('mensal', 'anual')),
  add column if not exists trial_ends_at timestamptz,
  add column if not exists next_due_date date,
  add column if not exists activated_at timestamptz,
  add column if not exists owner_name text,
  add column if not exists owner_email text,
  add column if not exists owner_phone text,
  add column if not exists notes text;

comment on column public.clinics.status is 'Ciclo de vida comercial: trial, ativo, inadimplente, suspenso ou cancelado. Controlado manualmente pela Prisma no painel administrativo.';
comment on column public.clinics.notes is 'Anotações internas da Prisma sobre o relacionamento com o cliente (não visível para a clínica).';

-- ----------------------------------------------------------------------------
-- 2. clinic_payments: ficha manual de pagamentos por clínica
-- ----------------------------------------------------------------------------
create table if not exists public.clinic_payments (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  amount numeric(10, 2) not null,
  due_date date,
  paid_at timestamptz,
  status text not null default 'pendente'
    check (status in ('pago', 'pendente', 'atrasado', 'cancelado')),
  payment_method text,
  reference text,
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

comment on table public.clinic_payments is 'Ledger manual de pagamentos das clínicas (assinatura da plataforma), controlado pela equipe Prisma. Não é cobrança automática -- é o registro do que foi combinado/recebido.';

alter table public.clinic_payments enable row level security;

-- só a equipe Prisma opera essa tabela; é o controle interno de cobrança da
-- agência, a clínica-cliente não deve ver isso pela própria conta.
create policy "clinic_payments_all" on public.clinic_payments for all
  using (public.auth_is_prisma_team())
  with check (public.auth_is_prisma_team());

grant select, insert, update, delete on public.clinic_payments to authenticated;

-- ----------------------------------------------------------------------------
-- 3. clinic_signup_requests: pedidos de acesso (público, sem login)
-- ----------------------------------------------------------------------------
create table if not exists public.clinic_signup_requests (
  id uuid primary key default gen_random_uuid(),
  clinic_name text not null,
  contact_name text not null,
  contact_email text not null,
  contact_phone text,
  specialty text,
  message text,
  -- preenchido quando o pedido chega via "Continuar com Google": já existe
  -- uma conta em auth.users esperando a Prisma aprovar e vincular a uma
  -- clínica. Nulo quando o pedido veio só do formulário (sem login).
  requester_auth_user_id uuid references auth.users (id) on delete set null,
  status text not null default 'pendente'
    check (status in ('pendente', 'aprovado', 'recusado')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.users (id) on delete set null,
  review_notes text,
  resulting_clinic_id uuid references public.clinics (id) on delete set null
);

comment on table public.clinic_signup_requests is 'Pedidos de acesso enviados pela página pública solicitar-acesso.html. A Prisma revisa e aprova (cria a clínica) ou recusa pelo painel administrativo.';

alter table public.clinic_signup_requests enable row level security;

-- Inserção pública: qualquer visitante (mesmo sem login, papel "anon") pode
-- enviar um pedido. Não é possível ler os pedidos dos outros -- só inserir o
-- próprio. Isso é o único ponto de todo o sistema que aceita escrita sem
-- autenticação, por natureza (é a porta de entrada de quem ainda não é
-- cliente).
create policy "clinic_signup_requests_insert_public" on public.clinic_signup_requests for insert
  to anon, authenticated
  with check (true);

-- Um visitante que acabou de fazer login com Google pode ver o status do
-- próprio pedido (para a tela de "aguardando aprovação" funcionar depois de
-- um refresh), mas não os pedidos de outras pessoas.
create policy "clinic_signup_requests_select_own" on public.clinic_signup_requests for select
  using (
    public.auth_is_prisma_team()
    or (requester_auth_user_id is not null and requester_auth_user_id = auth.uid())
  );

create policy "clinic_signup_requests_update_prisma" on public.clinic_signup_requests for update
  using (public.auth_is_prisma_team())
  with check (public.auth_is_prisma_team());

grant select, insert, update on public.clinic_signup_requests to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 4. clinics: corrigir UPDATE e criar INSERT para a equipe Prisma
-- ----------------------------------------------------------------------------
drop policy if exists "clinics_update" on public.clinics;
create policy "clinics_update" on public.clinics for update
  using ((id = public.auth_clinic_id() and public.auth_is_admin()) or public.auth_is_prisma_team())
  with check ((id = public.auth_clinic_id() and public.auth_is_admin()) or public.auth_is_prisma_team());

-- Criar clínica nova é uma ação exclusiva da Prisma (onboarding de cliente),
-- nunca de um administrador de clínica sobre a própria conta.
create policy "clinics_insert" on public.clinics for insert
  with check (public.auth_is_prisma_team());
