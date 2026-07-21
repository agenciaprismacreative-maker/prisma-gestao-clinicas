/* ===================================================================
   Prisma · barra de navegação superior (busca, lembretes, novo paciente)
   Componente Alpine independente, injetado junto com partials/topbar.html.
   =================================================================== */

function topbarApp() {
  return {
    clinicId: null,
    currentUserId: null,
    isAdmin: false,

    query: '',
    results: [],
    searching: false,
    showResults: false,

    reminders: [],
    showReminders: false,
    remindersLoading: false,

    async init() {
      const { data: { user } } = await supabaseClient.auth.getUser();
      if (!user) return;
      this.currentUserId = user.id;
      const { data } = await supabaseClient.from('users').select('clinic_id, role').eq('id', user.id).single();
      if (!data) return;
      this.clinicId = data.clinic_id;
      this.isAdmin = data.role === 'administrador' || data.role === 'equipe_prisma';
      await this.loadReminders();
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
      const [tasksRes, apptRes] = await Promise.all([
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
      ]);

      const items = [];
      (tasksRes.data || []).forEach((t) => {
        if (!this.isAdmin && t.assigned_to !== this.currentUserId) return;
        const due = t.due_date ? new Date(t.due_date) : null;
        const overdue = !!(due && due < now);
        items.push({
          label: t.title,
          overdue,
          href: 'equipe.html'
        });
      });
      (apptRes.data || []).forEach((a) => {
        items.push({
          label: 'Confirmar agendamento: ' + (a.patients ? a.patients.full_name : 'paciente'),
          overdue: false,
          href: 'agenda.html'
        });
      });
      items.sort((a, b) => (b.overdue ? 1 : 0) - (a.overdue ? 1 : 0));
      this.reminders = items.slice(0, 15);
      this.remindersLoading = false;
    },

    get overdueCount() {
      return this.reminders.filter((r) => r.overdue).length;
    }
  };
}
