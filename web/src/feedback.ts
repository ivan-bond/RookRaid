// Feedback from Profile → Feedback, like FeedbackService in the app. Edge function `send-feedback` stores the message
// and emails it to rookraidchess@gmail.com (Backend/supabase/functions/send-feedback).
import { supabase } from './supabase'
import { getLang } from './i18n'
import { APP_VERSION } from './version'
import * as S from './game/store'

export type FeedbackCategory = 'bug' | 'balance' | 'idea' | 'other'
export const FEEDBACK_EMAIL = 'rookraidchess@gmail.com'

/** Resolves on success; rejects with 'rate_limited', 'invalid' or 'failed'. */
export async function sendFeedback(category: FeedbackCategory, message: string, contact: string): Promise<void> {
  if (!supabase) throw new Error('failed')
  const p = S.getProfile()
  const { error } = await supabase.functions.invoke('send-feedback', {
    method: 'POST',
    body: {
      category, message: message.trim(), contact: contact.trim(),
      meta: { platform: 'web', app_version: APP_VERSION, language: getLang(), player_name: p.name, trophies: p.trophies, device: navigator.userAgent.slice(0, 80) },
    },
  })
  if (!error) return
  const status = (error as { context?: Response }).context?.status
  throw new Error(status === 429 ? 'rate_limited' : status === 400 ? 'invalid' : 'failed')
}
