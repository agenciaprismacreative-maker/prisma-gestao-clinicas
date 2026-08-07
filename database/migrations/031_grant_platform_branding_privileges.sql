-- 031: privilegios de tabela faltando em platform_branding.
--
-- A migration 029 criou platform_branding com RLS e uma policy de leitura
-- publica ("to anon, authenticated using (true)"), mas RLS sozinha nao
-- basta: sem o GRANT de privilegio na tabela em si, toda consulta esbarra
-- em 401 antes mesmo da policy ser avaliada. Era exatamente essa a causa
-- do erro 401 visto no console da tela de login (loadBranding() falhando
-- silenciosamente para visitante sem sessao, caindo no fallback padrao).

grant select on public.platform_branding to anon, authenticated;
grant insert, update, delete on public.platform_branding to authenticated;
