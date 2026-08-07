/* ===================================================================
   Prisma · conexão com o Supabase
   Carregar SEMPRE depois da tag <script> do CDN do supabase-js e ANTES
   de js/include.js e js/auth-guard.js.
   =================================================================== */

const SUPABASE_URL = 'https://xyltzpfjdbskxcdvxmih.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_DPg9ge8MZ7QIC8jkPQCFYQ_OOPpR7NC';

window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Traduz os erros mais comuns do Supabase Auth para uma mensagem em PT-BR
// que não soa técnica nem indica de propósito qual dos dois campos está
// errado (mensagem genérica, evita ajudar tentativa de adivinhação de
// e-mail cadastrado). Compartilhada entre index.html e
// acesso-administrativo.html -- as duas telas de login do sistema.
window.translateAuthError = function (error) {
  const msg = ((error && error.message) || '').toLowerCase();
  if (msg.includes('invalid login credentials') || msg.includes('user not found')) {
    return 'Ops, parece que alguma das informações de acesso está incorreta. Confira o e-mail e a senha e tente de novo.';
  }
  if (msg.includes('email not confirmed')) {
    return 'Seu e-mail ainda não foi confirmado. Verifique sua caixa de entrada.';
  }
  if (msg.includes('too many requests') || msg.includes('rate limit')) {
    return 'Muitas tentativas seguidas. Aguarde um instante e tente de novo.';
  }
  if (msg.includes('failed to fetch') || msg.includes('network')) {
    return 'Não foi possível conectar agora. Verifique sua internet e tente de novo.';
  }
  return 'Não foi possível entrar agora. Tente novamente em instantes.';
};

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
  // equipe_prisma tem o próprio console, fora do contexto de qualquer
  // clínica -- não é mais tratado como "administrador de uma clínica"
  // depois da restrição de acesso a dado de paciente (LGPD).
  equipe_prisma: 'admin-clinicas.html',
  esteticista: 'dashboard.html',
  atendente: 'dashboard.html'
};
window.homeForRole = function (role) {
  return window.PRISMA_ROLE_HOME[role] || 'agenda.html';
};
