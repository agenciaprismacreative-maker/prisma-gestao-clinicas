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
  setupLogout();
  fillUserInfo();
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

function setupLogout() {
  const btn = document.querySelector('[data-action="logout"]');
  if (!btn || !window.supabaseClient) return;
  btn.addEventListener('click', async () => {
    await supabaseClient.auth.signOut();
    window.location.href = 'index.html';
  });
}

function getInitials(name) {
  if (!name) return '--';
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

async function fillUserInfo() {
  if (!window.supabaseClient) return;
  const nameEl = document.querySelector('[data-slot="user-name"]');
  const clinicEl = document.querySelector('[data-slot="clinic-name"]');
  const initialsEl = document.querySelector('[data-slot="user-initials"]');
  if (!nameEl && !clinicEl && !initialsEl) return;

  try {
    const { data: { user } } = await supabaseClient.auth.getUser();
    if (!user) return;

    // Preenche com o e-mail imediatamente, para nunca ficar travado em
    // "Carregando…" mesmo se a consulta de perfil abaixo falhar.
    if (nameEl) nameEl.textContent = user.email;
    if (initialsEl) initialsEl.textContent = getInitials(user.email);

    const { data: profile, error } = await supabaseClient
      .from('users')
      .select('clinic_id, full_name, role, clinics ( name )')
      .eq('id', user.id)
      .single();

    if (error) {
      console.error('[fillUserInfo] erro ao buscar perfil em public.users:', error);
      return;
    }
    if (!profile) return;

    if (nameEl) nameEl.textContent = profile.full_name || user.email;
    if (clinicEl) clinicEl.textContent = profile.clinics ? profile.clinics.name : '';
    if (initialsEl) initialsEl.textContent = getInitials(profile.full_name);
    window.__prismaClinicName = profile.clinics ? profile.clinics.name : '';

    window.__prismaUserRole = profile.role;
    applyRoleVisibility(profile.role);
    await applyClinicSettings(profile.clinic_id, profile.role);
    await applyPendingSalesIndicator(profile.clinic_id, profile.role);
  } catch (err) {
    console.error('[include.js] fillUserInfo:', err);
  }
}

// pontinho amarelo no item "Vendas" do menu lateral quando há venda parada
// aguardando aprovação — mesmo critério do lembrete "Venda pendente" do sino
// (topbar.js), só que visível direto no menu, sem precisar abrir o sino.
// Só para administrador, que é quem aprova a venda.
async function applyPendingSalesIndicator(clinicId, role) {
  if (!clinicId || !window.supabaseClient) return;
  if (!(window.isAdminRole && window.isAdminRole(role))) return;
  try {
    const { count, error } = await supabaseClient
      .from('sales')
      .select('id', { count: 'exact', head: true })
      .eq('clinic_id', clinicId)
      .eq('status', 'pendente');
    if (error) return;
    const dot = document.querySelector('[data-slot="vendas-pending-dot"]');
    if (dot) dot.style.display = (count && count > 0) ? 'block' : 'none';
  } catch (err) {
    console.error('[include.js] applyPendingSalesIndicator:', err);
  }
}

function shadeColor(hex, percent) {
  if (!hex) return hex;
  const clean = hex.replace('#', '');
  if (clean.length !== 6) return hex;
  const num = parseInt(clean, 16);
  if (Number.isNaN(num)) return hex;
  let r = (num >> 16) + Math.round(255 * percent);
  let g = ((num >> 8) & 0x00FF) + Math.round(255 * percent);
  let b = (num & 0x0000FF) + Math.round(255 * percent);
  r = Math.max(0, Math.min(255, r));
  g = Math.max(0, Math.min(255, g));
  b = Math.max(0, Math.min(255, b));
  return '#' + (0x1000000 + r * 0x10000 + g * 0x100 + b).toString(16).slice(1);
}

function hexToRgb(hex) {
  const clean = (hex || '').replace('#', '');
  if (clean.length !== 6) return null;
  const num = parseInt(clean, 16);
  if (Number.isNaN(num)) return null;
  return { r: (num >> 16) & 0xFF, g: (num >> 8) & 0xFF, b: num & 0xFF };
}

// Luminância relativa (fórmula do WCAG), usada para decidir automaticamente
// se o texto sobre uma cor deve ser branco ou escuro, e para garantir que
// a variante "-dark" de uma cor fique escura o bastante para texto branco
// em cima, não importa quão clara seja a cor original escolhida.
function relativeLuminance(hex) {
  const rgb = hexToRgb(hex);
  if (!rgb) return 1;
  const channels = [rgb.r, rgb.g, rgb.b].map((c) => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}

function contrastTextColor(hex) {
  if (!hex) return '#FFFFFF';
  return relativeLuminance(hex) > 0.42 ? '#1F2624' : '#FFFFFF';
}

// Escurece progressivamente até a luminância cair abaixo do alvo, em vez de
// aplicar sempre a mesma porcentagem fixa — assim uma cor de marca muito
// clara (ex.: um rosa pastel) ainda vira um fundo escuro o suficiente para
// o texto branco da barra lateral continuar legível.
function ensureDarkEnough(hex, maxLuminance) {
  let current = shadeColor(hex, -0.22);
  let extra = 0;
  while (relativeLuminance(current) > maxLuminance && extra < 0.85) {
    extra += 0.12;
    current = shadeColor(hex, -0.22 - extra);
  }
  return current;
}

function applyBrandColors(primary, accent) {
  const root = document.documentElement.style;
  if (primary) {
    root.setProperty('--color-primary', primary);
    root.setProperty('--color-primary-dark', ensureDarkEnough(primary, 0.35));
    root.setProperty('--color-primary-light', shadeColor(primary, 0.86));
    root.setProperty('--color-primary-contrast', contrastTextColor(primary));
  }
  if (accent) {
    root.setProperty('--color-accent', accent);
    root.setProperty('--color-accent-light', shadeColor(accent, 0.86));
    root.setProperty('--color-accent-contrast', contrastTextColor(accent));
  }
}
window.shadeColor = shadeColor;
window.hexToRgb = hexToRgb;
window.relativeLuminance = relativeLuminance;
window.contrastTextColor = contrastTextColor;
window.ensureDarkEnough = ensureDarkEnough;
window.applyBrandColors = applyBrandColors;

async function applyClinicSettings(clinicId, role) {
  if (!clinicId) return;
  try {
    const { data: settings } = await supabaseClient
      .from('clinic_settings')
      .select('logo_url, theme, prevent_double_booking, agenda_name_format, manager_password, manager_password_for_discount, manager_password_for_courtesy, show_performance_to_staff, manager_password_for_performance, primary_color, accent_color, max_discount_percentage, legal_name, cnpj, company_address')
      .eq('clinic_id', clinicId)
      .maybeSingle();

    window.__prismaClinicSettings = settings || {};

    document.documentElement.setAttribute('data-theme', settings && settings.theme === 'escuro' ? 'escuro' : 'claro');

    if (settings && (settings.primary_color || settings.accent_color)) {
      applyBrandColors(settings.primary_color, settings.accent_color);
    }

    if (settings && settings.logo_url) {
      const logoImg = document.querySelector('[data-slot="clinic-logo"]');
      const defaultLogo = document.querySelector('[data-slot="default-logo"]');
      if (logoImg) { logoImg.src = settings.logo_url; logoImg.style.display = 'block'; }
      if (defaultLogo) defaultLogo.style.display = 'none';
    }

    const isAdmin = window.isAdminRole && window.isAdminRole(role);
    if (settings && settings.show_performance_to_staff === false && !isAdmin) {
      document.querySelectorAll('.nav-item[data-page="bi"]').forEach((el) => { el.style.display = 'none'; });
      if (document.body.getAttribute('data-page') === 'bi') {
        window.location.href = 'dashboard.html';
        return;
      }
    }

    if (settings && settings.manager_password_for_performance && !isAdmin && document.body.getAttribute('data-page') === 'bi') {
      const attempt = window.prompt('Esta área exige a senha do gerente. Digite a senha para continuar:');
      if (!settings.manager_password || attempt !== settings.manager_password) {
        window.alert('Senha incorreta. Você será redirecionado ao Dashboard.');
        window.location.href = 'dashboard.html';
        return;
      }
    }
  } catch (err) {
    console.error('[include.js] applyClinicSettings:', err);
  }
}

function applyRoleVisibility(role) {
  if (window.isAdminRole && window.isAdminRole(role)) return; // administrador vê o menu inteiro
  document.querySelectorAll('[data-allowed-roles]').forEach((el) => {
    const allowed = el.getAttribute('data-allowed-roles').split(',').map((r) => r.trim());
    if (!allowed.includes(role)) {
      el.style.display = 'none';
    }
  });
}

function startAlpine() {
  if (window.Alpine) return;
  const script = document.createElement('script');
  script.src = 'https://cdn.jsdelivr.net/npm/alpinejs@3.14.1/dist/cdn.min.js';
  script.defer = true;
  document.head.appendChild(script);
}

document.addEventListener('DOMContentLoaded', loadIncludes);
