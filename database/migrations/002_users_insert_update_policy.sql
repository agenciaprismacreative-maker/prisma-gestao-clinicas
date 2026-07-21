-- ============================================================================
-- Migration 002: políticas de INSERT/UPDATE para public.users
-- Corrige o erro "new row violates row-level security policy for table users"
-- ao vincular um novo integrante da equipe (e também protege a edição).
-- A tabela só tinha política de SELECT; faltava permitir insert/update
-- restritos à própria clínica (ou à equipe Prisma).
-- ============================================================================

create policy "users_insert" on public.users for insert
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());

create policy "users_update" on public.users for update
  using (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team())
  with check (clinic_id = public.auth_clinic_id() or public.auth_is_prisma_team());
