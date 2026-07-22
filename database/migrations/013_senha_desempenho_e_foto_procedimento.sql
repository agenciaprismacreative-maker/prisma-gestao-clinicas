-- ============================================================================
-- Migration 013: senha do gerente para acessar o quadro de Desempenho (BI) e
-- vínculo da foto de evolução ao atendimento/procedimento que a gerou.
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.clinic_settings
  add column if not exists manager_password_for_performance boolean not null default false;
alter table public.clinic_settings
  add column if not exists primary_color text;
alter table public.clinic_settings
  add column if not exists accent_color text;
alter table public.clinic_settings
  add column if not exists max_discount_percentage numeric(5, 2);

alter table public.patient_photos
  add column if not exists appointment_id uuid references public.appointments (id) on delete set null;

create index if not exists idx_patient_photos_appointment on public.patient_photos (appointment_id);
