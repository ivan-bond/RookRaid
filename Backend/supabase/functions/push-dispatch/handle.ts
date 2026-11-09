// Rook Raid – Edge Function „push-dispatch“: verschickt die Push-Nachrichten, die der Aufrufer ausgelöst hat.
// Die App ruft sie direkt nach einer Freundschaftsanfrage oder -annahme auf. Was verschickt wird, steht nur in
// push_outbox (geschrieben von den Server-Funktionen) – der Aufrufer kann weder Empfänger noch Text wählen,
// und claim_push_outbox gibt jede Nachricht nur einmal heraus.
// Zweiter Weg: Der Wartungsjob (private.dispatch_bot_push, über pg_net) schickt den Header x-cron-secret = CRON_SECRET
// und lässt so die Nachrichten der Bot-Spieler verschicken (angenommene Freundschaftsanfragen).
// Deshalb ohne JWT-Prüfung des Gateways deployen (--no-verify-jwt); die Function prüft selbst.
// Anfrage: POST (ohne Inhalt)   Antwort: 200 { sent: number }
import { adminClient, cors, currentUser, json } from "../_shared/common.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";
import { type Deliver, message, type PushKind, pushSender, type PushTarget } from "../_shared/push.ts";

interface Claimed extends PushTarget { kind: PushKind; actor_name: string }

export async function handle(req: Request, admin: SupabaseClient = adminClient(), deliver: Deliver = pushSender(),
                             env: (k: string) => string | undefined = (k) => Deno.env.get(k)): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  try {
    const cronSecret = env("CRON_SECRET") ?? "";
    const fromCron = cronSecret.length >= 32 && timingSafeEqual(req.headers.get("x-cron-secret") ?? "", cronSecret);
    const uid = fromCron ? null : await currentUser(req, admin);
    if (!fromCron && !uid) return json({ error: "not_authenticated" }, 401);
    const { data, error } = fromCron
      ? await admin.rpc("claim_bot_push_outbox")
      : await admin.rpc("claim_push_outbox", { p_actor: uid });
    if (error) throw error;
    const rows = (data ?? []) as Claimed[];
    const results = await Promise.all(rows.map((r) => deliver(r, message(r.kind, r.actor_name, r.locale))));
    const gone = rows.filter((_, i) => results[i] === "gone").map((r) => r.token);
    if (gone.length) {
      const { error: dropError } = await admin.rpc("drop_push_tokens", { p_tokens: gone });
      if (dropError) console.error("push-dispatch: drop tokens", dropError);
    }
    return json({ sent: results.filter((r) => r === "ok").length });
  } catch (e) {
    console.error("push-dispatch", e);
    return json({ error: "server_error" }, 500);
  }
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
