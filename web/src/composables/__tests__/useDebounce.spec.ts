import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { effectScope, nextTick, ref } from 'vue'

import { useDebounce, useDebouncedRef } from '../useDebounce'

describe('useDebounce', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('runs once, with the last arguments, after the calls stop', () => {
    const fn = vi.fn<(value: string) => void>()
    const { run } = useDebounce(fn, 300)

    run('c')
    run('ca')
    vi.advanceTimersByTime(299)
    run('cas')
    vi.advanceTimersByTime(299)

    expect(fn).not.toHaveBeenCalled()

    vi.advanceTimersByTime(1)

    expect(fn).toHaveBeenCalledExactlyOnceWith('cas')
  })

  it('runs straight away when flushed, dropping the pending call', () => {
    const fn = vi.fn<(value: string) => void>()
    const { run, flush } = useDebounce(fn, 300)

    run('ca')
    flush('casey')
    vi.advanceTimersByTime(300)

    expect(fn).toHaveBeenCalledExactlyOnceWith('casey')
  })

  it('drops a pending call when its scope ends', () => {
    const fn = vi.fn<() => void>()
    const scope = effectScope()
    scope.run(() => useDebounce(fn, 300).run())

    scope.stop()
    vi.advanceTimersByTime(300)

    expect(fn).not.toHaveBeenCalled()
  })
})

describe('useDebouncedRef', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('follows the source once it settles', async () => {
    const source = ref('')
    const debounced = useDebouncedRef(source, 300)

    source.value = 'casey'
    await nextTick()
    vi.advanceTimersByTime(200)
    expect(debounced.value).toBe('')

    vi.advanceTimersByTime(100)
    expect(debounced.value).toBe('casey')
  })
})
