<script setup lang="ts">
// Previous/next paging for server-paginated lists. OpenVue's Paginator renders page links,
// page-size and jump-to controls that these lists don't need.
import { computed } from 'vue'
import BaseButton from './BaseButton.vue'

const props = defineProps<{
  total: number
  perPage: number
  disabled?: boolean
}>()

const page = defineModel<number>('page', { required: true })

const pageCount = computed(() => Math.max(1, Math.ceil(props.total / Math.max(props.perPage, 1))))
</script>

<template>
  <nav v-if="pageCount > 1" aria-label="Pagination" class="flex items-center justify-between gap-4">
    <p class="text-sm text-text-muted">Page {{ page }} of {{ pageCount }} · {{ total }} total</p>
    <div class="flex gap-2">
      <BaseButton label="Previous" variant="secondary" size="sm" :disabled="disabled || page <= 1" @click="page -= 1" />
      <BaseButton label="Next" variant="secondary" size="sm" :disabled="disabled || page >= pageCount" @click="page += 1" />
    </div>
  </nav>
</template>
