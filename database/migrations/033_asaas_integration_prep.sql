-- 033_asaas_integration_prep.sql
-- Prepara os campos para a futura integração com o Asaas (gateway de
-- pagamento). Nenhuma chamada à API do Asaas é feita nesta migration --
-- só os campos que vão guardar o vínculo entre cada clínica/cobrança e o
-- respectivo registro no Asaas, para quando a integração for ligada não
-- precisar de uma nova migration nem alterar dado já existente.
-- Idempotente: seguro rodar mais de uma vez.

alter table public.clinics
  add column if not exists asaas_customer_id text;

comment on column public.clinics.asaas_customer_id is
  'ID do cliente correspondente no Asaas. Nulo até a integração ser ativada.';

alter table public.clinic_payments
  add column if not exists asaas_payment_id text,
  add column if not exists asaas_invoice_url text;

comment on column public.clinic_payments.asaas_payment_id is
  'ID da cobrança correspondente no Asaas. Nulo para pagamentos registrados manualmente.';
comment on column public.clinic_payments.asaas_invoice_url is
  'Link da fatura/boleto/checkout gerado pelo Asaas para essa cobrança.';
