/* ===================================================================
   Prisma · inclusão de fragmentos HTML (header e menu lateral)
   compartilhados entre páginas, conforme especificação (seção 3).

   Importante: como o carregamento usa fetch(), o projeto precisa ser
   aberto por um servidor local (não em file://). Na pasta do projeto,
   rode por exemplo "npx serve" ou "python3 -m http.server" e acesse o
   endereço indicado pelo terminal.
   =================================================================== */

async function loadIncludes() {
  const nodes = document.querySelectorAll('[data-include]');

  await Promise.all(Array.from(nodes).map(async (el) => {
    const file = el.getAttribute('data-include');
    try {
      const res = await fetch(file);
      if (!res.ok) throw new Error('HTTP ' + res.status);
      el.innerHTML = await res.text();
    } catch (err) {
      el.innerHTML =
        '<div style="padding:16px;font-size:12.5px;color:#B23A3A;font-family:sans-serif;">' +
        'Não foi possível carregar "' + file + '". Abra o projeto por um servidor local ' +
        '(ex.: executar "npx serve" na pasta) em vez de abrir o arquivo diretamente no navegador.' +
        '</div>';
      console.error('[include.js]', err);
    }
  }));

  markActivePage();
  fillPageTitle();
  startAlpine();
}

function markActivePage() {
  const current = document.body.getAttribute('data-page');
  document.querySelectorAll('.nav-item[data-page]').forEach((item) => {
    item.classList.toggle('active', item.getAttribute('data-page') === current);
  });
}

function fillPageTitle() {
  const title = document.body.getAttribute('data-title');
  const subtitle = document.body.getAttribute('data-subtitle');
  const titleEl = document.querySelector('[data-slot="page-title"]');
  const subtitleEl = document.querySelector('[data-slot="page-subtitle"]');
  if (titleEl && title) titleEl.textContent = title;
  if (subtitleEl && subtitle) subtitleEl.textContent = subtitle;
}

function startAlpine() {
  if (window.Alpine) return;
  const script = document.createElement('script');
  script.src = 'https://cdn.jsdelivr.net/npm/alpinejs@3.14.1/dist/cdn.min.js';
  script.defer = true;
  document.head.appendChild(script);
}

document.addEventListener('DOMContentLoaded', loadIncludes);
