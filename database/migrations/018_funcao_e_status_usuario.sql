-- ============================================================================
-- Migration 018: função (cargo) separada do papel de acesso, e status
-- ativo/inativo do integrante.
--
-- job_function guarda o cargo do dia a dia (esteticista/atendente),
-- independente de a pessoa também ter (ou não) acesso de administrador —
-- isso permite conceder/remover admin sem perder de vista qual é a função
-- real da pessoa na clínica.
--
-- is_active permite "remover" um integrante sem apagar o histórico dele
-- (vendas, comissões, atendimentos continuam intactos): a pessoa só deixa
-- de conseguir entrar no sistema.
--
-- Seguro rodar mais de uma vez.
-- ============================================================================

alter table public.users add column if not exists job_function text;
alter table public.users add column if not exists is_active boolean not null default true;

-- Preenche job_function para quem já existe, a partir do papel atual (só
-- faz sentido para quem não é administrador nem equipe_prisma).
update public.users
set job_function = role
where job_function is null and role in ('atendente', 'esteticista');
