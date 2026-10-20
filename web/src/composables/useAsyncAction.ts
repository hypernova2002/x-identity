import { ref } from 'vue'

import { ApiError } from '@/services/http'

/**
 * Wraps an async function with `loading` and `error` state for a view. Non-API failures are
 * reported as a generic ApiError so the template only deals with one error type.
 */
export function useAsyncAction<Args extends unknown[], Result>(action: (...args: Args) => Promise<Result>) {
  const loading = ref(false)
  const error = ref<ApiError | null>(null)

  async function run(...args: Args): Promise<Result | undefined> {
    loading.value = true
    error.value = null

    try {
      return await action(...args)
    } catch (caught) {
      error.value =
        caught instanceof ApiError ? caught : new ApiError('internal_error', 'Something unexpected happened. Try again.', 0)
      return undefined
    } finally {
      loading.value = false
    }
  }

  return { loading, error, run }
}
