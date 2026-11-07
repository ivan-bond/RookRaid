// Rook Raid – Edge Function „delete-account“ (Apple-Pflicht: Konto in der App löschen)
// Löscht den Auth-Nutzer; Profil, Fortschritt und Warteschlangen-Eintrag verschwinden per „on delete cascade“,
// in vergangenen Partien bleibt der Platz leer (white/black = null).
// Mit Apple gesicherte Konten: Die App schickt einen frischen Autorisierungscode mit, damit hier zuerst
// „Sign in with Apple“ widerrufen wird (Richtlinie 5.1.1(v)). Klappt das nicht, wird trotzdem gelöscht –
// Löschen darf nie an Apple scheitern; der Fehler steht im Log und in der Antwort.
// Anfrage: POST { apple_authorization_code?: string }
// Antwort: 200 { ok: true, apple_revoked: boolean | null }   (null = kein Apple-Code geschickt)
import { adminClient, cors, currentUser, json } from "../_shared/common.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";
import { type AppleRevoker, appleRevoker } from "./apple.ts";

export async function handle(req: Request, admin: SupabaseClient = adminClient(), revoke: AppleRevoker = appleRevoker()): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const uid = await currentUser(req, admin);
    if (!uid) return json({ error: "not_authenticated" }, 401);

    const body = await req.json().catch(() => null) as { apple_authorization_code?: unknown } | null;
    const code = typeof body?.apple_authorization_code === "string" && body.apple_authorization_code.length <= 1024
      ? body.apple_authorization_code : null;
    let appleRevoked: boolean | null = null;
    if (code) {
      try {
        await revoke(code);
        appleRevoked = true;
      } catch (e) {
        console.error("delete-account: apple revoke", e);
        appleRevoked = false;
      }
    }

    const { error } = await admin.auth.admin.deleteUser(uid);
    if (error) throw error;
    return json({ ok: true, apple_revoked: appleRevoked });
  } catch (e) {
    console.error("delete-account", e);
    return json({ error: "server_error" }, 500);
  }
}
