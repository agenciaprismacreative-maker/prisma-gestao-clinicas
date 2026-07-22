/* ===================================================================
   Prisma · modal de confirmação estilizado, substituto do window.confirm()
   nativo do navegador (que foge do visual do sistema).

   Uso (em qualquer função async já existente, no lugar de window.confirm):
     if (!(await confirmDialog('Remover o serviço "Botox"?'))) return;

   Aceita um 2º argumento opcional para customizar título/rótulos/tom:
     await confirmDialog('Aprovar esta venda?', { danger: false, confirmLabel: 'Aprovar' })

   Não depende do Alpine nem do x-data da página: cria o overlay via DOM
   puro e resolve uma Promise<boolean>, por isso funciona em qualquer
   página que carregue este script, sem precisar de estado extra no
   componente Alpine de cada tela.
   =================================================================== */

function confirmDialog(message, opts) {
  opts = opts || {};
  const title = opts.title || 'Confirmar ação';
  const confirmLabel = opts.confirmLabel || 'Remover';
  const cancelLabel = opts.cancelLabel || 'Cancelar';
  const danger = opts.danger !== false;

  return new Promise((resolve) => {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay';
    overlay.style.zIndex = '9999';

    const card = document.createElement('div');
    card.className = 'card card-shadow';
    card.style.cssText = 'margin:auto;width:100%;max-width:400px;padding:24px;';

    const titleEl = document.createElement('h3');
    titleEl.style.cssText = 'margin:0 0 10px;font-size:16px;';
    titleEl.textContent = title;

    const msgEl = document.createElement('p');
    msgEl.className = 'text-sm text-muted';
    msgEl.style.cssText = 'margin:0 0 22px;line-height:1.55;';
    msgEl.textContent = message;

    const actions = document.createElement('div');
    actions.className = 'flex gap-2';
    actions.style.justifyContent = 'flex-end';

    const cancelBtn = document.createElement('button');
    cancelBtn.type = 'button';
    cancelBtn.className = 'btn btn-secondary btn-sm';
    cancelBtn.textContent = cancelLabel;

    const confirmBtn = document.createElement('button');
    confirmBtn.type = 'button';
    confirmBtn.className = 'btn btn-sm';
    confirmBtn.textContent = confirmLabel;
    confirmBtn.style.cssText = danger
      ? 'background:var(--color-danger);border-color:var(--color-danger);color:#fff;'
      : 'background:var(--color-primary);border-color:var(--color-primary);color:#fff;';

    actions.appendChild(cancelBtn);
    actions.appendChild(confirmBtn);
    card.appendChild(titleEl);
    card.appendChild(msgEl);
    card.appendChild(actions);
    overlay.appendChild(card);
    document.body.appendChild(overlay);

    // Foco no botão de confirmação por padrão, para permitir Enter.
    confirmBtn.focus();

    function cleanup(result) {
      document.removeEventListener('keydown', onKey);
      overlay.remove();
      resolve(result);
    }
    function onKey(e) {
      if (e.key === 'Escape') cleanup(false);
      if (e.key === 'Enter') cleanup(true);
    }
    document.addEventListener('keydown', onKey);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) cleanup(false); });
    cancelBtn.addEventListener('click', () => cleanup(false));
    confirmBtn.addEventListener('click', () => cleanup(true));
  });
}

window.confirmDialog = confirmDialog;
