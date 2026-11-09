// Push-Nachrichten an iPhones (APNs) und Browser (Web Push mit VAPID, Inhalt verschlüsselt nach RFC 8291).
// Geheimnisse (Supabase → Edge Functions → Secrets); fehlt eins, wird diese Plattform still übersprungen:
//   APNS_KEY_ID        ID des APNs-Schlüssels (Apple Developer → Keys, „Apple Push Notifications service“)
//   APNS_TEAM_ID       z. B. X2XXYAQYX6
//   APNS_PRIVATE_KEY   Inhalt der .p8-Datei
//   APNS_TOPIC         Bundle-ID (Standard: com.ivan.rookraid)
//   VAPID_PUBLIC_KEY   öffentlicher VAPID-Schlüssel (base64url, 65 Byte) – derselbe wie VITE_VAPID_PUBLIC_KEY im Browser
//   VAPID_PRIVATE_KEY  privater VAPID-Schlüssel (base64url, 32 Byte)
//   VAPID_SUBJECT      Kontakt für die Push-Dienste, z. B. mailto:support@deine-domain
import { b64url, fromB64url, importP8, signES256 } from "./jwt.ts";

export type PushKind = "friend_request" | "friend_accepted";
export interface PushTarget {
  token: string;
  platform: "ios" | "web";
  environment: "sandbox" | "production" | null;
  subscription: { endpoint: string; keys: { p256dh: string; auth: string } } | null;
  locale: string;
}
export interface PushMessage { title: string; body: string; kind: PushKind }
/** ok = zugestellt, gone = Gerät abgemeldet (löschen), skipped = Plattform nicht eingerichtet, error = später egal */
export type PushResult = "ok" | "gone" | "skipped" | "error";
export type Deliver = (target: PushTarget, message: PushMessage) => Promise<PushResult>;

// Dieselben Texte wie in RookRaid/Localization (Schlüssel = Deutsch). {0} = Name.
const TEXTS: Record<PushKind, Record<string, [string, string]>> = {
  friend_request: {
    de: ["Neue Freundschaftsanfrage", "{0} möchte mit dir befreundet sein."],
    en: ["New friend request", "{0} wants to be your friend."],
    fr: ["Nouvelle demande d'ami", "{0} veut devenir ton ami."],
    es: ["Nueva solicitud de amistad", "{0} quiere ser tu amigo."],
    it: ["Nuova richiesta di amicizia", "{0} vuole essere tuo amico."],
    ru: ["Новая заявка в друзья", "{0} хочет добавить тебя в друзья."],
    zh: ["新的好友请求", "{0} 想和你成为好友。"],
  },
  friend_accepted: {
    de: ["Neuer Freund!", "{0} hat deine Freundschaftsanfrage angenommen."],
    en: ["New friend!", "{0} accepted your friend request."],
    fr: ["Nouvel ami !", "{0} a accepté ta demande d'ami."],
    es: ["¡Nuevo amigo!", "{0} ha aceptado tu solicitud de amistad."],
    it: ["Nuovo amico!", "{0} ha accettato la tua richiesta di amicizia."],
    ru: ["Новый друг!", "{0} принял(а) твою заявку в друзья."],
    zh: ["新好友！", "{0} 接受了你的好友请求。"],
  },
};

export function message(kind: PushKind, name: string, locale: string): PushMessage {
  const [title, body] = TEXTS[kind][locale] ?? TEXTS[kind].en;
  return { kind, title, body: body.replace("{0}", name) };
}

// ───────────────────────── APNs ─────────────────────────
let apnsJwt: { token: string; at: number; keyId: string } | null = null;

/** Apple will höchstens alle 20 Minuten ein neues Token und lehnt Tokens älter als 1 Stunde ab: 50 Minuten behalten. */
async function apnsToken(teamId: string, keyId: string, pem: string, now: number): Promise<string> {
  if (apnsJwt && apnsJwt.keyId === keyId && now - apnsJwt.at < 50 * 60_000) return apnsJwt.token;
  const token = await signES256(await importP8(pem), { alg: "ES256", kid: keyId }, { iss: teamId, iat: Math.floor(now / 1000) });
  apnsJwt = { token, at: now, keyId };
  return token;
}

export function apnsRequest(target: PushTarget, msg: PushMessage, jwt: string, topic: string): { url: string; init: RequestInit } {
  const host = target.environment === "sandbox" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  return {
    url: `https://${host}/3/device/${target.token}`,
    init: {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": topic,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-expiration": String(Math.floor(Date.now() / 1000) + 86400),
        "content-type": "application/json",
      },
      body: JSON.stringify({
        aps: { alert: { title: msg.title, body: msg.body }, sound: "default", "thread-id": "friends" },
        type: "friends",
      }),
    },
  };
}

// ───────────────────────── Web Push ─────────────────────────
const enc = new TextEncoder();
function concat(...parts: Uint8Array[]): Uint8Array<ArrayBuffer> {
  const out = new Uint8Array(new ArrayBuffer(parts.reduce((n, p) => n + p.length, 0)));
  let i = 0;
  for (const p of parts) { out.set(p, i); i += p.length; }
  return out;
}
async function hmac(key: Uint8Array<ArrayBuffer>, data: Uint8Array<ArrayBuffer>): Promise<Uint8Array<ArrayBuffer>> {
  const k = await crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", k, data));
}

/** Inhalt verschlüsseln (RFC 8291, aes128gcm). `serverKeys`/`salt` nur für Tests vorgeben. */
export async function encryptWebPush(
  payload: Uint8Array, p256dh: string, auth: string,
  serverKeys?: CryptoKeyPair, salt: Uint8Array<ArrayBuffer> = crypto.getRandomValues(new Uint8Array(new ArrayBuffer(16))),
): Promise<Uint8Array<ArrayBuffer>> {
  const uaPublic = fromB64url(p256dh);
  const authSecret = fromB64url(auth);
  const keys = serverKeys ?? await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"]) as CryptoKeyPair;
  const asPublic = new Uint8Array(await crypto.subtle.exportKey("raw", keys.publicKey));
  const uaKey = await crypto.subtle.importKey("raw", uaPublic, { name: "ECDH", namedCurve: "P-256" }, false, []);
  const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: "ECDH", public: uaKey }, keys.privateKey, 256));
  const prkKey = await hmac(authSecret, ecdh);
  const ikm = await hmac(prkKey, concat(enc.encode("WebPush: info\0"), uaPublic, asPublic, new Uint8Array([1])));
  const prk = await hmac(salt, ikm);
  const cek = (await hmac(prk, concat(enc.encode("Content-Encoding: aes128gcm\0"), new Uint8Array([1])))).slice(0, 16);
  const nonce = (await hmac(prk, concat(enc.encode("Content-Encoding: nonce\0"), new Uint8Array([1])))).slice(0, 12);
  const aes = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["encrypt"]);
  const cipher = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, aes, concat(payload, new Uint8Array([2]))));
  const header = new Uint8Array(new ArrayBuffer(21));
  header.set(salt, 0);
  new DataView(header.buffer).setUint32(16, 4096);
  header[20] = asPublic.length;
  return concat(header, asPublic, cipher);
}

/** VAPID-Schlüssel als WebCrypto-Schlüssel (privat: 32 Byte d, öffentlich: 65 Byte 04‖x‖y). */
export function importVapid(publicKey: string, privateKey: string): Promise<CryptoKey> {
  const pub = fromB64url(publicKey);
  return crypto.subtle.importKey("jwk", {
    kty: "EC", crv: "P-256", d: privateKey, x: b64url(pub.slice(1, 33)), y: b64url(pub.slice(33, 65)), ext: false,
  }, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}

export async function webPushRequest(
  sub: NonNullable<PushTarget["subscription"]>, msg: PushMessage,
  vapid: { publicKey: string; key: CryptoKey; subject: string }, now = Date.now(),
): Promise<{ url: string; init: RequestInit }> {
  const aud = new URL(sub.endpoint).origin;
  const jwt = await signES256(vapid.key, { typ: "JWT", alg: "ES256" }, { aud, exp: Math.floor(now / 1000) + 12 * 3600, sub: vapid.subject });
  const body = await encryptWebPush(enc.encode(JSON.stringify({ title: msg.title, body: msg.body, url: "/?friends=1", tag: msg.kind })),
    sub.keys.p256dh, sub.keys.auth);
  return {
    url: sub.endpoint,
    init: {
      method: "POST",
      headers: {
        authorization: `vapid t=${jwt}, k=${vapid.publicKey}`,
        "content-encoding": "aes128gcm",
        "content-type": "application/octet-stream",
        ttl: "86400",
        urgency: "normal",
      },
      body,
    },
  };
}

// ───────────────────────── Versand ─────────────────────────
export function pushSender(env: (k: string) => string | undefined = (k) => Deno.env.get(k), http: typeof fetch = fetch): Deliver {
  let vapidKey: Promise<CryptoKey> | null = null;
  return async (target, msg) => {
    try {
      if (target.platform === "ios") {
        const keyId = env("APNS_KEY_ID"), teamId = env("APNS_TEAM_ID"), pem = env("APNS_PRIVATE_KEY");
        if (!keyId || !teamId || !pem) return "skipped";
        const jwt = await apnsToken(teamId, keyId, pem, Date.now());
        const { url, init } = apnsRequest(target, msg, jwt, env("APNS_TOPIC") || "com.ivan.rookraid");
        const res = await http(url, init);
        if (res.ok) return "ok";
        const reason = (await res.json().catch(() => ({})) as { reason?: string }).reason;
        if (res.status === 410 || reason === "BadDeviceToken" || reason === "Unregistered" || reason === "DeviceTokenNotForTopic") return "gone";
        console.error("push-dispatch: apns", res.status, reason);
        return "error";
      }
      const pub = env("VAPID_PUBLIC_KEY"), priv = env("VAPID_PRIVATE_KEY");
      if (!pub || !priv || !target.subscription) return "skipped";
      vapidKey ??= importVapid(pub, priv);
      const { url, init } = await webPushRequest(target.subscription, msg,
        { publicKey: pub, key: await vapidKey, subject: env("VAPID_SUBJECT") || "mailto:support@rookraid.app" });
      const res = await http(url, init);
      await res.body?.cancel();
      if (res.ok) return "ok";
      if (res.status === 404 || res.status === 410) return "gone";
      console.error("push-dispatch: web push", res.status);
      return "error";
    } catch (e) {
      console.error("push-dispatch", e);
      return "error";
    }
  };
}
