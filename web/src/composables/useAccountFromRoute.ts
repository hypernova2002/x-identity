import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import { authService } from '@/services/auth'
import { ApiError } from '@/services/http'
import type { AccountSummary } from '@/types/api'

/** Resolves the account alias in the current route (`/:slug/...`) to the account's uid and name. */
export function useAccountFromRoute() {
  const route = useRoute()
  const account = ref<AccountSummary | null>(null)
  const loading = ref(true)
  const error = ref<ApiError | null>(null)

  const slug = computed(() => String(route.params.slug ?? ''))

  watch(
    slug,
    async (value) => {
      loading.value = true
      error.value = null
      account.value = null

      try {
        account.value = await authService.lookupAccount(value)
      } catch (caught) {
        error.value = caught instanceof ApiError ? caught : new ApiError('internal_error', 0)
      } finally {
        loading.value = false
      }
    },
    { immediate: true },
  )

  return { account, slug, loading, error }
}
