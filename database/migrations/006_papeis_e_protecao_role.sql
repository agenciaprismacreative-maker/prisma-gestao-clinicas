-- ============================================================================
-- Migration 006: renomeia os papéis para Esteticista / Atendente /
-- Administrador, e trava a alteração do papel de um usuário para que só um
-- Administrador (ou a equipe Prisma) consiga fazer essa mudança — mesmo que
-- alguém tente contornar a tela e chamar a API diretamente.
-- Seguro rodar mais de uma vez.
-- ============================================================================

-- 1) Migra os valores existentes
update public.users set role = 'esteticista' where role = 'profissional';
update public.users set role = 'atendente' where role = 'recepcao';
update public.users set role = 'administrador' where role in ('gestor', 'financeiro');
-- 'equipe_prisma' permanece como está: é o papel interno de super-admin da
-- Prisma Creative, com acesso a todas as clínicas, e não aparece nas opções
-- de cadastro que o cliente vê na tela de Equipe.

-- 2) Atualiza o check constraint da coluna role
alter table public.users drop constraint if exists users_role_check;
alter table public.users add constraint users_role_check check (
  role in ('esteticista', 'atendente', 'administrador', 'equipe_prisma')
);

-- 3) Função que confirma se quem está logado é administrador (ou equipe Prisma)
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

-- 4) Trigger: bloqueia qualquer UPDATE que mude a coluna role, a menos que
-- quem esteja fazendo a alteração seja administrador/equipe_prisma.
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
