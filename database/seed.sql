-- ============================================================================
-- Prisma · Dados de teste
-- Roda depois do schema.sql. Cria a clínica de demonstração, os serviços
-- usados no esboço visual, e vincula o usuário já criado em Authentication
-- (Authentication → Users) a essa clínica, como gestor.
-- ============================================================================

-- Idempotência: como a tabela services não tem uma coluna única além do id,
-- limpa os serviços de teste desta clínica antes de inserir de novo, para
-- este script poder ser rodado mais de uma vez sem duplicar linhas.
delete from public.services where clinic_id = 'a0000000-0000-4000-8000-000000000001';

-- Clínica de teste (UUID fixo para poder referenciar nas próximas seções
-- sem depender do retorno da inserção anterior).
insert into public.clinics (id, name, specialty)
values ('a0000000-0000-4000-8000-000000000001', 'Clínica Alma Estética', 'Estética e dermatologia')
on conflict (id) do nothing;

-- Vincula o usuário de autenticação (criado em Authentication → Users) a
-- essa clínica. Troque o UUID abaixo caso crie outro usuário de teste.
insert into public.users (id, clinic_id, full_name, email, role)
values (
  '7ca1c9df-96c7-405d-bd51-72aa2383684a',
  'a0000000-0000-4000-8000-000000000001',
  'Lairton',
  'agenciaprismacreative@gmail.com',
  'gestor'
)
on conflict (id) do update set
  clinic_id = excluded.clinic_id,
  full_name = excluded.full_name,
  role = excluded.role;

-- Catálogo de serviços, consistente com os dados usados no esboço visual.
insert into public.services (clinic_id, name, default_duration_minutes, price, return_interval_days)
values
  ('a0000000-0000-4000-8000-000000000001', 'Limpeza de pele', 60, 180.00, 30),
  ('a0000000-0000-4000-8000-000000000001', 'Botox', 30, 890.00, 120),
  ('a0000000-0000-4000-8000-000000000001', 'Preenchimento labial', 45, 1200.00, 365),
  ('a0000000-0000-4000-8000-000000000001', 'Peeling', 45, 250.00, 30),
  ('a0000000-0000-4000-8000-000000000001', 'Drenagem linfática', 60, 150.00, 7),
  ('a0000000-0000-4000-8000-000000000001', 'Laser depilação', 30, 220.00, 30),
  ('a0000000-0000-4000-8000-000000000001', 'Microagulhamento', 60, 350.00, 90);
