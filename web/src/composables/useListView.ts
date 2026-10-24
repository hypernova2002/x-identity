import { computed, ref, watch } from 'vue'
import { useRoute, useRouter, type LocationQuery } from 'vue-router'

import { useAsync } from './useAsync'
import type { Page } from '@/services/http'
import type { ListParams } from '@/services/list'

/** What a data table asks the server for. Pages are 1-based. */
export interface ListState {
  page: number
  search: string
  sort: string
  filters: Record<string, string>
}

interface Options {
  defaultSort: string
  /** Filter keys the view offers; each is a `q` predicate of the endpoint. */
  filterKeys?: readonly string[]
  /** Keeps the state in the URL, so lists can be shared, bookmarked and restored with back/forward. */
  syncRoute?: boolean
  perPage?: number
}

const text = (value: LocationQuery[string] | undefined) => (typeof value === 'string' ? value : '')

/** One server-side list: its search, filters, sort and page, and the page of rows they load. */
export function useListView<T>(fetch: (params: ListParams) => Promise<Page<T>>, options: Options) {
  const route = useRoute()
  const router = useRouter()
  const filterKeys = options.filterKeys ?? []

  function fromQuery(query: LocationQuery): ListState {
    const page = Number(text(query.page))
    return {
      page: Number.isInteger(page) && page > 0 ? page : 1,
      search: text(query.search),
      sort: text(query.sort) || options.defaultSort,
      filters: Object.fromEntries(filterKeys.map((key) => [key, text(query[key])]).filter(([, value]) => value !== '')),
    }
  }

  function toQuery(state: ListState): Record<string, string> {
    return {
      ...(state.page > 1 ? { page: String(state.page) } : {}),
      ...(state.search ? { search: state.search } : {}),
      ...(state.sort !== options.defaultSort ? { sort: state.sort } : {}),
      ...state.filters,
    }
  }

  const state = ref<ListState>(options.syncRoute ? fromQuery(route.query) : fromQuery({}))
  /** Set by "Count exactly"; any change to the list goes back to the cheaper, capped count. */
  const exactCount = ref(false)

  const { data, loading, error, reload } = useAsync(() =>
    fetch({
      page: state.value.page,
      perPage: options.perPage,
      search: state.value.search,
      sort: state.value.sort,
      filters: state.value.filters,
      exactCount: exactCount.value || undefined,
    }),
  )

  const rows = computed(() => data.value?.items ?? [])
  const total = computed(() => data.value?.total ?? 0)
  const perPage = computed(() => data.value?.perPage ?? options.perPage ?? 25)
  const capped = computed(() => data.value?.capped ?? false)
  const filtered = computed(() => state.value.search !== '' || Object.keys(state.value.filters).length > 0)

  watch(
    state,
    (next) => {
      exactCount.value = false
      reload()
      if (!options.syncRoute) return
      const owned = new Set(['page', 'search', 'sort', ...filterKeys])
      const others = Object.fromEntries(Object.entries(route.query).filter(([key]) => !owned.has(key)))
      router.replace({ query: { ...others, ...toQuery(next) } })
    },
    { deep: true, immediate: true },
  )

  if (options.syncRoute) {
    watch(
      () => route.query,
      (query) => {
        const next = fromQuery(query)
        if (JSON.stringify(next) !== JSON.stringify(state.value)) state.value = next
      },
    )
  }

  function countExactly() {
    exactCount.value = true
    return reload()
  }

  return { state, rows, total, perPage, capped, loading, error, filtered, reload, countExactly }
}
