/* ===================================================================
   Prisma · conexão com o Supabase
   Carregar SEMPRE depois da tag <script> do CDN do supabase-js e ANTES
   de js/include.js e js/auth-guard.js.
   =================================================================== */

const SUPABASE_URL = 'https://xyltzpfjdbskxcdvxmih.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_DPg9ge8MZ7QIC8jkPQCFYQ_OOPpR7NC';

window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ---------------------------------------------------------------------------
// Visões do sistema: Administrador, Esteticista e Atendente.
// - Administrador (também aceita o papel interno "equipe_prisma", usado só
//   pela equipe da Prisma Creative): acesso ao sistema inteiro.
// - Esteticista: só a própria Agenda e a própria fila de Atendimento.
// - Atendente: Agenda completa (de todos os profissionais) e Pacientes, sem
//   Atendimento nem áreas administrativas.
// ---------------------------------------------------------------------------
window.PRISMA_STAFF_ROLES = ['atendente', 'esteticista'];
window.isStaffRole = function (role) {
  return window.PRISMA_STAFF_ROLES.includes(role);
};
window.isAdminRole = function (role) {
  return role === 'administrador' || role === 'equipe_prisma';
};
window.PRISMA_ROLE_HOME = {
  administrador: 'dashboard.html',
  equipe_prisma: 'dashboard.html',
  esteticista: 'dashboard.html',
  atendente: 'dashboard.html'
};
window.homeForRole = function (role) {
  return window.PRISMA_ROLE_HOME[role] || 'agenda.html';
};
