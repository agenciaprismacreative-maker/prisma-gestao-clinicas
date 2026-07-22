-- ============================================================================
-- Migration 022: CEP do endereço da clínica (Configurações > Dados fiscais).
--
-- Guarda o CEP usado para preencher automaticamente o campo "Endereço
-- completo" via busca no ViaCEP, para que o CEP não precise ser digitado de
-- novo toda vez que a tela de Configurações for reaberta.
--
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.clinic_settings add column if not exists address_cep text;
