// Sign in with Apple widerrufen (App-Store-Pflicht beim Löschen eines Kontos, Richtlinie 5.1.1(v)).
// Ablauf nach https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens:
//   1. Client-Secret bauen: ein mit dem .p8-Schlüssel (ES256) signiertes JWT, 5 Minuten gültig.
//   2. Den frischen Autorisierungscode der App gegen ein Refresh-Token tauschen (/auth/token).
//   3. Das Token widerrufen (/auth/revoke). Danach ist die App bei der Apple-ID des Spielers abgemeldet.
// Geheimnisse (Supabase → Edge Functions → Secrets):
//   APPLE_TEAM_ID       z. B. X2XXYAQYX6
//   APPLE_KEY_ID        ID des „Sign in with Apple“-Schlüssels
//   APPLE_PRIVATE_KEY   Inhalt der .p8-Datei (mit BEGIN/END-Zeilen)
//   APPLE_CLIENT_ID     Bundle-ID der App (Standard: com.ivan.rookraid)

import { importP8, signES256 } from "../_shared/jwt.ts";

const APPLE = "https://appleid.apple.com";

export type AppleRevoker = (code: string) => Promise<void>;

/** Client-Secret für Apple: JWT mit ES256, 5 Minuten gültig. */
export async function clientSecret(teamId: string, keyId: string, privateKeyPem: string, clientId: string, now = Date.now()): Promise<string> {
  const iat = Math.floor(now / 1000);
  return signES256(await importP8(privateKeyPem), { alg: "ES256", kid: keyId },
    { iss: teamId, iat, exp: iat + 300, aud: APPLE, sub: clientId });
}

/** Echte Fassung: liest die Geheimnisse und spricht mit Apple. Wirft bei jedem Fehler. */
export function appleRevoker(env: (k: string) => string | undefined = (k) => Deno.env.get(k), http: typeof fetch = fetch): AppleRevoker {
  return async (code: string) => {
    const teamId = env("APPLE_TEAM_ID");
    const keyId = env("APPLE_KEY_ID");
    const pem = env("APPLE_PRIVATE_KEY");
    const clientId = env("APPLE_CLIENT_ID") || "com.ivan.rookraid";
    if (!teamId || !keyId || !pem) throw new Error("apple_secrets_missing");
    const secret = await clientSecret(teamId, keyId, pem, clientId);
    const form = (o: Record<string, string>) => ({
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams(o).toString(),
    });

    const tokenRes = await http(`${APPLE}/auth/token`, form({
      client_id: clientId, client_secret: secret, code, grant_type: "authorization_code",
    }));
    const tokens = await tokenRes.json().catch(() => ({})) as { refresh_token?: string; access_token?: string; error?: string };
    if (!tokenRes.ok) throw new Error(`apple_token_${tokens.error ?? tokenRes.status}`);
    const token = tokens.refresh_token ?? tokens.access_token;
    if (!token) throw new Error("apple_token_missing");

    const revokeRes = await http(`${APPLE}/auth/revoke`, form({
      client_id: clientId, client_secret: secret, token,
      token_type_hint: tokens.refresh_token ? "refresh_token" : "access_token",
    }));
    if (!revokeRes.ok) throw new Error(`apple_revoke_${revokeRes.status}`);
  };
}
