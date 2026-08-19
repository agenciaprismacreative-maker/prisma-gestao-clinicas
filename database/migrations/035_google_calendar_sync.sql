-- ============================================================================
-- 035: GOOGLE CALENDAR SYNC (mão única: Prisma -> Google, por profissional)
-- ============================================================================
-- Cada profissional (esteticista/atendente/administrador) pode conectar a
-- própria conta Google. A partir daí, todo agendamento criado/remarcado/
-- cancelado na Agenda da Prisma é refletido no Google Calendar dele. O
-- sentido é único: mudanças feitas direto no Google não voltam pra Prisma.
--
-- O refresh_token fica isolado em calendar_tokens, tabela sem NENHUMA
-- policy de SELECT -- nem o próprio dono consegue ler de volta pelo client.
-- Só a Edge Function (service role, ignora RLS) lê de fato, na hora de
-- sincronizar. O client só insere (ao conectar) e apaga (ao desconectar).
-- ============================================================================

alter table public.appointments
  add column if not exists google_event_id text;

comment on column public.appointments.google_event_id is
  'id do evento correspondente no Google Calendar do profissional (quando ele tem sincronização ativa). Null = nunca sincronizado ou profissional sem conexão.';

-- Metadados da conexão: visíveis (não sensíveis). O token em si NÃO mora
-- aqui -- ver calendar_tokens abaixo.
create table public.calendar_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users (id) on delete cascade,
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  google_email text,
  google_calendar_id text not null default 'primary',
  sync_enabled boolean not null default true,
  connected_at timestamptz not null default now(),
  last_synced_at timestamptz,
  last_sync_error text
);

comment on table public.calendar_connections is
  'Conexão de cada profissional com o próprio Google Calendar. Sincronização de mão única: Prisma -> Google.';

-- Só o refresh_token, isolado numa tabela à parte, sem policy de select
-- para authenticated/anon -- só o service role (dentro da Edge Function)
-- consegue ler. O client só grava (insert/update) e apaga (delete) o
-- próprio; nunca lê de volta.
create table public.calendar_tokens (
  user_id uuid primary key references public.users (id) on delete cascade,
  refresh_token text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.calendar_tokens is
  'Refresh tokens do Google Calendar. Sem policy de SELECT para nenhum papel do client -- só o service role (Edge Function) lê. Existe separada de calendar_connections propositalmente, para que um vazamento de leitura de uma nunca exponha a outra.';

alter table public.calendar_connections enable row level security;
alter table public.calendar_tokens enable row level security;

-- calendar_connections: o próprio profissional, a administração da mesma
-- clínica e a equipe Prisma podem ver que a conexão existe (e-mail
-- conectado, data, status). Só o próprio dono (ou equipe Prisma, suporte)
-- grava/apaga.
create policy "calendar_connections_select" on public.calendar_connections for select
  using (
    user_id = auth.uid()
    or auth_is_prisma_team()
    or (auth_is_admin() and clinic_id = auth_clinic_id())
  );

create policy "calendar_connections_insert" on public.calendar_connections for insert
  with check (user_id = auth.uid() or auth_is_prisma_team());

create policy "calendar_connections_update" on public.calendar_connections for update
  using (user_id = auth.uid() or auth_is_prisma_team());

create policy "calendar_connections_delete" on public.calendar_connections for delete
  using (user_id = auth.uid() or auth_is_prisma_team());

-- calendar_tokens: nenhuma policy de select (nem para o dono). Só
-- insert/update/delete do próprio token por quem é dono dele.
create policy "calendar_tokens_insert" on public.calendar_tokens for insert
  with check (user_id = auth.uid());

create policy "calendar_tokens_update" on public.calendar_tokens for update
  using (user_id = auth.uid());

create policy "calendar_tokens_delete" on public.calendar_tokens for delete
  using (user_id = auth.uid());

create index idx_calendar_connections_clinic on public.calendar_connections (clinic_id);
