import { describe, expect, it } from 'vitest'

import { useAsyncAction } from '../useAsyncAction'
import { ApiError } from '@/services/http'

describe('useAsyncAction', () => {
  it('returns the action result', async () => {
    const { run } = useAsyncAction(async (value: number) => value * 2)

    await expect(run(21)).resolves.toBe(42)
  })

  it('is loading while the action runs', async () => {
    let resolve: () => void = () => {}
    const { loading, run } = useAsyncAction(() => new Promise<void>((done) => (resolve = done)))

    const running = run()
    const loadingWhileRunning = loading.value
    resolve()
    await running

    expect([loadingWhileRunning, loading.value]).toEqual([true, false])
  })

  it('keeps API errors as they are', async () => {
    const apiError = new ApiError('forbidden', 'No.', 403)
    const { error, run } = useAsyncAction(async () => {
      throw apiError
    })

    await run()

    expect(error.value).toBe(apiError)
  })

  it('wraps unexpected errors in an ApiError', async () => {
    const { error, run } = useAsyncAction(async () => {
      throw new Error('boom')
    })

    await run()

    expect(error.value?.code).toBe('internal_error')
  })
})
