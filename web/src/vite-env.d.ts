/// <reference types="vite/client" />

declare module 'rookraid-rules' {
  const core: any
  export default core
}
/// <reference types="vite-plugin-pwa/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string
  readonly VITE_SUPABASE_ANON_KEY: string
  readonly VITE_APPLE_CLIENT_ID: string
  readonly VITE_VAPID_PUBLIC_KEY: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

interface AppleSignInResponse {
  authorization?: { id_token?: string; code?: string }
}

interface Window {
  AppleID?: {
    auth: {
      init(config: Record<string, unknown>): void
      signIn(): Promise<AppleSignInResponse>
    }
  }
}
