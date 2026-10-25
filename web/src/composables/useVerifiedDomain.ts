import { computed, onMounted } from 'vue'

import { useAsync } from './useAsync'
import { projectAdminService } from '@/services/project'

/** The project's verified custom domain, if any, for pages offering to switch to it. */
export function useVerifiedDomain(target: () => { accountUid: string; projectUid: string } | null) {
  const domains = useAsync(async () => {
    const ids = target()
    return ids ? projectAdminService.listDomains(ids.accountUid, ids.projectUid) : []
  })
  const hostname = computed(() => domains.data.value?.find((domain) => domain.status === 'verified')?.hostname ?? null)

  onMounted(() => domains.reload())

  return { hostname, loading: domains.loading, error: domains.error }
}
