// supabase/functions/sync-calendar-event/index.ts
//
// Sincroniza um agendamento da Prisma com o Google Calendar do profissional
// responsável. Mão única: Prisma -> Google -- mudanças feitas direto no
// Google não voltam pra Prisma. Chamada best-effort pelo client (agenda.html)
// depois de criar/remarcar/cancelar um agendamento: uma falha aqui nunca
// desfaz a operação que já foi salva no banco.
//
// Body esperado: { appointment_id: string, action?: 'upsert' | 'cancel' }
// ('upsert' é o default -- cria o evento se ainda não existe, atualiza se já
// existe. 'cancel' apaga o evento do Google.)
//
// Segredos necessários (Supabase Dashboard -> Edge Functions -> Secrets):
//   GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET
//   -> o MESMO client OAuth já usado pelo login "Continuar com Google"
//      (Authentication -> Providers -> Google no painel do Supabase).
// SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY já vêm prontos em toda função,
// não precisa configurar.

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_CLIENT_ID = Deno.env.get("GOOGLE_CLIENT_ID") ?? "";
const GOOGLE_CLIENT_SECRET = Deno.env.get("GOOGLE_CLIENT_SECRET") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
      return json({ ok: false, error: "GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET não configurados nos segredos da função." }, 500);
    }

    const authHeader = req.headers.get("Authorization") || "";

    // Client com o token de quem chamou -- só serve pra identificar a
    // pessoa e a clínica dela (auth.getUser() valida o JWT).
    const callerClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });
    const { data: { user }, error: userError } = await callerClient.auth.getUser();
    if (userError || !user) return json({ ok: false, error: "não autenticado" }, 401);

    const { data: callerProfile } = await callerClient
      .from("users")
      .select("clinic_id, role")
      .eq("id", user.id)
      .single();
    if (!callerProfile) return json({ ok: false, error: "perfil não encontrado" }, 403);
    const isPrismaTeam = callerProfile.role === "equipe_prisma";

    const body = await req.json().catch(() => ({}));
    const appointmentId = body.appointment_id;
    const action = body.action === "cancel" ? "cancel" : "upsert";
    if (!appointmentId) return json({ ok: false, error: "appointment_id é obrigatório" }, 400);

    // Client com service role -- ignora RLS. Único jeito de ler
    // calendar_tokens (sem policy de select nenhuma) e gravar o
    // google_event_id de volta no agendamento.
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    const { data: appt, error: apptError } = await admin
      .from("appointments")
      .select("id, clinic_id, professional_id, scheduled_at, duration_minutes, status, google_event_id, patients(full_name), services(name)")
      .eq("id", appointmentId)
      .single();
    if (apptError || !appt) return json({ ok: false, error: "agendamento não encontrado" }, 404);

    // só deixa disparar sync pra agendamento da própria clínica de quem
    // chamou (ou equipe Prisma) -- evita adivinhar id de outra clínica.
    if (!isPrismaTeam && appt.clinic_id !== callerProfile.clinic_id) {
      return json({ ok: false, error: "não autorizado" }, 403);
    }

    if (!appt.professional_id) return json({ ok: true, skipped: "sem profissional vinculado" });

    const { data: connection } = await admin
      .from("calendar_connections")
      .select("google_calendar_id, sync_enabled")
      .eq("user_id", appt.professional_id)
      .maybeSingle();
    if (!connection || !connection.sync_enabled) {
      return json({ ok: true, skipped: "profissional sem Google Calendar conectado" });
    }

    const { data: tokenRow } = await admin
      .from("calendar_tokens")
      .select("refresh_token")
      .eq("user_id", appt.professional_id)
      .maybeSingle();
    if (!tokenRow) {
      return json({ ok: true, skipped: "conexão incompleta -- sem refresh token" });
    }

    // troca o refresh_token por um access_token novo
    const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: GOOGLE_CLIENT_ID,
        client_secret: GOOGLE_CLIENT_SECRET,
        refresh_token: tokenRow.refresh_token,
        grant_type: "refresh_token",
      }),
    });
    const tokenData = await tokenResp.json();
    if (!tokenResp.ok || !tokenData.access_token) {
      await admin.from("calendar_connections").update({
        last_sync_error: "Falha ao renovar autorização do Google: " + (tokenData.error_description || tokenData.error || tokenResp.status),
      }).eq("user_id", appt.professional_id);
      return json({ ok: false, error: "falha ao renovar token do Google" }, 502);
    }
    const accessToken = tokenData.access_token as string;
    const calendarId = encodeURIComponent(connection.google_calendar_id || "primary");
    const googleHeaders = { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" };

    // cancelamento explícito, ou o próprio status do agendamento já virou
    // "cancelado" -- nesses casos só apaga o evento do Google (se existir).
    if (action === "cancel" || appt.status === "cancelado") {
      if (appt.google_event_id) {
        await fetch(
          `https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events/${appt.google_event_id}`,
          { method: "DELETE", headers: googleHeaders },
        );
        await admin.from("appointments").update({ google_event_id: null }).eq("id", appt.id);
      }
      await admin.from("calendar_connections")
        .update({ last_synced_at: new Date().toISOString(), last_sync_error: null })
        .eq("user_id", appt.professional_id);
      return json({ ok: true, action: "cancelled" });
    }

    const start = new Date(appt.scheduled_at);
    const end = new Date(start.getTime() + (appt.duration_minutes || 60) * 60000);
    const patientName = (appt.patients as any)?.full_name || "Paciente";
    const serviceName = (appt.services as any)?.name || "Atendimento";

    const eventBody = {
      summary: patientName + " · " + serviceName,
      description: "Agendamento sincronizado automaticamente do painel Prisma.",
      start: { dateTime: start.toISOString() },
      end: { dateTime: end.toISOString() },
    };

    let googleResp: Response;
    let googleData: any;
    if (appt.google_event_id) {
      googleResp = await fetch(
        `https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events/${appt.google_event_id}`,
        { method: "PATCH", headers: googleHeaders, body: JSON.stringify(eventBody) },
      );
      googleData = await googleResp.json();
      // evento pode ter sido apagado direto no Google -- se der 404/410,
      // recria do zero em vez de falhar.
      if (googleResp.status === 404 || googleResp.status === 410) {
        googleResp = await fetch(
          `https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events`,
          { method: "POST", headers: googleHeaders, body: JSON.stringify(eventBody) },
        );
        googleData = await googleResp.json();
      }
    } else {
      googleResp = await fetch(
        `https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events`,
        { method: "POST", headers: googleHeaders, body: JSON.stringify(eventBody) },
      );
      googleData = await googleResp.json();
    }

    if (!googleResp.ok) {
      await admin.from("calendar_connections").update({
        last_sync_error: "Erro do Google Calendar: " + (googleData?.error?.message || googleResp.status),
      }).eq("user_id", appt.professional_id);
      return json({ ok: false, error: "falha ao gravar evento no Google" }, 502);
    }

    await admin.from("appointments").update({ google_event_id: googleData.id }).eq("id", appt.id);
    await admin.from("calendar_connections")
      .update({ last_synced_at: new Date().toISOString(), last_sync_error: null })
      .eq("user_id", appt.professional_id);

    return json({ ok: true, action: appt.google_event_id ? "updated" : "created", google_event_id: googleData.id });
  } catch (err) {
    console.error("[sync-calendar-event]", err);
    return json({ ok: false, error: String(err) }, 500);
  }
});
