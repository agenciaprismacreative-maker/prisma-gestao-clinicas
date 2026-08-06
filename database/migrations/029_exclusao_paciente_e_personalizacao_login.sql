-- ============================================================================
-- 029: permitir exclusão definitiva de paciente + personalização da tela de
-- login controlada pelo painel Prisma.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Parte 1: transactions/tasks/communications_log referenciavam patients sem
-- regra de ON DELETE (default = NO ACTION), o que bloqueava a exclusão de
-- qualquer paciente com histórico financeiro, tarefa ou mensagem registrada
-- -- ou seja, praticamente todo paciente real. Troca para SET NULL: o
-- registro (financeiro, tarefa, log de mensagem) continua existindo para fins
-- de relatório/fiscal, só perde o vínculo com o paciente excluído.
-- ----------------------------------------------------------------------------
alter table public.transactions drop constraint transactions_patient_id_fkey;
alter table public.transactions add constraint transactions_patient_id_fkey
  foreign key (patient_id) references public.patients (id) on delete set null;

alter table public.tasks drop constraint tasks_patient_id_fkey;
alter table public.tasks add constraint tasks_patient_id_fkey
  foreign key (patient_id) references public.patients (id) on delete set null;

alter table public.communications_log drop constraint communications_log_patient_id_fkey;
alter table public.communications_log add constraint communications_log_patient_id_fkey
  foreign key (patient_id) references public.patients (id) on delete set null;

-- ----------------------------------------------------------------------------
-- Parte 2: platform_branding -- linha única com a identidade visual da tela
-- de login (logo, imagem de fundo, cores, textos), editável só pela equipe
-- Prisma no admin-clinicas.html. Leitura pública porque a tela de login é
-- acessada sem sessão autenticada.
-- ----------------------------------------------------------------------------
create table public.platform_branding (
  id integer primary key default 1,
  constraint platform_branding_singleton check (id = 1),
  logo_url text,
  background_url text,
  primary_color text,
  accent_color text,
  login_title text not null default 'Prisma · Gestão de Clínicas',
  login_subtitle text not null default 'Acesse o painel da sua clínica',
  support_message text not null default 'Esqueceu a senha? Fale com a administração da clínica.',
  footer_text text not null default 'Sistema interno · Prisma Creative',
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users (id) on delete set null
);

insert into public.platform_branding (id) values (1) on conflict (id) do nothing;

alter table public.platform_branding enable row level security;

create policy "platform_branding_select" on public.platform_branding for select
  to anon, authenticated
  using (true);

create policy "platform_branding_write" on public.platform_branding for all
  using (public.auth_is_prisma_team())
  with check (public.auth_is_prisma_team());

-- ----------------------------------------------------------------------------
-- Parte 3: bucket público dedicado (não reaproveita clinic-assets, porque o
-- upload deste bucket precisa ficar restrito à equipe Prisma, não a
-- "qualquer autenticado" como no clinic-assets).
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('platform-branding', 'platform-branding', true)
on conflict (id) do nothing;

create policy "platform_branding_storage_select" on storage.objects for select
  using (bucket_id = 'platform-branding');

create policy "platform_branding_storage_insert" on storage.objects for insert
  with check (bucket_id = 'platform-branding' and public.auth_is_prisma_team());

create policy "platform_branding_storage_update" on storage.objects for update
  using (bucket_id = 'platform-branding' and public.auth_is_prisma_team());

create policy "platform_branding_storage_delete" on storage.objects for delete
  using (bucket_id = 'platform-branding' and public.auth_is_prisma_team());
