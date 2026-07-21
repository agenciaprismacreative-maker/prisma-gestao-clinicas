/* ===================================================================
   Prisma · conexão com o Supabase
   Carregar SEMPRE depois da tag <script> do CDN do supabase-js e ANTES
   de js/include.js e js/auth-guard.js.
   =================================================================== */

const SUPABASE_URL = 'https://xyltzpfjdbskxcdvxmih.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_DPg9ge8MZ7QIC8jkPQCFYQ_OOPpR7NC';

window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
