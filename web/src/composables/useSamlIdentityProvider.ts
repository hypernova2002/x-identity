import { ref } from 'vue'

import { useAsyncAction } from './useAsyncAction'
import { projectAdminService } from '@/services/project'
import type { SamlCertificate, SamlIdentityProviderInfo } from '@/types/api'

/** The project's SAML identity provider details, and rotating its signing certificate. */
export function useSamlIdentityProvider() {
  const info = ref<SamlIdentityProviderInfo | null>(null)
  let target: { accountUid: string; projectUid: string } | null = null

  const load = useAsyncAction(async (accountUid: string, projectUid: string) => {
    target = { accountUid, projectUid }
    info.value = await projectAdminService.getSamlIdentityProvider(accountUid, projectUid)
  })

  const certificateAction = useAsyncAction(async (action: 'add' | 'activate' | 'remove', certificate?: SamlCertificate) => {
    if (!target) return
    const { accountUid, projectUid } = target
    if (action === 'add') await projectAdminService.addSamlCertificate(accountUid, projectUid)
    if (action === 'activate' && certificate) await projectAdminService.activateSamlCertificate(accountUid, projectUid, certificate.uid)
    if (action === 'remove' && certificate) await projectAdminService.removeSamlCertificate(accountUid, projectUid, certificate.uid)
    info.value = await projectAdminService.getSamlIdentityProvider(accountUid, projectUid)
  })

  return { info, load, certificateAction }
}
