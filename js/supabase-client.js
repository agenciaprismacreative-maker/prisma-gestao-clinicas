/* ===================================================================
   Prisma · conexão com o Supabase
   Carregar SEMPRE depois da tag <script> do CDN do supabase-js e ANTES
   de js/include.js e js/auth-guard.js.
   =================================================================== */

const SUPABASE_URL = 'https://xyltzpfjdbskxcdvxmih.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_DPg9ge8MZ7QIC8jkPQCFYQ_OOPpR7NC';

window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ---------------------------------------------------------------------------
// Visões do sistema: Administrador (gestor, financeiro, equipe_prisma) e
// Funcionário/esteticista (recepção, profissional). O funcionário só acessa
// Agenda (a própria) e Atendimento (a própria fila); o restante do menu
// (Dashboard, Pacientes, Equipe, Financeiro, Pós-venda, Serviços, BI) é
// exclusivo do Administrador.
// ---------------------------------------------------------------------------
window.PRISMA_STAFF_ROLES = ['recepcao', 'profissional'];
window.isStaffRole = function (role) {
  return window.PRISMA_STAFF_ROLES.includes(role);
};
