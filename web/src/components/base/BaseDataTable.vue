<script setup lang="ts" generic="Row">
// The app's one list table. It owns finding rows (search, filters, active-filter chips) and
// navigating them (columns, refresh, rows per page, paging), sortable headers, and the loading,
// empty and error states; views supply rows, columns, filters and the list state. OpenVue's DataTable sorts and pages on the client, while
// every list here round-trips to the server. Hiding columns only changes what's shown.
import { computed, ref, watch } from 'vue'

import BaseAlert from './BaseAlert.vue'
import BaseButton from './BaseButton.vue'
import BaseColumnPicker from './BaseColumnPicker.vue'
import BaseFilterField from './BaseFilterField.vue'
import BaseFilterPopover from './BaseFilterPopover.vue'
import BaseInput from './BaseInput.vue'
import BasePagination from './BasePagination.vue'
import BaseSelect from './BaseSelect.vue'
import type { DataTableColumn, DataTableFilter } from './types'
import { useDebounce } from '@/composables/useDebounce'
import { PAGE_SIZES, type ListState } from '@/composables/useListView'
import type { ApiError } from '@/services/http'
import { formatDate } from '@/utils/format'
import { readTablePreferences, saveTablePreferences } from '@/utils/tablePreferences'

const SEARCH_DELAY_MS = 300
/** Lists with more filters than this show the first two and put the rest under "More filters". */
const MAX_INLINE_FILTERS = 3

const props = withDefaults(
  defineProps<{
    caption: string
    columns: readonly DataTableColumn[]
    rows: readonly Row[]
    rowKey: (row: Row) => string
    total: number
    perPage: number
    /** The total is a lower bound; offers counting exactly. */
    capped?: boolean
    searchLabel: string
    searchPlaceholder?: string
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
    /** Remembers hidden columns in this browser; the same key as the list's `storageKey`. */
    storageKey?: string
  }>(),
  {
    searchPlaceholder: 'Search',
    searchHint: undefined,
    filters: () => [],
    loading: false,
    error: null,
    noMatchesMessage: 'Nothing matches this search and these filters.',
    stacked: false,
    capped: false,
    storageKey: undefined,
  },
)

const state = defineModel<ListState>('state', { required: true })

const emit = defineEmits<{
  /** Refresh was pressed, or Try again after a failed load. */
  reload: []
  countExactly: []
}>()

defineSlots<{
  [key: `cell-${string}`]: (props: { row: Row }) => unknown
  /** Actions next to the search, for tables without a page header of their own, such as one in a card. */
  actions?: () => unknown
  empty?: () => unknown
}>()

const search = ref(state.value.search)
const textFilters = ref<Record<string, string>>(
  Object.fromEntries(props.filters.filter((filter) => filter.type === 'text').map((filter) => [filter.key, state.value.filters[filter.key] ?? ''])),
)

const hiddenColumns = ref<string[]>(props.storageKey ? (readTablePreferences(props.storageKey).hiddenColumns ?? []) : [])

/** The first column names each row and unlabelled ones hold row actions, so they can't be hidden. */
const nameKey = computed(() => props.columns.find((column) => !column.srOnly)?.key)
const isLocked = (column: DataTableColumn) => column.srOnly || column.key === nameKey.value
const pickerColumns = computed(() =>
  props.columns.filter((column) => !column.srOnly).map((column) => ({ key: column.key, label: column.label, locked: isLocked(column) })),
)
const visibleColumns = computed(() => props.columns.filter((column) => isLocked(column) || !hiddenColumns.value.includes(column.key)))

watch(hiddenColumns, (hidden) => {
  if (props.storageKey) saveTablePreferences(props.storageKey, { hiddenColumns: hidden })
})

const pageSizeOptions = PAGE_SIZES.map((size) => ({ label: String(size), value: String(size) }))

const narrowed = computed(() => state.value.search !== '' || Object.keys(state.value.filters).length > 0)

function update(changes: Partial<Pick<ListState, 'perPage' | 'search' | 'sort' | 'filters'>>) {
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

const filterValue = (filter: DataTableFilter) => (filter.type === 'text' ? (textFilters.value[filter.key] ?? '') : (state.value.filters[filter.key] ?? ''))

function setFilterValue(filter: DataTableFilter, value: string) {
  if (filter.type === 'text') onTextFilter(filter.key, value)
  else setFilter(filter.key, value)
}

const inlineFilters = computed(() => (props.filters.length > MAX_INLINE_FILTERS ? props.filters.slice(0, 2) : props.filters))
const moreFilters = computed(() => props.filters.slice(inlineFilters.value.length))
const activeMoreFilters = computed(() => moreFilters.value.filter((filter) => state.value.filters[filter.key]).length)

/** Names picked from lookups, for their chips; filled in as the values change. */
const lookupLabels = ref<Record<string, string>>({})

watch(
  () => props.filters.filter((filter) => filter.type === 'lookup').map((filter) => [filter, state.value.filters[filter.key] ?? ''] as const),
  async (lookups) => {
    for (const [filter, value] of lookups) {
      if (filter.type !== 'lookup' || value === '' || lookupLabels.value[value] || !filter.resolveLabel) continue
      const label = await filter.resolveLabel(value)
      if (label) lookupLabels.value = { ...lookupLabels.value, [value]: label }
    }
  },
  { immediate: true },
)

function valueLabel(filter: DataTableFilter, value: string): string {
  if (filter.type === 'select') return filter.options.find((option) => option.value === value)?.label ?? value
  if (filter.type === 'date') return formatDate(value)
  if (filter.type === 'lookup') return lookupLabels.value[value] ?? value
  return value
}

function removeFilter(filter: DataTableFilter) {
  debouncedFilter.cancel()
  if (filter.type === 'text') textFilters.value = { ...textFilters.value, [filter.key]: '' }
  setFilter(filter.key, '')
}

function removeSearch() {
  debouncedSearch.cancel()
  search.value = ''
  update({ search: '' })
}

const chips = computed(() => [
  ...(state.value.search ? [{ key: 'search', label: `Search: ${state.value.search}`, remove: removeSearch }] : []),
  ...props.filters
    .filter((filter) => state.value.filters[filter.key])
    .map((filter) => ({ key: filter.key, label: `${filter.label}: ${valueLabel(filter, state.value.filters[filter.key]!)}`, remove: () => removeFilter(filter) })),
])

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
  <div class="flex flex-col gap-3">
    <div class="flex flex-wrap items-end justify-between gap-3">
      <form class="flex flex-wrap items-end gap-3" role="search" :aria-label="caption" @submit.prevent="debouncedSearch.flush(search)">
        <div class="w-full sm:w-80">
          <BaseInput v-model="search" :label="searchLabel" :placeholder="searchPlaceholder" :hint="searchHint" type="search" icon="search" />
        </div>
        <div v-for="filter in inlineFilters" :key="filter.key" class="w-full sm:w-44">
          <BaseFilterField :filter="filter" :model-value="filterValue(filter)" @update:model-value="(value: string) => setFilterValue(filter, value)" />
        </div>
        <BaseFilterPopover v-if="moreFilters.length > 0" :active-count="activeMoreFilters">
          <BaseFilterField
            v-for="filter in moreFilters"
            :key="filter.key"
            :filter="filter"
            :model-value="filterValue(filter)"
            append-to="self"
            @update:model-value="(value: string) => setFilterValue(filter, value)"
          />
        </BaseFilterPopover>
        <div v-if="stacked && sortOptions.length > 0" class="w-full sm:hidden">
          <BaseSelect :model-value="state.sort" label="Sort by" :options="sortOptions" @update:model-value="(value: string) => update({ sort: value })" />
        </div>
      </form>
      <div v-if="$slots.actions" class="flex flex-wrap gap-2">
        <slot name="actions" />
      </div>
    </div>

    <ul v-if="chips.length > 0" class="flex flex-wrap items-center gap-2" aria-label="Active filters">
      <li v-for="chip in chips" :key="chip.key" class="inline-flex max-w-full items-center gap-1 rounded-full border border-border bg-bg-subtle py-1 pr-1 pl-3 text-sm">
        <span class="truncate">{{ chip.label }}</span>
        <button
          type="button"
          class="rounded-full p-1 text-text-muted hover:bg-border hover:text-text focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
          :aria-label="`Remove ${chip.label}`"
          @click="chip.remove"
        >
          <svg aria-hidden="true" viewBox="0 0 20 20" class="size-3.5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
            <path d="M5 5l10 10M15 5L5 15" />
          </svg>
        </button>
      </li>
      <li><BaseButton label="Clear all" variant="ghost" size="sm" @click="clearAll" /></li>
    </ul>

    <div class="flex flex-wrap items-center justify-between gap-3 border-t border-border pt-3">
      <div class="flex flex-wrap items-center gap-2" role="toolbar" :aria-label="`${caption} table`">
        <BaseColumnPicker v-if="pickerColumns.length > 1" v-model:hidden="hiddenColumns" :columns="pickerColumns" />
        <BaseButton label="Refresh" variant="secondary" :disabled="loading" @click="emit('reload')">
          <template #icon>
            <svg
              aria-hidden="true"
              viewBox="0 0 20 20"
              class="size-5"
              :class="{ 'animate-spin motion-reduce:animate-none': loading }"
              fill="none"
              stroke="currentColor"
              stroke-width="1.75"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M16 10a6 6 0 1 1-1.76-4.24" />
              <path d="M16 3.5v3h-3" />
            </svg>
          </template>
        </BaseButton>
        <span aria-hidden="true" class="ml-2 text-sm text-text-muted">Rows per page</span>
        <div class="w-24">
          <BaseSelect
            :model-value="String(state.perPage)"
            label="Rows per page"
            hide-label
            :options="pageSizeOptions"
            @update:model-value="(value: string) => update({ perPage: Number(value) })"
          />
        </div>
      </div>
      <BasePagination
        v-model:page="page"
        :total="total"
        :per-page="perPage"
        :row-count="rows.length"
        :capped="capped"
        :disabled="loading"
        @count-exactly="emit('countExactly')"
      />
    </div>

    <BaseAlert v-if="error" variant="danger" title="We couldn't load this list">
      {{ error.message }}
      <BaseButton label="Try again" variant="ghost" size="sm" @click="emit('reload')" />
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
          <div v-for="column in visibleColumns" :key="column.key" class="flex min-w-0 flex-col gap-0.5">
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
            <th v-for="column in visibleColumns" :key="column.key" scope="col" class="px-4 py-3 font-semibold" :aria-sort="ariaSort(column)">
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
            <td :colspan="visibleColumns.length" class="px-4 py-8 text-center text-text-muted" role="status">Loading…</td>
          </tr>
          <tr v-else-if="rows.length === 0 && !error">
            <td :colspan="visibleColumns.length" class="px-4 py-8 text-center text-text-muted">
              <template v-if="narrowed">
                {{ noMatchesMessage }}
                <BaseButton label="Clear filters" variant="ghost" size="sm" @click="clearAll" />
              </template>
              <slot v-else name="empty">{{ emptyMessage }}</slot>
            </td>
          </tr>
          <template v-else>
            <tr v-for="row in rows" :key="rowKey(row)" class="border-t border-border hover:bg-bg-subtle" :class="{ 'opacity-60': loading }">
              <td v-for="column in visibleColumns" :key="column.key" class="px-4 py-3 align-middle">
                <slot :name="`cell-${column.key}`" :row="row">{{ (row as Record<string, unknown>)[column.key] }}</slot>
              </td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>

    <BasePagination
      v-model:page="page"
      class="self-end"
      label="Pagination, bottom"
      :total="total"
      :per-page="perPage"
      :row-count="rows.length"
      :capped="capped"
      :disabled="loading"
      @count-exactly="emit('countExactly')"
    />
  </div>
</template>
