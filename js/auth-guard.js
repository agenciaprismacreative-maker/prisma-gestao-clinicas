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

  // Páginas marcadas com data-admin-only="true" no <body> são exclusivas da
  // visão Administrador. Um Funcionário (recepção/profissional) que tentar
  // acessá-las direto pela URL é redirecionado para a tela de Atendimento.
  const adminOnly = document.body.getAttribute('data-admin-only') === 'true';
  if (!adminOnly) return;

  const { data: profile, error } = await supabaseClient
    .from('users')
    .select('role')
    .eq('id', session.user.id)
    .single();

  if (error) {
    console.error('[auth-guard] erro ao verificar o papel do usuário:', error);
    return;
  }

  window.__prismaUserRole = profile ? profile.role : null;
  if (profile && window.isStaffRole(profile.role)) {
    window.location.href = 'atendimento.html';
  }
})();
