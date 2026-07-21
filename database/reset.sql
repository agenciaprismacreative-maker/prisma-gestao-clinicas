-- ============================================================================
-- Prisma · Script de limpeza
-- Rodar SOMENTE se uma tentativa anterior do schema.sql ficou incompleta e
-- está travando a criação (erro do tipo "relation already exists").
-- Remove tudo o que schema.sql cria, para permitir rodar do zero com segurança.
-- ============================================================================

drop table if exists public.communications_log cascade;
drop table if exists public.leads cascade;
drop table if exists public.transactions cascade;
drop table if exists public.tasks cascade;
drop table if exists public.patient_photos cascade;
drop table if exists public.medical_records cascade;
drop table if exists public.appointments cascade;
drop table if exists public.packages cascade;
drop table if exists public.patients cascade;
drop table if exists public.services cascade;
drop table if exists public.users cascade;
drop table if exists public.clinics cascade;

drop function if exists public.auth_clinic_id() cascade;
drop function if exists public.auth_is_prisma_team() cascade;

drop policy if exists "patient_photos_storage_select" on storage.objects;
drop policy if exists "patient_photos_storage_insert" on storage.objects;
-- O bucket "patient-photos" não precisa ser removido: o schema.sql usa
-- "on conflict do nothing" ao recriá-lo, então não há erro mesmo se ele
-- já existir. O Supabase também bloqueia exclusão direta dessa tabela
-- por SQL (é preciso usar a Storage API), então não tentamos aqui.
