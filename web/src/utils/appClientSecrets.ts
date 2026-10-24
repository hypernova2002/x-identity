import type { AppClientSecret } from '@/types/api'
import { formatDateTime } from '@/utils/format'

export interface SecretStatus {
  tone: 'success' | 'warning' | 'neutral'
  label: string
}

/** Whether a secret works, and until when; secrets replaced by a rotation work for a while longer. */
export function secretStatus(secret: AppClientSecret, now: Date = new Date()): SecretStatus {
  if (secret.revoked_at) return { tone: 'neutral', label: 'Revoked' }
  if (secret.expires_at && new Date(secret.expires_at) <= now) return { tone: 'neutral', label: 'Expired' }
  if (secret.expires_at) return { tone: 'warning', label: `Works until ${formatDateTime(secret.expires_at)}` }
  return { tone: 'success', label: 'Active' }
}
