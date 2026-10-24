<script setup lang="ts">
// Previous/next paging for server-paginated lists. OpenVue's Paginator renders page links,
// page-size and jump-to controls that these lists don't need.
import { computed } from 'vue'
import BaseButton from './BaseButton.vue'

const props = defineProps<{
  /** When `capped`, at least this many: the server stopped counting there. */
  total: number
  perPage: number
  capped?: boolean
  disabled?: boolean
}>()

const page = defineModel<number>('page', { required: true })

const emit = defineEmits<{
  countExactly: []
}>()

// A capped total is a lower bound, so there's always at least one more page past it.
const pageCount = computed(() => Math.max(1, Math.ceil((props.total + (props.capped ? 1 : 0)) / Math.max(props.perPage, 1))))
const totalLabel = computed(() => `${props.total.toLocaleString()}${props.capped ? '+' : ''} total`)
</script>

<template>
  <nav v-if="pageCount > 1" aria-label="Pagination" class="flex items-center justify-between gap-4">
    <p class="flex flex-wrap items-center gap-x-2 text-sm text-text-muted">
      <span>{{ capped ? `Page ${page}` : `Page ${page} of ${pageCount}` }} · {{ totalLabel }}</span>
      <button
        v-if="capped"
        type="button"
        class="rounded-sm text-xs font-medium text-primary underline hover:text-primary-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:text-text-disabled"
        :disabled="disabled"
        @click="emit('countExactly')"
      >
        Count exactly
      </button>
    </p>
    <div class="flex gap-2">
      <BaseButton label="Previous" variant="secondary" size="sm" :disabled="disabled || page <= 1" @click="page -= 1" />
      <BaseButton label="Next" variant="secondary" size="sm" :disabled="disabled || page >= pageCount" @click="page += 1" />
    </div>
  </nav>
</template>
