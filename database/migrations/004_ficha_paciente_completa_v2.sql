-- ============================================================================
-- Migration 004: ficha de paciente completa (documentos, contato, endereço,
-- origem do lead/indicação, responsável legal e dados complementares).
-- Inspirado nos prints de um sistema de gestão de estética já usado pelo
-- cliente, adaptado ao que faz sentido para o Prisma.
-- ============================================================================

alter table public.patients
  -- documentos
  add column if not exists rg text,
  add column if not exists rg_orgao_emissor text,
  add column if not exists rg_data_emissao date,

  -- contato expandido
  add column if not exists phone2 text,
  add column if not exists landline text,
  add column if not exists instagram text,
  add column if not exists facebook text,

  -- endereço
  add column if not exists address_cep text,
  add column if not exists address_street text,
  add column if not exists address_number text,
  add column if not exists address_neighborhood text,
  add column if not exists address_complement text,
  add column if not exists address_city text,
  add column if not exists address_state text,

  -- origem do lead / indicação
  add column if not exists lead_source text,
  add column if not exists referred_by_patient_id uuid references public.patients (id) on delete set null,
  add column if not exists referred_by_name text,

  -- responsável legal (paciente menor de idade ou dependente)
  add column if not exists legal_guardian_name text,
  add column if not exists legal_guardian_cpf text,
  add column if not exists legal_guardian_notes text,

  -- dados complementares
  add column if not exists naturality text,
  add column if not exists father_name text,
  add column if not exists mother_name text,
  add column if not exists profession text,
  add column if not exists workplace text,
  add column if not exists record_number text,
  add column if not exists gender text,
  add column if not exists marital_status text,
  add column if not exists blood_type text,
  add column if not exists client_type text default 'particular';
