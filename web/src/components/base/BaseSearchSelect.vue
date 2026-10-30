<script setup lang="ts">
// A dropdown for picking from a list that can be too long to load whole: it shows the first page,
// searches the server as the user types, and links to the full list when there's more.
import { computed, ref, useId, watch } from 'vue'
import { RouterLink, type RouteLocationRaw } from 'vue-router'
import AutoComplete from 'openvue/autocomplete'

import type { SelectOption } from './types'
import type { LookupPage } from '@/services/list'

const SEARCH_DELAY_MS = 300

const props = withDefaults(
  defineProps<{
    label: string
    /** Finds options matching the text typed so far (empty for the first page). */
    search: (term: string) => Promise<LookupPage>
    /** Names a selected value that didn't come from the options, e.g. one from the URL. */
    resolveLabel?: (value: string) => Promise<string | null> | string | null
    /** The page listing every item, offered when there are more than the dropdown shows. */
    seeAll?: RouteLocationRaw
    hideLabel?: boolean
    hint?: string
    error?: string
    placeholder?: string
    disabled?: boolean
    /** 'self' keeps the options inside the component, e.g. within a popover that closes on outside clicks. */
    appendTo?: 'body' | 'self'
  }>(),
  { appendTo: 'body', resolveLabel: undefined, seeAll: undefined, hideLabel: false, hint: undefined, error: undefined, placeholder: undefined, disabled: false },
)

/** The selected item's value, or '' for none. */
const model = defineModel<string>({ required: true })

const id = useId()
const labelId = `${id}-label`
const hintId = `${id}-hint`
const errorId = `${id}-error`

const suggestions = ref<SelectOption[]>([])
const total = ref(0)
const loading = ref(false)
const failed = ref(false)
const selected = ref<SelectOption | string | null>(null)
let latest = 0

const describedBy = computed(() => [props.hint ? hintId : null, props.error ? errorId : null].filter(Boolean).join(' ') || undefined)
const more = computed(() => total.value > suggestions.value.length)

watch(
  model,
  async (value) => {
    const current = selected.value !== null && typeof selected.value === 'object' ? selected.value.value : ''
    if (value === current) return
    if (!value) {
      selected.value = null
      return
    }
    selected.value = { value, label: value }
    const label = await props.resolveLabel?.(value)
    if (label && model.value === value) selected.value = { value, label }
  },
  { immediate: true },
)

async function complete(event: { query: string }) {
  const call = ++latest
  loading.value = true
  failed.value = false
  try {
    const page = await props.search(event.query.trim())
    if (call !== latest) return
    suggestions.value = page.items
    total.value = page.total
  } catch {
    if (call !== latest) return
    suggestions.value = []
    failed.value = true
  } finally {
    if (call === latest) loading.value = false
  }
}

function pick(option: SelectOption | string | null) {
  selected.value = option
  if (option === null || option === '') model.value = ''
  else if (typeof option === 'object') model.value = option.value
}

interface OptionContext {
  context: { selected: boolean; focused: boolean }
}

const passThrough = computed(() => ({
  root: { class: 'relative flex w-full' },
  pcInputText: {
    root: {
      class: [
        'h-10 w-full rounded-l-md border bg-bg px-3 text-sm text-text placeholder:text-text-muted',
        'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary',
        'disabled:cursor-not-allowed disabled:bg-bg-subtle disabled:text-text-disabled',
        props.error ? 'border-danger' : 'border-border hover:enabled:border-text-muted',
      ],
    },
  },
  dropdown: {
    class: [
      'inline-flex h-10 items-center rounded-r-md border border-l-0 border-border bg-bg px-3 text-text-muted',
      'hover:bg-bg-subtle focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary',
    ],
  },
  dropdownIcon: { class: 'size-3', 'aria-hidden': 'true' },
  overlay: { class: 'mt-1 min-w-64 rounded-md border border-border bg-bg shadow-md' },
  listContainer: { class: 'max-h-64 overflow-auto' },
  list: { class: 'py-1' },
  option: ({ context }: OptionContext) => ({
    class: [
      'flex cursor-pointer items-center gap-2 px-3 py-2 text-sm',
      context.selected ? 'bg-primary-subtle font-medium text-primary-active' : 'text-text',
      context.focused && !context.selected ? 'bg-bg-subtle' : '',
    ],
  }),
  emptyMessage: { class: 'px-3 py-2 text-sm text-text-muted' },
}))
</script>

<template>
  <div class="flex flex-col gap-2">
    <span :id="labelId" class="text-sm font-medium" :class="{ 'sr-only': hideLabel }">{{ label }}</span>
    <AutoComplete
      :model-value="selected"
      :suggestions="suggestions"
      option-label="label"
      dropdown
      dropdown-mode="blank"
      force-selection
      complete-on-focus
      show-empty-message
      :empty-search-message="failed ? $t('base.searchSelect.failed') : $t('base.searchSelect.noMatches')"
      :delay="SEARCH_DELAY_MS"
      :loading="loading"
      :placeholder="placeholder ?? $t('base.searchSelect.placeholder')"
      :disabled="disabled"
      :append-to="appendTo"
      :invalid="Boolean(error)"
      :aria-labelledby="labelId"
      :aria-describedby="describedBy"
      :pt="passThrough"
      @complete="complete"
      @update:model-value="pick"
    >
      <template v-if="more" #footer>
        <p class="border-t border-border px-3 py-2 text-xs text-text-muted">
          <i18n-t v-if="seeAll" keypath="base.searchSelect.moreWithLink">
            <template #shown>{{ suggestions.length }}</template>
            <template #total>{{ total }}</template>
            <template #link>
              <RouterLink :to="seeAll" class="font-medium text-primary underline">{{ $t('base.searchSelect.seeAll') }}</RouterLink>
            </template>
          </i18n-t>
          <template v-else>{{ $t('base.searchSelect.more', { shown: suggestions.length, total }) }}</template>
        </p>
      </template>
    </AutoComplete>
    <p v-if="hint" :id="hintId" class="text-xs text-text-muted">{{ hint }}</p>
    <p v-if="error" :id="errorId" class="text-xs font-medium text-danger">{{ $t('base.field.error', { message: error }) }}</p>
  </div>
</template>
