// Rook Raid – Edge Function „submit-action“
// Ein Zug, eine Karte oder die Ultimate im Draht-Format (e2e4, e7e8q, card:freeze@f6, card:bulwark, ult:meteor@d8).
// Ablauf: Partie laden → alle bisherigen Aktionen mit dem Regel-Port nachspielen → prüfen, dass der Absender am Zug ist
// und die Aktion erlaubt ist → record_action (führt Uhr, Inkrement, Partieende und Trophäen in einer Transaktion).
// Erst danach sieht der Gegner die Aktion (Realtime auf match_actions).
//
// Anfrage:  POST { match_id: uuid, ply: number (= erwartete laufende Nummer), code: string }
// Antwort:  200 { ok, ply, clock_ms, turn } | 200 { ok, ply, finish: {...} }
//           409 { error: out_of_sync, action_count } | { error: not_your_turn } | { error: timeout } | { error: not_active }
//           422 { error: illegal_action }   401 not_authenticated   403 not_participant
import { adminClient, cors, currentUser, json, R, rulesFor, startState, terminal } from "../_shared/common.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const admin = adminClient();
    const uid = await currentUser(req, admin);
    if (!uid) return json({ error: "not_authenticated" }, 401);

    const body = await req.json().catch(() => null);
    const { match_id, ply, code } = body ?? {};
    if (typeof match_id !== "string" || typeof code !== "string" || code.length > 32 || !Number.isInteger(ply)) {
      return json({ error: "bad_request" }, 400);
    }

    const { data: m, error: mErr } = await admin.from("matches").select("*").eq("id", match_id).maybeSingle();
    if (mErr) throw mErr;
    if (!m) return json({ error: "not_found" }, 404);
    if (m.status !== "active") return json({ error: "not_active", status: m.status, result: m.result }, 409);
    if (m.is_bot) return json({ error: "bot_match_is_local" }, 409);
    const color = m.white === uid ? "white" : m.black === uid ? "black" : null;
    if (!color) return json({ error: "not_participant" }, 403);
    if (ply !== m.action_count) return json({ error: "out_of_sync", action_count: m.action_count }, 409);

    const { data: rows, error: aErr } = await admin.from("match_actions").select("code").eq("match_id", match_id).order("ply");
    if (aErr) throw aErr;
    const rules = await rulesFor(admin, m.rules_version);

    // ── ab hier kein await bis record_action (applyRules setzt globale Regeltabellen) ──
    const state = startState(rules, m.setup);
    for (let i = 0; i < rows.length; i++) {
      if (!R.apply(state, rows[i].code)) return json({ error: "corrupt_match", failed_at: i }, 500);
    }
    if (R.side(state) !== color) return json({ error: "not_your_turn" }, 409);
    if (!R.apply(state, code)) return json({ error: "illegal_action" }, 422);
    const end = terminal(state);
    const turnAfter = R.side(state);
    // ─────────────────────────────────────────────────────────────────────────────

    const { data: res, error: rErr } = await admin.rpc("record_action", {
      p_match: match_id, p_ply: ply, p_actor: uid, p_code: code,
      p_turn_after: turnAfter, p_result: end.result, p_winner: end.winner,
    });
    if (rErr) throw rErr;
    if (res?.error) return json(res, 409);
    return json(res);
  } catch (e) {
    console.error("submit-action", e);
    return json({ error: "server_error" }, 500);
  }
});
