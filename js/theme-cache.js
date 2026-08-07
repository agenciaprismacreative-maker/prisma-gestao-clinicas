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
   busca no banco normalmente e atualiza esse cache a cada carregamento.

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

    // Só os 2 tons principais aqui (o suficiente pra não piscar verde nos
    // botões/menu). js/include.js recalcula as variações completas
    // (contraste, tom escuro/claro) assim que a consulta real terminar.
    var root = document.documentElement.style;
    if (cached.primary_color) root.setProperty('--color-primary', cached.primary_color);
    if (cached.accent_color) root.setProperty('--color-accent', cached.accent_color);
  } catch (err) {
    // localStorage indisponível (aba anônima restrita, etc.) -- segue
    // com o padrão normal do sistema, sem quebrar nada.
  }
})();
