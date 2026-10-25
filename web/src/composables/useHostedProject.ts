import { computed, ref } from 'vue'
import { useRoute } from 'vue-router'

import { useAccountFromRoute } from './useAccountFromRoute'
import { ApiError } from '@/services/http'
import { hostedDomainService } from '@/services/hostedDomain'
import type { AccountSummary } from '@/types/api'
import { onCustomDomain } from '@/utils/customDomain'

/**
 * The account and project a hosted page belongs to: from the URL (`/auth/:slug/:projectUid/...`),
 * or, on a project's custom domain, from the domain itself.
 */
export function useHostedProject() {
  if (!onCustomDomain()) {
    const route = useRoute()
    const { account, loading, error } = useAccountFromRoute()
    return { account, projectUid: computed(() => String(route.params.projectUid)), loading, error }
  }

  const account = ref<AccountSummary | null>(null)
  const projectUid = ref('')
  const loading = ref(true)
  const error = ref<ApiError | null>(null)

  hostedDomainService
    .current()
    .then((domain) => {
      projectUid.value = domain.project_uid
      account.value = { uid: domain.account_uid, name: domain.account_name, slug: domain.account_slug }
    })
    .catch((caught: unknown) => {
      error.value = caught instanceof ApiError ? caught : new ApiError('internal_error', 'Something unexpected happened.', 0)
    })
    .finally(() => {
      loading.value = false
    })

  return { account, projectUid: computed(() => projectUid.value), loading, error }
}
