import { ref, shallowRef, type Ref } from 'vue'

import { ApiError } from '@/services/http'

/**
 * Loading state for a fetch. Views change the refs `fn` reads, then call `reload()`. When reloads
 * overlap, only the latest one's result is kept, so a slow response never overwrites a newer one.
 */
export function useAsync<T>(fn: () => Promise<T>) {
  const data = shallowRef<T | null>(null) as Ref<T | null>
  const loading = ref(false)
  const error = ref<ApiError | null>(null)
  let latest = 0

  async function reload() {
    const call = ++latest
    loading.value = true
    error.value = null
    try {
      const result = await fn()
      if (call === latest) data.value = result
    } catch (caught) {
      if (call === latest) {
        error.value = caught instanceof ApiError ? caught : new ApiError('internal_error', 'Something unexpected happened. Try again.', 0)
      }
    } finally {
      if (call === latest) loading.value = false
    }
  }

  return { data, loading, error, reload }
}
