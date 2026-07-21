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
  }
})();
