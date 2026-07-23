-- 026: política de UPDATE em public.clinics
--
-- Faltava uma policy de RLS para UPDATE na tabela clinics (só existia
-- "clinics_select"). Sem ela, o Postgres aceita a chamada de update sem
-- erro nenhum, mas não altera nenhuma linha, porque a checagem de RLS
-- filtra todas as linhas antes do update ser aplicado. Na prática, isso
-- fazia o nome da clínica parecer "travado" no valor antigo: a tela de
-- Configurações mostrava "Configurações salvas." (nenhum erro retornado),
-- mas o campo clinics.name nunca era gravado de fato.
--
-- Restrita a administrador da própria clínica, coerente com a página de
-- Configurações (data-allowed-roles="administrador").

create policy "clinics_update" on public.clinics for update
  using (id = public.auth_clinic_id() and public.auth_is_admin())
  with check (id = public.auth_clinic_id() and public.auth_is_admin());
