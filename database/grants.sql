-- ============================================================================
-- Prisma · Permissões de acesso (GRANT)
-- Quando tabelas são criadas direto pelo SQL Editor (em vez do Table Editor),
-- o Supabase às vezes não aplica automaticamente a permissão de acesso do
-- role "authenticated" às tabelas nem às funções do schema public. RLS
-- filtra QUAIS linhas um usuário vê, mas antes disso o Postgres precisa
-- conceder a permissão de acesso à tabela em si. Rodar uma vez, depois do
-- schema.sql e do seed.sql.
-- ============================================================================

grant usage on schema public to authenticated, anon;

grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant execute on all functions in schema public to authenticated;

-- Usuários não logados (anon) não precisam ler nada das tabelas de negócio.
revoke all on all tables in schema public from anon;
