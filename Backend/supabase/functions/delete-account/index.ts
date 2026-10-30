// Rook Raid – Edge Function „delete-account“ (Apple-Pflicht: Konto in der App löschen)
// Löscht den Auth-Nutzer; Profil, Fortschritt und Warteschlangen-Eintrag verschwinden per „on delete cascade“,
// in vergangenen Partien bleibt der Platz leer (white/black = null).
// Anfrage: POST {}   Antwort: 200 { ok: true }
import { adminClient, cors, currentUser, json } from "../_shared/common.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const admin = adminClient();
    const uid = await currentUser(req, admin);
    if (!uid) return json({ error: "not_authenticated" }, 401);
    const { error } = await admin.auth.admin.deleteUser(uid);
    if (error) throw error;
    return json({ ok: true });
  } catch (e) {
    console.error("delete-account", e);
    return json({ error: "server_error" }, 500);
  }
});
