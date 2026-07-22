/* ===================================================================
   Prisma · barra de navegação superior (busca, lembretes, novo paciente)
   Componente Alpine independente, injetado junto com partials/topbar.html.
   =================================================================== */

function topbarApp() {
  return {
    clinicId: null,
    currentUserId: null,
    isAdmin: false,
    firstName: '',
    now: new Date(),

    query: '',
    results: [],
    searching: false,
    showResults: false,

    reminders: [],
    showReminders: false,
    remindersLoading: false,

    async init() {
      // relógio da saudação: atualiza sozinho, sem precisar recarregar a
      // página, pra sempre mostrar a data e a hora certas.
      setInterval(() => { this.now = new Date(); }, 30000);

      const { data: { user } } = await supabaseClient.auth.getUser();
      if (!user) return;
      this.currentUserId = user.id;
      const { data } = await supabaseClient.from('users').select('clinic_id, role, full_name').eq('id', user.id).single();
      if (!data) return;
      this.clinicId = data.clinic_id;
      this.isAdmin = data.role === 'administrador' || data.role === 'equipe_prisma';
      this.firstName = (data.full_name || '').trim().split(/\s+/)[0] || '';
      await this.loadReminders();
    },

    get greeting() {
      return this.firstName ? ('Olá, ' + this.firstName + '!') : 'Olá!';
    },

    get todaySummary() {
      const dateLabel = this.now.toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' });
      const timeLabel = this.now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
      const capitalized = dateLabel.charAt(0).toUpperCase() + dateLabel.slice(1);
      return 'Aqui estão os dados de hoje · ' + capitalized + ' · ' + timeLabel;
    },

    async onSearchInput() {
      const q = this.query.trim();
      if (q.length < 2) {
        this.results = [];
        this.showResults = false;
        return;
      }
      this.searching = true;
      this.showResults = true;
      const { data } = await supabaseClient
        .from('patients')
        .select('id, full_name, phone')
        .eq('clinic_id', this.clinicId)
        .ilike('full_name', '%' + q + '%')
        .order('full_name')
        .limit(8);
      this.results = data || [];
      this.searching = false;
    },

    goToPatient(p) {
      window.location.href = 'pacientes.html?patient_id=' + p.id;
    },

    closeSearchDelayed() {
      // pequeno atraso para o clique no resultado registrar antes do
      // dropdown sumir (blur dispara antes do click em alguns navegadores)
      setTimeout(() => { this.showResults = false; }, 150);
    },

    async loadReminders() {
      if (!this.clinicId) return;
      this.remindersLoading = true;
      const now = new Date();
      const in48h = new Date(now.getTime() + 48 * 3600 * 1000);
      const in3days = new Date(now.getTime() + 3 * 24 * 3600 * 1000);

      const queries = [
        supabaseClient
          .from('tasks')
          .select('id, title, due_date, status, assigned_to')
          .eq('clinic_id', this.clinicId)
          .neq('status', 'concluida'),
        supabaseClient
          .from('appointments')
          .select('id, scheduled_at, patients ( full_name )')
          .eq('clinic_id', this.clinicId)
          .eq('status', 'agendado')
          .gte('scheduled_at', now.toISOString())
          .lte('scheduled_at', in48h.toISOString())
      ];

      // Fontes extras, só para administrador: estoque baixo/vencendo e
      // vendas paradas aguardando aprovação. Consultas feitas com try/catch
      // implícito (erro vira lista vazia) para não quebrar o sino de
      // lembretes inteiro se alguma migração ainda não tiver sido aplicada.
      if (this.isAdmin) {
        queries.push(
          supabaseClient
            .from('products')
            .select('id, name, stock_quantity, min_stock_quantity, expiry_date')
            .eq('clinic_id', this.clinicId)
            .not('min_stock_quantity', 'is', null),
          supabaseClient
            .from('sales')
            .select('id, created_at, patients ( full_name )')
            .eq('clinic_id', this.clinicId)
            .eq('status', 'pendente')
        );
      }

      const [tasksRes, apptRes, productsRes, salesRes] = await Promise.all(queries);
      const items = [];

      // Tarefas: só entram no sino as atrasadas ou que vencem nos próximos
      // 3 dias. Mostrar toda tarefa aberta (sem olhar prazo) é o que deixava
      // isso raso — a lista virava ruído em vez de aviso.
      (tasksRes.data || []).forEach((t) => {
        if (!this.isAdmin && t.assigned_to !== this.currentUserId) return;
        const due = t.due_date ? new Date(t.due_date) : null;
        if (!due || due > in3days) return;
        const overdue = due < now;
        items.push({
          label: t.title,
          sublabel: overdue ? 'Tarefa atrasada' : 'Vence nos próximos dias',
          severity: overdue ? 'urgent' : 'warning',
          href: 'equipe.html'
        });
      });

      (apptRes.data || []).forEach((a) => {
        items.push({
          label: 'Confirmar: ' + (a.patients ? a.patients.full_name : 'paciente'),
          sublabel: 'Agendamento nas próximas 48h ainda sem confirmação',
          severity: 'info',
          href: 'agenda.html'
        });
      });

      if (this.isAdmin && productsRes && !productsRes.error) {
        const products = productsRes.data || [];
        products
          .filter((p) => Number(p.stock_quantity || 0) <= Number(p.min_stock_quantity))
          .forEach((p) => {
            items.push({
              label: 'Estoque baixo: ' + p.name,
              sublabel: Number(p.stock_quantity || 0) + ' em estoque (mínimo ' + p.min_stock_quantity + ')',
              severity: 'urgent',
              href: 'estoque.html'
            });
          });

        const in7days = new Date(now.getTime() + 7 * 24 * 3600 * 1000);
        products
          .filter((p) => p.expiry_date && new Date(p.expiry_date) <= in7days)
          .forEach((p) => {
            const expired = new Date(p.expiry_date) < now;
            items.push({
              label: (expired ? 'Vencido: ' : 'Vence em breve: ') + p.name,
              sublabel: expired ? 'Já passou da validade' : 'Vence em até 7 dias',
              severity: expired ? 'urgent' : 'warning',
              href: 'estoque.html'
            });
          });
      }

      if (this.isAdmin && salesRes && !salesRes.error) {
        (salesRes.data || []).forEach((s) => {
          const daysWaiting = Math.floor((now - new Date(s.created_at)) / 86400000);
          items.push({
            label: 'Venda pendente: ' + (s.patients ? s.patients.full_name : 'paciente'),
            sublabel: daysWaiting > 0 ? ('Aguardando aprovação há ' + daysWaiting + ' dia(s)') : 'Aguardando aprovação',
            severity: daysWaiting >= 2 ? 'urgent' : 'warning',
            href: 'vendas.html'
          });
        });
      }

      const severityWeight = { urgent: 0, warning: 1, info: 2 };
      items.sort((a, b) => severityWeight[a.severity] - severityWeight[b.severity]);
      this.reminders = items.slice(0, 20);
      this.remindersLoading = false;
    },

    get urgentCount() {
      return this.reminders.filter((r) => r.severity === 'urgent').length;
    },

    severityColor(severity) {
      if (severity === 'urgent') return 'var(--color-danger)';
      if (severity === 'warning') return 'var(--color-warning)';
      return 'var(--color-text)';
    }
  };
}
