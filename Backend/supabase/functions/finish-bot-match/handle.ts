// Rook Raid – Edge Function „finish-bot-match“
// Bot-Ersatz-Partien laufen komplett auf dem Gerät (der Bot rechnet lokal). Am Ende schickt die App alle Aktionen;
// der Server spielt sie mit dem Regel-Port nach und wertet nur, was die Regeln hergeben:
//   - Matt / Patt / 50 Züge / Wiederholung aus der Stellung selbst,
//   - „resigned“ oder „timeout“ nur als Niederlage des Menschen (der Bot gibt nie auf und hat immer Zeit).
// Anfrage: POST { match_id, actions: string[], outcome: "final" | "resigned" | "timeout" }
// Antwort: 200 { status, result, winner, trophy_delta_white, trophy_delta_black } | 4xx { error }
import { adminClient, type Color, cors, currentUser, json, other, R, rulesFor, startState, terminal } from "../_shared/common.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";

const MAX_ACTIONS = 800;

export async function handle(req: Request, admin: SupabaseClient = adminClient()): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const uid = await currentUser(req, admin);
    if (!uid) return json({ error: "not_authenticated" }, 401);

    const body = await req.json().catch(() => null);
    const { match_id, actions, outcome } = body ?? {};
    if (typeof match_id !== "string" || !Array.isArray(actions) || actions.length > MAX_ACTIONS ||
        !actions.every((a: unknown) => typeof a === "string" && a.length <= 32) ||
        !["final", "resigned", "timeout"].includes(outcome)) {
      return json({ error: "bad_request" }, 400);
    }

    const { data: m, error: mErr } = await admin.from("matches").select("*").eq("id", match_id).maybeSingle();
    if (mErr) throw mErr;
    if (!m) return json({ error: "not_found" }, 404);
    if (!m.is_bot) return json({ error: "not_a_bot_match" }, 409);
    if (m.status !== "active") return json({ error: "not_active", status: m.status, result: m.result }, 409);
    const human: Color | null = m.white === uid ? "white" : m.black === uid ? "black" : null;
    if (!human) return json({ error: "not_participant" }, 403);
    const bot = other(human);

    const rules = await rulesFor(admin, m.rules_version);
    // ── ab hier kein await bis zum Speichern (applyRules setzt globale Regeltabellen) ──
    const state = startState(rules, m.setup);
    const rows: { match_id: string; ply: number; actor: string | null; code: string }[] = [];
    for (let i = 0; i < actions.length; i++) {
      const mover = R.side(state);
      if (!R.apply(state, actions[i])) return json({ error: "illegal_action", failed_at: i }, 422);
      rows.push({ match_id, ply: i, actor: mover === human ? uid : null, code: actions[i] });
    }
    let end = terminal(state);
    if (!end.result) {
      if (outcome === "resigned") end = { result: "resigned", winner: bot };
      else if (outcome === "timeout" && R.side(state) === human) end = { result: "timeout", winner: bot };
      else return json({ error: "not_finished" }, 422);
    }
    // ─────────────────────────────────────────────────────────────────────────────

    if (rows.length) {
      const { error: iErr } = await admin.from("match_actions").insert(rows);
      if (iErr) throw iErr;
    }
    const { data: res, error: fErr } = await admin.rpc("finish_match", {
      p_match: match_id, p_result: end.result, p_winner: end.winner,
    });
    if (fErr) throw fErr;
    return json(res);
  } catch (e) {
    console.error("finish-bot-match", e);
    return json({ error: "server_error" }, 500);
  }
}
