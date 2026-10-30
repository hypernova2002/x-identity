import type { AppClientSecret } from '@/types/api'
import { i18n } from '@/i18n'
import { formatDateTime } from '@/utils/format'

export interface SecretStatus {
  tone: 'success' | 'warning' | 'neutral'
  label: string
}

/** Whether a secret works, and until when; secrets replaced by a rotation work for a while longer. */
export function secretStatus(secret: AppClientSecret, now: Date = new Date()): SecretStatus {
  const { t } = i18n.global
  if (secret.revoked_at) return { tone: 'neutral', label: t('project.secretStatus.revoked') }
  if (secret.expires_at && new Date(secret.expires_at) <= now) return { tone: 'neutral', label: t('project.secretStatus.expired') }
  if (secret.expires_at) return { tone: 'warning', label: t('project.secretStatus.worksUntil', { date: formatDateTime(secret.expires_at) }) }
  return { tone: 'success', label: t('project.secretStatus.active') }
}
