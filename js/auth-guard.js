/* ===================================================================
   Prisma · proteção de páginas internas
   Carregar depois de js/supabase-client.js em toda página que exige
   login (dashboard, pacientes, agenda, etc). Redireciona para o login
   se não houver sessão ativa no Supabase Auth.
   =================================================================== */

(async function () {
  const { data: { session } } = await supabaseClient.auth.getSession();
  if (!session) {
    window.location.href = 'index.html';
    return;
  }

  // Confere papel e status de acesso em toda página autenticada (não só nas
  // que têm data-allowed-roles), para um integrante desativado ser
  // derrubado mesmo em telas sem restrição de papel (ex.: Agenda). Se
  // is_active ainda não existir nesse banco (migration 018 pendente), cai
  // para buscar só o papel — assim a checagem de papel por página não para
  // de funcionar por causa de uma coluna nova.
  let profile = null;
  const withStatus = await supabaseClient.from('users').select('role, is_active').eq('id', session.user.id).single();
  if (!withStatus.error) {
    profile = withStatus.data;
  } else {
    const roleOnly = await supabaseClient.from('users').select('role').eq('id', session.user.id).single();
    if (roleOnly.error) {
      console.error('[auth-guard] erro ao verificar o papel do usuário:', roleOnly.error);
      return;
    }
    profile = roleOnly.data;
  }

  if (profile && profile.is_active === false) {
    await supabaseClient.auth.signOut();
    window.location.href = 'index.html?desativado=1';
    return;
  }

  const role = profile ? profile.role : null;
  window.__prismaUserRole = role;

  // Páginas marcadas com data-allowed-roles="administrador,atendente" no
  // <body> restringem quais papéis podem acessá-las direto pela URL. Sem o
  // atributo, a página é aberta a qualquer papel autenticado (ex.: Agenda,
  // que em vez de bloquear o acesso filtra os dados exibidos).
  const allowedRolesAttr = document.body.getAttribute('data-allowed-roles');
  if (!allowedRolesAttr) return;

  const allowedRoles = allowedRolesAttr.split(',').map((r) => r.trim());
  if (!window.isAdminRole(role) && !allowedRoles.includes(role)) {
    window.location.href = window.homeForRole(role);
  }
})();
