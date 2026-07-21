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

  // Páginas marcadas com data-allowed-roles="administrador,atendente" no
  // <body> restringem quais papéis podem acessá-las direto pela URL. Sem o
  // atributo, a página é aberta a qualquer papel autenticado (ex.: Agenda,
  // que em vez de bloquear o acesso filtra os dados exibidos).
  const allowedRolesAttr = document.body.getAttribute('data-allowed-roles');
  if (!allowedRolesAttr) return;

  const { data: profile, error } = await supabaseClient
    .from('users')
    .select('role')
    .eq('id', session.user.id)
    .single();

  if (error) {
    console.error('[auth-guard] erro ao verificar o papel do usuário:', error);
    return;
  }

  const role = profile ? profile.role : null;
  window.__prismaUserRole = role;
  const allowedRoles = allowedRolesAttr.split(',').map((r) => r.trim());
  if (!window.isAdminRole(role) && !allowedRoles.includes(role)) {
    window.location.href = window.homeForRole(role);
  }
})();
