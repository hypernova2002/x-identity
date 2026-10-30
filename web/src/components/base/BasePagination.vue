<script setup lang="ts">
// Previous/next paging for server-paginated lists, the same above and below a table. OpenVue's
// Paginator renders page links and jump-to controls that these lists don't need.
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import BaseButton from './BaseButton.vue'

const props = withDefaults(
  defineProps<{
    /** When `capped`, at least this many: the server stopped counting there. */
    total: number
    perPage: number
    /** Rows on this page. */
    rowCount: number
    capped?: boolean
    disabled?: boolean
    /** Defaults to "Pagination". */
    label?: string
  }>(),
  { capped: false, disabled: false, label: undefined },
)

const { t, n } = useI18n()

const page = defineModel<number>('page', { required: true })

const emit = defineEmits<{
  countExactly: []
}>()

const size = computed(() => Math.max(props.perPage, 1))
// A capped total is a lower bound, so there's always at least one more page past it.
const pageCount = computed(() => Math.max(1, Math.ceil((props.total + (props.capped ? 1 : 0)) / size.value)))
const totalLabel = computed(() => `${n(props.total)}${props.capped ? '+' : ''}`)

/** "1–25 of 32": where this page is, and how many there are. */
const rangeLabel = computed(() => {
  if (props.rowCount === 0) return props.total === 0 ? t('base.pagination.noResults') : t('base.pagination.emptyPage', { total: totalLabel.value })
  const first = (page.value - 1) * size.value + 1
  return t('base.pagination.range', { first: n(first), last: n(first + props.rowCount - 1), total: totalLabel.value })
})
</script>

<template>
  <nav :aria-label="label ?? t('base.pagination.label')" class="flex items-center gap-2">
    <p class="flex items-center gap-2 text-sm whitespace-nowrap text-text-muted">
      <span>{{ rangeLabel }}</span>
      <button
        v-if="capped"
        type="button"
        class="rounded-sm text-xs font-medium text-primary underline hover:text-primary-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:text-text-disabled"
        :disabled="disabled"
        @click="emit('countExactly')"
      >
        {{ t('base.pagination.countExactly') }}
      </button>
    </p>
    <BaseButton :label="t('base.pagination.previous')" variant="secondary" :disabled="disabled || page <= 1" @click="page -= 1">
      <template #icon>
        <svg aria-hidden="true" viewBox="0 0 20 20" class="size-5" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
          <path d="M12 5l-5 5 5 5" />
        </svg>
      </template>
    </BaseButton>
    <BaseButton :label="t('base.pagination.next')" variant="secondary" :disabled="disabled || page >= pageCount" @click="page += 1">
      <template #icon>
        <svg aria-hidden="true" viewBox="0 0 20 20" class="size-5" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
          <path d="M8 5l5 5-5 5" />
        </svg>
      </template>
    </BaseButton>
  </nav>
</template>
