// Rook Raid – gemeinsame Hilfen für die Edge Functions (Deno).
// Regeln: rookraid-rules.mjs ist GENERIERT (node Tools/rules-js/build-server.js) – derselbe Regelstand wie die App.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";
import * as R from "./rookraid-rules.mjs";

export { R };
export type Color = "white" | "black";

export const cors: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

/// Client mit Service-Rolle: umgeht die Zugriffsregeln – nur auf dem Server verwenden.
export function adminClient(): SupabaseClient {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/// Angemeldeter Spieler aus dem Authorization-Header (JWT der App) – oder null.
export async function currentUser(req: Request, admin: SupabaseClient): Promise<string | null> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user.id;
}

// Regeln je Version zwischenspeichern (eine Function-Instanz bedient viele Anfragen)
const rulesCache = new Map<number, unknown>();

export async function rulesFor(admin: SupabaseClient, version: number): Promise<unknown> {
  const hit = rulesCache.get(version);
  if (hit) return hit;
  const { data, error } = await admin.from("rules_config").select("config").eq("version", version).single();
  if (error || !data) throw new Error(`Regel-Version ${version} fehlt in rules_config`);
  rulesCache.set(version, data.config);
  return data.config;
}

export interface MatchSetup {
  decks: { white: string[]; black: string[] };
  ultimates: { white?: string; black?: string };
}

/// Regeln setzen und die Grundstellung der Partie bauen. WICHTIG: applyRules ändert globale Tabellen des Ports –
/// zwischen applyRules und dem Ende des Nachspielens darf kein await stehen.
// deno-lint-ignore no-explicit-any
export function startState(rules: unknown, setup: MatchSetup): any {
  R.applyRules(rules);
  return R.initialFromRecord(setup);
}

/// Partieende nach der letzten Aktion: Ergebnis und Sieger (null = Remis) – oder result null, wenn es weitergeht.
// deno-lint-ignore no-explicit-any
export function terminal(state: any): { result: string | null; winner: Color | null } {
  const st = state.status();
  if (st === "mate") return { result: "mate", winner: R.side(state) === "white" ? "black" : "white" };
  if (st === "stalemate" || st === "fifty" || st === "repetition") return { result: st, winner: null };
  return { result: null, winner: null };
}

export const other = (c: Color): Color => (c === "white" ? "black" : "white");
