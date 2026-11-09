// Rook Raid – Edge Function „push-dispatch“: verschickt die Push-Nachrichten, die der Aufrufer ausgelöst hat.
// Die App ruft sie direkt nach einer Freundschaftsanfrage oder -annahme auf. Was verschickt wird, steht nur in
// push_outbox (geschrieben von den Server-Funktionen) – der Aufrufer kann weder Empfänger noch Text wählen,
// und claim_push_outbox gibt jede Nachricht nur einmal heraus.
// Anfrage: POST (ohne Inhalt)   Antwort: 200 { sent: number }
import { adminClient, cors, currentUser, json } from "../_shared/common.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";
import { type Deliver, message, type PushKind, pushSender, type PushTarget } from "../_shared/push.ts";

interface Claimed extends PushTarget { kind: PushKind; actor_name: string }

export async function handle(req: Request, admin: SupabaseClient = adminClient(), deliver: Deliver = pushSender()): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  try {
    const uid = await currentUser(req, admin);
    if (!uid) return json({ error: "not_authenticated" }, 401);
    const { data, error } = await admin.rpc("claim_push_outbox", { p_actor: uid });
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
