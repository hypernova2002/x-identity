import { describe, expect, it } from 'vitest'

import { useAsync } from '../useAsync'
import { ApiError } from '@/services/http'

function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((done) => (resolve = done))
  return { promise, resolve }
}

describe('useAsync', () => {
  it('tracks loading and keeps the result', async () => {
    const { data, loading, reload } = useAsync(async () => 'rows')

    const pending = reload()
    expect(loading.value).toBe(true)
    await pending

    expect(loading.value).toBe(false)
    expect(data.value).toBe('rows')
  })

  it('keeps only the latest result when reloads overlap', async () => {
    const calls = [deferred<string>(), deferred<string>()]
    let call = 0
    const { data, loading, reload } = useAsync(() => calls[call++]!.promise)

    const first = reload()
    const second = reload()
    calls[1]!.resolve('newer')
    await second
    calls[0]!.resolve('older')
    await first

    expect(data.value).toBe('newer')
    expect(loading.value).toBe(false)
  })

  it('reports failures as API errors', async () => {
    const { error, reload } = useAsync(async () => {
      throw new ApiError('not_found', 'Gone', 404)
    })

    await reload()

    expect(error.value?.code).toBe('not_found')
  })
})
