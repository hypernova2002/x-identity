import { onScopeDispose, ref, watch, type Ref } from 'vue'

/** Delays `fn` until `ms` have passed without another call. Pending calls are dropped when the scope ends. */
export function useDebounce<Args extends unknown[]>(fn: (...args: Args) => void, ms: number) {
  let timer: ReturnType<typeof setTimeout> | undefined

  function cancel() {
    if (timer !== undefined) clearTimeout(timer)
    timer = undefined
  }

  function run(...args: Args) {
    cancel()
    timer = setTimeout(() => {
      timer = undefined
      fn(...args)
    }, ms)
  }

  /** Runs a pending call now, e.g. when the user presses Enter. */
  function flush(...args: Args) {
    cancel()
    fn(...args)
  }

  onScopeDispose(cancel)

  return { run, cancel, flush }
}

/** A copy of `source` that only takes its value once it has stopped changing for `ms`. */
export function useDebouncedRef<T>(source: Ref<T>, ms: number): Ref<T> {
  const debounced = ref(source.value) as Ref<T>
  const { run } = useDebounce((value: T) => (debounced.value = value), ms)
  watch(source, (value) => run(value))
  return debounced
}
