<script setup lang="ts" generic="Row">
// The app's one list table. It owns search, filters, sortable headers, pagination and the loading,
// empty and error states; views supply rows, columns, filters and the list state. OpenVue's
// DataTable sorts and pages on the client, while every list here round-trips to the server.
import { computed, ref, watch } from 'vue'

import BaseAlert from './BaseAlert.vue'
import BaseButton from './BaseButton.vue'
import BaseInput from './BaseInput.vue'
import BasePagination from './BasePagination.vue'
import BaseSelect from './BaseSelect.vue'
import type { DataTableColumn, DataTableFilter } from './types'
import { useDebounce } from '@/composables/useDebounce'
import type { ListState } from '@/composables/useListView'
import type { ApiError } from '@/services/http'

const SEARCH_DELAY_MS = 300

const props = withDefaults(
  defineProps<{
    caption: string
    columns: readonly DataTableColumn[]
    rows: readonly Row[]
    rowKey: (row: Row) => string
    total: number
    perPage: number
    searchLabel: string
    searchHint?: string
    filters?: readonly DataTableFilter[]
    loading?: boolean
    error?: ApiError | null
    /** Shown when nothing exists yet. */
    emptyMessage: string
    /** Shown when a search or filter matches nothing. */
    noMatchesMessage?: string
    /** On narrow screens, shows each row as a card of labelled fields instead of a wide table. */
    stacked?: boolean
  }>(),
  {
    searchHint: undefined,
    filters: () => [],
    loading: false,
    error: null,
    noMatchesMessage: 'Nothing matches this search and these filters.',
    stacked: false,
  },
)

const state = defineModel<ListState>('state', { required: true })

const emit = defineEmits<{
  retry: []
}>()

defineSlots<{
  [key: `cell-${string}`]: (props: { row: Row }) => unknown
  /** Actions next to the search, such as "Create". */
  actions?: () => unknown
  empty?: () => unknown
}>()

const search = ref(state.value.search)
const textFilters = ref<Record<string, string>>(
  Object.fromEntries(props.filters.filter((filter) => filter.type === 'text').map((filter) => [filter.key, state.value.filters[filter.key] ?? ''])),
)

const narrowed = computed(() => state.value.search !== '' || Object.keys(state.value.filters).length > 0)

function update(changes: Partial<Pick<ListState, 'search' | 'sort' | 'filters'>>) {
  const next = { ...state.value, ...changes, page: 1 }
  if (JSON.stringify(next) !== JSON.stringify(state.value)) state.value = next
}

function setFilter(key: string, value: string) {
  const filters = { ...state.value.filters }
  if (value === '') delete filters[key]
  else filters[key] = value
  update({ filters })
}

const debouncedSearch = useDebounce((value: string) => update({ search: value.trim() }), SEARCH_DELAY_MS)
const debouncedFilter = useDebounce((key: string, value: string) => setFilter(key, value.trim()), SEARCH_DELAY_MS)

watch(search, (value) => debouncedSearch.run(value))

function onTextFilter(key: string, value: string) {
  textFilters.value = { ...textFilters.value, [key]: value }
  debouncedFilter.run(key, value)
}

watch(
  () => state.value,
  (next) => {
    if (next.search !== search.value.trim()) search.value = next.search
    for (const key of Object.keys(textFilters.value)) {
      if ((next.filters[key] ?? '') !== textFilters.value[key]!.trim()) textFilters.value[key] = next.filters[key] ?? ''
    }
  },
)

function clearAll() {
  debouncedSearch.cancel()
  debouncedFilter.cancel()
  search.value = ''
  update({ search: '', filters: {} })
}

const sortKey = computed(() => state.value.sort.replace(/^-/, ''))
const descending = computed(() => state.value.sort.startsWith('-'))

function ariaSort(column: DataTableColumn) {
  if (!column.sortKey) return undefined
  if (column.sortKey !== sortKey.value) return 'none'
  return descending.value ? 'descending' : 'ascending'
}

function toggleSort(column: DataTableColumn) {
  if (!column.sortKey) return
  const nextDescending = column.sortKey === sortKey.value ? !descending.value : false
  update({ sort: `${nextDescending ? '-' : ''}${column.sortKey}` })
}

function sortLabel(column: DataTableColumn) {
  const current = column.sortKey === sortKey.value
  return `Sort by ${column.label}, ${current && !descending.value ? 'descending' : 'ascending'}`
}

const page = computed({
  get: () => state.value.page,
  set: (value: number) => (state.value = { ...state.value, page: value }),
})

const selectValue = (filter: DataTableFilter) => state.value.filters[filter.key] ?? ''

/** Stacked rows have no headers to click, so they sort with a select instead. */
const sortOptions = computed(() =>
  props.columns
    .filter((column) => column.sortKey)
    .flatMap((column) => {
      const [ascending, descending] = column.sortKind === 'date' ? ['oldest first', 'newest first'] : ['A to Z', 'Z to A']
      return [
        { label: `${column.label}, ${descending}`, value: `-${column.sortKey}` },
        { label: `${column.label}, ${ascending}`, value: column.sortKey! },
      ]
    }),
)
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <form class="flex flex-wrap items-end gap-4" role="search" :aria-label="caption" @submit.prevent="debouncedSearch.flush(search)">
        <div class="w-full sm:w-64">
          <BaseInput v-model="search" :label="searchLabel" :hint="searchHint" type="search" />
        </div>
        <div v-for="filter in filters" :key="filter.key" class="w-full sm:w-44">
          <BaseSelect
            v-if="filter.type === 'select'"
            :model-value="selectValue(filter)"
            :label="filter.label"
            :options="[{ label: filter.anyLabel ?? 'Any', value: '' }, ...filter.options]"
            @update:model-value="(value: string) => setFilter(filter.key, value)"
          />
          <BaseInput
            v-else-if="filter.type === 'date'"
            :model-value="selectValue(filter)"
            :label="filter.label"
            type="date"
            @update:model-value="(value: string) => setFilter(filter.key, value)"
          />
          <BaseInput
            v-else
            :model-value="textFilters[filter.key] ?? ''"
            :label="filter.label"
            type="search"
            @update:model-value="(value: string) => onTextFilter(filter.key, value)"
          />
        </div>
        <div v-if="stacked && sortOptions.length > 0" class="w-full sm:hidden">
          <BaseSelect :model-value="state.sort" label="Sort by" :options="sortOptions" @update:model-value="(value: string) => update({ sort: value })" />
        </div>
        <BaseButton v-if="narrowed" label="Clear filters" variant="ghost" @click="clearAll" />
      </form>
      <div v-if="$slots.actions" class="flex flex-wrap gap-2">
        <slot name="actions" />
      </div>
    </div>

    <BaseAlert v-if="error" variant="danger" title="We couldn't load this list">
      {{ error.message }}
      <BaseButton label="Try again" variant="ghost" size="sm" @click="emit('retry')" />
    </BaseAlert>

    <ul v-if="stacked" class="flex flex-col divide-y divide-border rounded-lg border border-border sm:hidden" :aria-label="caption" :aria-busy="loading || undefined">
      <li v-if="loading && rows.length === 0" class="px-4 py-8 text-center text-sm text-text-muted" role="status">Loading…</li>
      <li v-else-if="rows.length === 0 && !error" class="px-4 py-8 text-center text-sm text-text-muted">
        <template v-if="narrowed">
          {{ noMatchesMessage }}
          <BaseButton label="Clear filters" variant="ghost" size="sm" @click="clearAll" />
        </template>
        <slot v-else name="empty">{{ emptyMessage }}</slot>
      </li>
      <template v-else>
        <li v-for="row in rows" :key="rowKey(row)" class="flex flex-col gap-2 p-4 text-sm" :class="{ 'opacity-60': loading }">
          <div v-for="column in columns" :key="column.key" class="flex min-w-0 flex-col gap-0.5">
            <span v-if="!column.srOnly" class="text-xs font-medium text-text-muted">{{ column.label }}</span>
            <div class="min-w-0 break-words">
              <slot :name="`cell-${column.key}`" :row="row">{{ (row as Record<string, unknown>)[column.key] }}</slot>
            </div>
          </div>
        </li>
      </template>
    </ul>

    <div class="overflow-x-auto rounded-lg border border-border" :class="{ 'hidden sm:block': stacked }">
      <table class="w-full border-collapse text-left text-sm" :aria-busy="loading || undefined">
        <caption class="sr-only">{{ caption }}</caption>
        <thead class="bg-bg-subtle">
          <tr>
            <th v-for="column in columns" :key="column.key" scope="col" class="px-4 py-3 font-semibold" :aria-sort="ariaSort(column)">
              <button
                v-if="column.sortKey"
                type="button"
                class="inline-flex items-center gap-1 rounded-sm hover:text-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
                :aria-label="sortLabel(column)"
                @click="toggleSort(column)"
              >
                {{ column.label }}
                <span aria-hidden="true" class="w-3 text-xs text-text-muted">
                  {{ column.sortKey === sortKey ? (descending ? '↓' : '↑') : '↕' }}
                </span>
              </button>
              <span v-else :class="{ 'sr-only': column.srOnly }">{{ column.label }}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading && rows.length === 0">
            <td :colspan="columns.length" class="px-4 py-8 text-center text-text-muted" role="status">Loading…</td>
          </tr>
          <tr v-else-if="rows.length === 0 && !error">
            <td :colspan="columns.length" class="px-4 py-8 text-center text-text-muted">
              <template v-if="narrowed">
                {{ noMatchesMessage }}
                <BaseButton label="Clear filters" variant="ghost" size="sm" @click="clearAll" />
              </template>
              <slot v-else name="empty">{{ emptyMessage }}</slot>
            </td>
          </tr>
          <template v-else>
            <tr v-for="row in rows" :key="rowKey(row)" class="border-t border-border hover:bg-bg-subtle" :class="{ 'opacity-60': loading }">
              <td v-for="column in columns" :key="column.key" class="px-4 py-3 align-middle">
                <slot :name="`cell-${column.key}`" :row="row">{{ (row as Record<string, unknown>)[column.key] }}</slot>
              </td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>

    <BasePagination v-model:page="page" :total="total" :per-page="perPage" :disabled="loading" />
  </div>
</template>
