/* ===================================================================
   Prisma · cache local de tema e cores da marca

   Evita o "flash" de verde/tema claro padrão toda vez que a página é
   recarregada ou se navega para outra tela: como as cores da clínica
   (Configurações > Marca) só chegam depois de uma consulta ao Supabase
   (js/include.js -> applyClinicSettings), sem isso a tela sempre pinta
   primeiro com os valores fixos do CSS e só troca de cor alguns
   instantes depois -- esse é o "rastro" reportado.

   Aqui só se lê o que já foi salvo da última vez que as configurações
   reais foram confirmadas (localStorage), e aplica na hora, antes da
   tela pintar. js/include.js continua sendo a fonte da verdade: ele
   busca no banco normalmente e recalcula/atualiza esse cache a cada
   carregamento -- inclusive os tons DERIVADOS (--color-primary-dark/
   -light/-contrast, --color-accent-light/-contrast), não só a cor base.
   Cachear só a cor base não era suficiente: o menu lateral, hovers e
   texto de contraste usam esses tons derivados, e ficavam presos no
   valor padrão do CSS (verde) até include.js recalcular tudo de novo --
   por isso o rastro continuava aparecendo mesmo com o cache ligado.

   Carregar em <head>, logo depois do <link> do styles.css, SEM defer
   nem async -- precisa terminar de rodar antes do restante da página
   ser pintado, senão o efeito que resolve nem chega a acontecer.
   =================================================================== */
(function () {
  try {
    var cached = JSON.parse(localStorage.getItem('prisma_theme_cache') || 'null');
    if (!cached) return;

    if (cached.theme === 'escuro') {
      document.documentElement.setAttribute('data-theme', 'escuro');
    }

    var root = document.documentElement.style;
    if (cached.primary_color) root.setProperty('--color-primary', cached.primary_color);
    if (cached.primary_dark) root.setProperty('--color-primary-dark', cached.primary_dark);
    if (cached.primary_light) root.setProperty('--color-primary-light', cached.primary_light);
    if (cached.primary_contrast) root.setProperty('--color-primary-contrast', cached.primary_contrast);
    if (cached.accent_color) root.setProperty('--color-accent', cached.accent_color);
    if (cached.accent_light) root.setProperty('--color-accent-light', cached.accent_light);
    if (cached.accent_contrast) root.setProperty('--color-accent-contrast', cached.accent_contrast);
  } catch (err) {
    // localStorage indisponível (aba anônima restrita, etc.) -- segue
    // com o padrão normal do sistema, sem quebrar nada.
  }
})();
