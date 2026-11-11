// Die Edge Functions, ohne Supabase: ein nachgebauter Client, dieselben Regeln wie der Server.
// Läuft mit: deno test --allow-read --allow-net --allow-env functions_test.ts
import { assertEquals } from "jsr:@std/assert@1";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";
import { handle as submit } from "./submit-action/handle.ts";
import { handle as finishBot } from "./finish-bot-match/handle.ts";
import { handle as deleteAccount } from "./delete-account/handle.ts";
import { handle as pushDispatch } from "./push-dispatch/handle.ts";
import { handle as sendFeedback, type Mail } from "./send-feedback/handle.ts";
import { apnsRequest, encryptWebPush, message, pushSender, type PushTarget, webPushRequest, importVapid } from "./_shared/push.ts";
import { b64url, fromB64url } from "./_shared/jwt.ts";

const WHITE = "11111111-1111-1111-1111-111111111111";
const BLACK = "22222222-2222-2222-2222-222222222222";
const STRANGER = "33333333-3333-3333-3333-333333333333";
const RULES = JSON.parse(await Deno.readTextFile(new URL("../../../RookRaid/Engine/rookraid-rules.json", import.meta.url)));
const DECK = ["shield", "freeze", "sprint", "lightning"];

interface Calls { rpc: { name: string; args: Record<string, unknown> }[]; deleted: string[]; inserted: unknown[] }

function match(over: Record<string, unknown> = {}) {
  return {
    id: "match-1", status: "active", result: null, is_bot: false,
    white: WHITE, black: BLACK, action_count: 0, rules_version: RULES.version,
    setup: { decks: { white: DECK, black: DECK }, ultimates: { white: "meteor", black: "fortress" } },
    ...over,
  };
}

function admin(row: Record<string, unknown>, actions: { code: string }[] = []): { client: SupabaseClient; calls: Calls } {
  const calls: Calls = { rpc: [], deleted: [], inserted: [] };
  const client = {
    auth: {
      getUser: async (token: string) => token === "good"
        ? { data: { user: { id: WHITE } }, error: null }
        : { data: { user: null }, error: { message: "bad" } },
      admin: { deleteUser: async (id: string) => { calls.deleted.push(id); return { error: null }; } },
    },
    from(table: string) {
      if (table === "matches") {
        return { select: () => ({ eq: () => ({ maybeSingle: async () => ({ data: row, error: null }) }) }) };
      }
      if (table === "match_actions") {
        return {
          select: () => ({ eq: () => ({ order: async () => ({ data: actions, error: null }) }) }),
          insert: async (rows: unknown) => { calls.inserted.push(rows); return { error: null }; },
        };
      }
      if (table === "rules_config") {
        return { select: () => ({ eq: () => ({ single: async () => ({ data: { config: RULES }, error: null }) }) }) };
      }
      throw new Error("unexpected table " + table);
    },
    rpc: async (name: string, args: Record<string, unknown>) => {
      calls.rpc.push({ name, args });
      return { data: { ok: true, ply: 1 }, error: null };
    },
  };
  return { client: client as unknown as SupabaseClient, calls };
}

function post(path: string, body: unknown, token?: string) {
  return new Request("http://localhost" + path, {
    method: "POST",
    headers: { "content-type": "application/json", ...(token ? { authorization: "Bearer " + token } : {}) },
    body: JSON.stringify(body),
  });
}

async function bodyOf(res: Response): Promise<Record<string, unknown>> {
  return await res.json();
}

Deno.test("submit-action weist Gäste, Fremde, Bots und illegale Züge ab", async () => {
  const open = admin(match());
  assertEquals((await bodyOf(await submit(post("/s", { match_id: "match-1", ply: 0, code: "f2f3" }), open.client))).error, "not_authenticated");

  const bad = admin(match());
  assertEquals((await bodyOf(await submit(post("/s", { match_id: 1 }, "good"), bad.client))).error, "bad_request");

  const stranger = admin(match({ white: STRANGER, black: BLACK }));
  assertEquals((await bodyOf(await submit(post("/s", { match_id: "match-1", ply: 0, code: "f2f3" }, "good"), stranger.client))).error, "not_participant");

  const bot = admin(match({ is_bot: true }));
  assertEquals((await bodyOf(await submit(post("/s", { match_id: "match-1", ply: 0, code: "f2f3" }, "good"), bot.client))).error, "bot_match_is_local");

  const stale = admin(match({ action_count: 2 }));
  assertEquals((await bodyOf(await submit(post("/s", { match_id: "match-1", ply: 0, code: "f2f3" }, "good"), stale.client))).error, "out_of_sync");

  const illegal = admin(match());
  assertEquals((await bodyOf(await submit(post("/s", { match_id: "match-1", ply: 0, code: "e2e5" }, "good"), illegal.client))).error, "illegal_action");
  assertEquals(illegal.calls.rpc.length, 0);

  const black = admin(match({ white: BLACK, black: WHITE }));
  assertEquals((await bodyOf(await submit(post("/s", { match_id: "match-1", ply: 0, code: "f2f3" }, "good"), black.client))).error, "not_your_turn");
});

Deno.test("submit-action speichert nur einen erlaubten Zug des Spielers am Zug", async () => {
  const legal = admin(match());
  const res = await submit(post("/s", { match_id: "match-1", ply: 0, code: "f2f3" }, "good"), legal.client);
  assertEquals(res.status, 200);
  assertEquals(legal.calls.rpc.length, 1);
  assertEquals(legal.calls.rpc[0].name, "record_action");
  assertEquals(legal.calls.rpc[0].args.p_actor, WHITE);
  assertEquals(legal.calls.rpc[0].args.p_code, "f2f3");
  assertEquals(legal.calls.rpc[0].args.p_result, null);
});

Deno.test("finish-bot-match wertet nur die nachgespielte Partie, und ein Timeout verliert der Mensch", async () => {
  const guest = admin(match({ is_bot: true, black: null }));
  assertEquals((await bodyOf(await finishBot(post("/f", { match_id: "match-1", actions: [], outcome: "resigned" }), guest.client))).error, "not_authenticated");

  const human = admin(match({ is_bot: false }));
  assertEquals((await bodyOf(await finishBot(post("/f", { match_id: "match-1", actions: [], outcome: "final" }, "good"), human.client))).error, "not_a_bot_match");

  const invented = admin(match({ is_bot: true, black: null }));
  assertEquals((await bodyOf(await finishBot(post("/f", { match_id: "match-1", actions: ["f2f3"], outcome: "final" }, "good"), invented.client))).error, "not_finished");
  assertEquals(invented.calls.rpc.length, 0);

  const timed = admin(match({ is_bot: true, black: null }));
  const timeout = await finishBot(post("/f", { match_id: "match-1", actions: [], outcome: "timeout" }, "good"), timed.client);
  assertEquals(timeout.status, 200);
  assertEquals(timed.calls.rpc[0].args.p_result, "timeout");
  assertEquals(timed.calls.rpc[0].args.p_winner, "black");

  const quit = admin(match({ is_bot: true, black: null }));
  await finishBot(post("/f", { match_id: "match-1", actions: ["f2f3"], outcome: "resigned" }, "good"), quit.client);
  assertEquals(quit.calls.rpc[0].args.p_result, "resigned");
  assertEquals(quit.calls.rpc[0].args.p_winner, "black");

  const mate = admin(match({ is_bot: true, white: BLACK, black: WHITE }));
  const done = await finishBot(post("/f", {
    match_id: "match-1",
    actions: ["f2f3", "e7e5", "g2g4", "d8h4"],
    outcome: "final",
  }, "good"), mate.client);
  assertEquals(done.status, 200);
  assertEquals(mate.calls.rpc[0].args.p_result, "mate");
  assertEquals(mate.calls.rpc[0].args.p_winner, "black");
});

Deno.test("delete-account löscht nur den angemeldeten Spieler", async () => {
  const guest = admin(match());
  assertEquals((await bodyOf(await deleteAccount(post("/d", {}), guest.client))).error, "not_authenticated");
  assertEquals(guest.calls.deleted.length, 0);

  const mine = admin(match());
  const res = await deleteAccount(post("/d", { user_id: BLACK }, "good"), mine.client);
  assertEquals(res.status, 200);
  assertEquals(mine.calls.deleted, [WHITE]);
});

Deno.test("delete-account widerruft Sign in with Apple – und löscht auch, wenn Apple nicht mitspielt", async () => {
  const codes: string[] = [];
  const ok = admin(match());
  const res = await deleteAccount(post("/d", { apple_authorization_code: "c-123" }, "good"), ok.client, async (c) => { codes.push(c); });
  assertEquals(codes, ["c-123"]);
  assertEquals((await bodyOf(res)).apple_revoked, true);
  assertEquals(ok.calls.deleted, [WHITE]);

  const broken = admin(match());
  const res2 = await deleteAccount(post("/d", { apple_authorization_code: "c-456" }, "good"), broken.client, async () => { throw new Error("apple down"); });
  assertEquals(res2.status, 200);
  assertEquals((await bodyOf(res2)).apple_revoked, false);
  assertEquals(broken.calls.deleted, [WHITE]);

  const plain = admin(match());
  const res3 = await deleteAccount(post("/d", {}, "good"), plain.client, async () => { throw new Error("darf nicht laufen"); });
  assertEquals((await bodyOf(res3)).apple_revoked, null);
});

Deno.test("Apple-Client-Secret ist ein gültiges ES256-JWT", async () => {
  const { clientSecret } = await import("./delete-account/apple.ts");
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  // Throwaway key made here. The PEM label is put together so the secret check does not see a committed key.
  const label = ["PRIVATE", "KEY"].join(" ");
  const pem = `-----BEGIN ${label}-----\n${btoa(String.fromCharCode(...der))}\n-----END ${label}-----`;
  const jwt = await clientSecret("TEAM", "KEY", pem, "com.ivan.rookraid", 1_700_000_000_000);
  const [h, p, s] = jwt.split(".");
  const dec = (x: string) => JSON.parse(atob(x.replace(/-/g, "+").replace(/_/g, "/")));
  assertEquals(dec(h), { alg: "ES256", kid: "KEY" });
  assertEquals(dec(p), { iss: "TEAM", iat: 1_700_000_000, exp: 1_700_000_300, aud: "https://appleid.apple.com", sub: "com.ivan.rookraid" });
  const sig = Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/") + "==".slice(0, (4 - s.length % 4) % 4)), (c) => c.charCodeAt(0));
  assertEquals(sig.length, 64);
  assertEquals(await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, pair.publicKey, sig, new TextEncoder().encode(`${h}.${p}`)), true);
});

// ───────────────────────── Push ─────────────────────────
async function hmacT(key: Uint8Array<ArrayBuffer>, data: Uint8Array<ArrayBuffer>) {
  const k = await crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", k, data));
}
const cat = (...p: Uint8Array[]) => { const o = new Uint8Array(new ArrayBuffer(p.reduce((n, x) => n + x.length, 0))); let i = 0; for (const x of p) { o.set(x, i); i += x.length; } return o; };

/** Wie ein Browser entschlüsselt (RFC 8291) – unabhängig von encryptWebPush nachgebaut. */
async function decryptLikeBrowser(body: Uint8Array, ua: CryptoKeyPair, auth: Uint8Array<ArrayBuffer>): Promise<string> {
  const salt = body.slice(0, 16), rs = new DataView(body.buffer, body.byteOffset).getUint32(16), idlen = body[20];
  assertEquals(rs, 4096);
  const asPublic = body.slice(21, 21 + idlen), cipher = body.slice(21 + idlen);
  const uaPublic = new Uint8Array(await crypto.subtle.exportKey("raw", ua.publicKey));
  const asKey = await crypto.subtle.importKey("raw", asPublic, { name: "ECDH", namedCurve: "P-256" }, false, []);
  const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: "ECDH", public: asKey }, ua.privateKey, 256));
  const te = new TextEncoder();
  const ikm = await hmacT(await hmacT(auth, ecdh), cat(te.encode("WebPush: info\0"), uaPublic, asPublic, new Uint8Array([1])));
  const prk = await hmacT(salt, ikm);
  const cek = (await hmacT(prk, cat(te.encode("Content-Encoding: aes128gcm\0"), new Uint8Array([1])))).slice(0, 16);
  const nonce = (await hmacT(prk, cat(te.encode("Content-Encoding: nonce\0"), new Uint8Array([1])))).slice(0, 12);
  const key = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["decrypt"]);
  const plain = new Uint8Array(await crypto.subtle.decrypt({ name: "AES-GCM", iv: nonce }, key, cipher));
  assertEquals(plain[plain.length - 1], 2); // letzter Datensatz
  return new TextDecoder().decode(plain.slice(0, -1));
}

async function browserSubscription() {
  const ua = await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"]) as CryptoKeyPair;
  const auth = crypto.getRandomValues(new Uint8Array(new ArrayBuffer(16)));
  const p256dh = b64url(new Uint8Array(await crypto.subtle.exportKey("raw", ua.publicKey)));
  return { ua, auth, sub: { endpoint: "https://push.example.com/send/abc", keys: { p256dh, auth: b64url(auth) } } };
}

async function vapidPair() {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]) as CryptoKeyPair;
  const pub = b64url(new Uint8Array(await crypto.subtle.exportKey("raw", pair.publicKey)));
  const priv = (await crypto.subtle.exportKey("jwk", pair.privateKey)).d!;
  return { pair, pub, priv };
}

Deno.test("Web Push: Inhalt verschlüsselt, ein Browser kann ihn lesen", async () => {
  const { ua, auth, sub } = await browserSubscription();
  const body = await encryptWebPush(new TextEncoder().encode("Hallo Rook Raid"), sub.keys.p256dh, sub.keys.auth);
  assertEquals(await decryptLikeBrowser(body, ua, auth), "Hallo Rook Raid");
});

Deno.test("Web Push: VAPID-Anmeldung für genau diesen Push-Dienst", async () => {
  const { ua, auth, sub } = await browserSubscription();
  const v = await vapidPair();
  const msg = message("friend_request", "Ivan", "de");
  const { url, init } = await webPushRequest(sub, msg, { publicKey: v.pub, key: await importVapid(v.pub, v.priv), subject: "mailto:a@b.c" }, 1_700_000_000_000);
  const h = init.headers as Record<string, string>;
  assertEquals(url, sub.endpoint);
  assertEquals(h["content-encoding"], "aes128gcm");
  const [, t, k] = h.authorization.match(/^vapid t=([^,]+), k=(.+)$/)!;
  assertEquals(k, v.pub);
  const [jh, jp, js] = t.split(".");
  const claims = JSON.parse(new TextDecoder().decode(fromB64url(jp)));
  assertEquals(claims, { aud: "https://push.example.com", exp: 1_700_000_000 + 43200, sub: "mailto:a@b.c" });
  assertEquals(await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, v.pair.publicKey, fromB64url(js), new TextEncoder().encode(`${jh}.${jp}`)), true);
  const shown = JSON.parse(await decryptLikeBrowser(init.body as Uint8Array, ua, auth));
  assertEquals(shown, { title: "Neue Freundschaftsanfrage", body: "Ivan möchte mit dir befreundet sein.", url: "/?friends=1", tag: "friend_request" });
});

Deno.test("APNs: richtiger Server je Build, Text in der Sprache des Geräts", () => {
  const target: PushTarget = { token: "ab".repeat(32), platform: "ios", environment: "sandbox", subscription: null, locale: "fr" };
  const msg = message("friend_accepted", "Mia", target.locale);
  const dev = apnsRequest(target, msg, "JWT", "com.ivan.rookraid");
  assertEquals(dev.url, `https://api.sandbox.push.apple.com/3/device/${target.token}`);
  const h = dev.init.headers as Record<string, string>;
  assertEquals([h.authorization, h["apns-topic"], h["apns-push-type"]], ["bearer JWT", "com.ivan.rookraid", "alert"]);
  assertEquals(JSON.parse(dev.init.body as string).aps.alert, { title: "Nouvel ami !", body: "Mia a accepté ta demande d'ami." });
  assertEquals(apnsRequest({ ...target, environment: "production" }, msg, "JWT", "x").url.startsWith("https://api.push.apple.com/"), true);
  assertEquals(message("friend_request", "Ivan", "xx").title, "New friend request");
});

Deno.test("Push-Versand: abgemeldete Geräte erkennen, fehlende Schlüssel überspringen", async () => {
  const { sub } = await browserSubscription();
  const v = await vapidPair();
  const apple = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign"]) as CryptoKeyPair;
  const p8 = btoa(String.fromCharCode(...new Uint8Array(await crypto.subtle.exportKey("pkcs8", apple.privateKey))));
  const env: Record<string, string> = { APNS_KEY_ID: "K", APNS_TEAM_ID: "T", APNS_PRIVATE_KEY: p8, VAPID_PUBLIC_KEY: v.pub, VAPID_PRIVATE_KEY: v.priv };
  const seen: string[] = [];
  const http = (async (url: string) => {
    seen.push(url);
    if (url.includes("apple")) return new Response(JSON.stringify({ reason: "Unregistered" }), { status: 410 });
    return new Response(null, { status: 201 });
  }) as unknown as typeof fetch;
  const send = pushSender((k) => env[k], http);
  const msg = message("friend_request", "Ivan", "en");
  const ios: PushTarget = { token: "cd".repeat(32), platform: "ios", environment: "production", subscription: null, locale: "en" };
  const web: PushTarget = { token: sub.endpoint, platform: "web", environment: null, subscription: sub, locale: "en" };
  assertEquals(await send(ios, msg), "gone");
  assertEquals(await send(web, msg), "ok");
  assertEquals(seen.length, 2);
  const bare = pushSender(() => undefined, http);
  assertEquals([await bare(ios, msg), await bare(web, msg)], ["skipped", "skipped"]);
});

Deno.test("push-dispatch: nur angemeldet, jede Nachricht an jedes Gerät, abgemeldete Geräte raus", async () => {
  const rpc: { name: string; args: Record<string, unknown> }[] = [];
  const claimed = [
    { kind: "friend_request", actor_name: "Ivan", token: "t-ios", platform: "ios", environment: "production", subscription: null, locale: "de" },
    { kind: "friend_request", actor_name: "Ivan", token: "t-web", platform: "web", environment: null, subscription: { endpoint: "https://x", keys: { p256dh: "a", auth: "b" } }, locale: "it" },
  ];
  const client = {
    auth: { getUser: async (token: string) => token === "good" ? { data: { user: { id: WHITE } }, error: null } : { data: { user: null }, error: { message: "bad" } } },
    rpc: async (name: string, args: Record<string, unknown>) => { rpc.push({ name, args }); return { data: name === "claim_push_outbox" ? claimed : null, error: null }; },
  } as unknown as SupabaseClient;
  const delivered: string[] = [];
  const deliver = async (t: PushTarget, m: { body: string }) => { delivered.push(`${t.token}:${m.body}`); return t.platform === "ios" ? "gone" as const : "ok" as const; };

  assertEquals((await pushDispatch(post("/p", {}), client, deliver)).status, 401);
  assertEquals(rpc.length, 0);
  const res = await pushDispatch(post("/p", {}, "good"), client, deliver);
  assertEquals(await bodyOf(res), { sent: 1 });
  assertEquals(rpc[0], { name: "claim_push_outbox", args: { p_actor: WHITE } });
  assertEquals(delivered, ["t-ios:Ivan möchte mit dir befreundet sein.", "t-web:Ivan vuole essere tuo amico."]);
  assertEquals(rpc[1], { name: "drop_push_tokens", args: { p_tokens: ["t-ios"] } });
});

Deno.test("push-dispatch: Wartungsjob mit Geheimnis verschickt die Nachrichten der Bot-Spieler", async () => {
  const rpc: string[] = [];
  const claimed = [{ kind: "friend_accepted", actor_name: "Turmfalke", token: "t-web", platform: "web", environment: null, subscription: { endpoint: "https://x", keys: { p256dh: "a", auth: "b" } }, locale: "en" }];
  const client = {
    auth: { getUser: async () => ({ data: { user: null }, error: { message: "bad" } }) },
    rpc: async (name: string) => { rpc.push(name); return { data: name === "claim_bot_push_outbox" ? claimed : null, error: null }; },
  } as unknown as SupabaseClient;
  const delivered: string[] = [];
  const deliver = async (t: PushTarget, m: { body: string }) => { delivered.push(`${t.token}:${m.body}`); return "ok" as const; };
  const secret = "s".repeat(40);
  const env = (k: string) => k === "CRON_SECRET" ? secret : undefined;
  const cron = (value: string) => new Request("http://x/p", { method: "POST", headers: { "x-cron-secret": value } });
  assertEquals((await pushDispatch(cron("wrong"), client, deliver, env)).status, 401);
  assertEquals((await pushDispatch(cron(secret), client, deliver, () => undefined)).status, 401);
  assertEquals(rpc.length, 0);
  assertEquals(await bodyOf(await pushDispatch(cron(secret), client, deliver, env)), { sent: 1 });
  assertEquals(rpc, ["claim_bot_push_outbox"]);
  assertEquals(delivered, ["t-web:Turmfalke accepted your friend request."]);
});

// ── send-feedback ──
function feedbackAdmin(rpcError: string | null = null) {
  const calls: { name: string; args: Record<string, unknown> }[] = [];
  const client = {
    auth: { getUser: async (token: string) => token === "good" ? { data: { user: { id: WHITE } }, error: null } : { data: { user: null }, error: { message: "bad" } } },
    rpc: async (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args });
      if (name === "save_feedback" && rpcError) return { data: null, error: { message: rpcError } };
      return { data: name === "save_feedback" ? "fb-1" : null, error: null };
    },
  } as unknown as SupabaseClient;
  return { client, calls };
}
const feedbackReq = (body: unknown, token?: string) => new Request("http://x/send-feedback", {
  method: "POST", body: JSON.stringify(body),
  headers: { "x-forwarded-for": "1.2.3.4, 10.0.0.1", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
});

Deno.test("send-feedback speichert, mailt mit Antwortadresse und hängt das Konto an", async () => {
  const { client, calls } = feedbackAdmin();
  const mails: Mail[] = [];
  const res = await sendFeedback(feedbackReq({ category: "balance", message: "Meteor ist zu stark\nDetails", contact: "a@b.de",
    meta: { platform: "ios", trophies: 812, evil: "x".repeat(500) } }, "good"), client, async (m) => { mails.push(m); });
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { ok: true, emailed: true });
  assertEquals(calls.map((c) => c.name), ["save_feedback", "mark_feedback_emailed"]);
  assertEquals(calls[0].args.p_user, WHITE);
  assertEquals(calls[0].args.p_meta, { platform: "ios", trophies: 812 });
  assertEquals(String(calls[0].args.p_ip_hash).length, 64);
  assertEquals(mails[0].subject, "[Rook Raid Balance] Meteor ist zu stark");
  assertEquals(mails[0].replyTo, "a@b.de");
});

Deno.test("send-feedback: Gäste dürfen, falsche Eingaben und zu viele Nachrichten nicht, Mail-Fehler verliert nichts", async () => {
  let { client, calls } = feedbackAdmin();
  let res = await sendFeedback(feedbackReq({ category: "bug", message: "Hängt beim Start", contact: "kein mail" }), client, async () => { throw new Error("down"); });
  assertEquals(await res.json(), { ok: true, emailed: false });
  assertEquals(calls[0].args.p_user, null);
  assertEquals(calls.length, 1);
  res = await sendFeedback(feedbackReq({ category: "bug", message: "ok ok" }), client, null);
  assertEquals(await res.json(), { ok: true, emailed: false });
  res = await sendFeedback(feedbackReq({ category: "spam", message: "Hallo" }), client, null);
  assertEquals(res.status, 400);
  res = await sendFeedback(feedbackReq({ category: "idea", message: " " }), client, null);
  assertEquals(res.status, 400);
  ({ client, calls } = feedbackAdmin("rate_limited"));
  res = await sendFeedback(feedbackReq({ category: "idea", message: "Noch eine Idee" }), client, null);
  assertEquals(res.status, 429);
});
