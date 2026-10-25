import { apiRequest } from './http'
import type { HostedDomain } from '@/types/api'

export const hostedDomainService = {
  /** Which project the custom domain serving this page belongs to. */
  current: () => apiRequest<HostedDomain>('/auth/domain'),
}
