// Rook Raid – Edge Function „send-feedback“ (Profile → Feedback)
// Stores the message (public.save_feedback: checks it, at most 5 an hour per device or account) and emails it
// to FEEDBACK_TO (default rookraidchess@gmail.com) through Resend. Guests without an account may send too,
// so the function is deployed with --no-verify-jwt; a player's token, if sent, adds the account to the mail.
// Request: POST { category: 'bug'|'balance'|'idea'|'other', message, contact?, meta? }
// Reply:   200 { ok: true, emailed }  ·  400 invalid  ·  429 rate_limited  ·  500 server_error
// Secrets: RESEND_API_KEY (without it the message is only stored), optional FEEDBACK_TO and FEEDBACK_FROM.
import { adminClient, cors, currentUser, json } from "../_shared/common.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";

export interface Mail { subject: string; text: string; replyTo?: string }
export type Mailer = (mail: Mail) => Promise<void>;

const CATEGORIES: Record<string, string> = { bug: "Bug", balance: "Balance", idea: "Idea / feature", other: "Other" };
const META_KEYS = ["platform", "app_version", "language", "player_name", "trophies", "device"];

/// Resend (https://resend.com). Without a verified domain Resend only delivers to the account's own address,
/// so the Resend account should belong to rookraidchess@gmail.com. Null when no key is set.
export function resendMailer(): Mailer | null {
  const key = Deno.env.get("RESEND_API_KEY");
  if (!key) return null;
  const to = Deno.env.get("FEEDBACK_TO") ?? "rookraidchess@gmail.com";
  const from = Deno.env.get("FEEDBACK_FROM") ?? "Rook Raid Feedback <onboarding@resend.dev>";
  return async (mail) => {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from, to: [to], subject: mail.subject, text: mail.text, ...(mail.replyTo ? { reply_to: mail.replyTo } : {}) }),
    });
    if (!res.ok) throw new Error(`resend ${res.status}: ${(await res.text()).slice(0, 300)}`);
  };
}

async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

function clientIp(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for") ?? "";
  return fwd.split(",")[0].trim() || req.headers.get("cf-connecting-ip") || "unknown";
}

export async function handle(req: Request, admin: SupabaseClient = adminClient(), mailer: Mailer | null = resendMailer()): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  try {
    const body = await req.json().catch(() => null) as Record<string, unknown> | null;
    const category = typeof body?.category === "string" ? body.category : "";
    const message = typeof body?.message === "string" ? body.message.trim() : "";
    const contact = typeof body?.contact === "string" ? body.contact.trim().slice(0, 200) : "";
    if (!(category in CATEGORIES) || message.length < 3 || message.length > 4000) return json({ error: "invalid" }, 400);
    const rawMeta = (body?.meta && typeof body.meta === "object") ? body.meta as Record<string, unknown> : {};
    const meta: Record<string, string | number> = {};
    for (const k of META_KEYS) {
      const v = rawMeta[k];
      if (typeof v === "number" && Number.isFinite(v)) meta[k] = v;
      else if (typeof v === "string" && v) meta[k] = v.slice(0, 80);
    }

    const uid = await currentUser(req, admin);
    const ipHash = await sha256(`rookraid-feedback:${clientIp(req)}`);
    const { data: id, error } = await admin.rpc("save_feedback", {
      p_user: uid, p_ip_hash: ipHash, p_category: category, p_message: message, p_contact: contact || null, p_meta: meta,
    });
    if (error) {
      if (/rate_limited/.test(error.message)) return json({ error: "rate_limited" }, 429);
      if (/invalid/.test(error.message)) return json({ error: "invalid" }, 400);
      throw error;
    }

    let emailed = false;
    if (mailer) {
      const firstLine = message.split("\n")[0].slice(0, 60);
      const lines = [
        message, "", "—",
        `Category: ${CATEGORIES[category]}`,
        `Contact: ${contact || "–"}`,
        `Account: ${uid ?? "guest"}`,
        ...Object.entries(meta).map(([k, v]) => `${k}: ${v}`),
        `Feedback id: ${id}`,
      ];
      try {
        await mailer({
          subject: `[Rook Raid ${CATEGORIES[category]}] ${firstLine}`,
          text: lines.join("\n"),
          replyTo: /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contact) ? contact : undefined,
        });
        emailed = true;
        await admin.rpc("mark_feedback_emailed", { p_id: id });
      } catch (e) {
        console.error("send-feedback: mail", e);   // stored anyway – it can be read in the dashboard
      }
    }
    return json({ ok: true, emailed });
  } catch (e) {
    console.error("send-feedback", e);
    return json({ error: "server_error" }, 500);
  }
}
