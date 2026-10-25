<script setup lang="ts">
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import type { ApiError } from '@/services/http'

export interface StatCard {
  label: string
  /** Undefined until the counts load. */
  value: number | undefined
}

defineProps<{
  /** Names the row for assistive technology, e.g. "End user counts". */
  label: string
  cards: readonly StatCard[]
  loading?: boolean
  error?: ApiError | null
}>()

const emit = defineEmits<{
  retry: []
}>()
</script>

<template>
  <section :aria-label="label" :aria-busy="loading || undefined">
    <BaseAlert v-if="error" variant="warning" title="We couldn't load these counts">
      {{ error.message }}
      <BaseButton label="Try again" variant="ghost" size="sm" @click="emit('retry')" />
    </BaseAlert>
    <dl v-else class="flex flex-wrap gap-4">
      <div v-for="card in cards" :key="card.label" class="flex min-w-40 flex-1 flex-col gap-1 rounded-lg border border-border bg-bg p-4 shadow-sm">
        <dt class="text-sm text-text-muted">{{ card.label }}</dt>
        <dd class="text-2xl font-semibold">
          <span v-if="card.value === undefined" class="inline-block h-8 w-16 animate-pulse rounded-md bg-bg-subtle motion-reduce:animate-none">
            <span class="sr-only">Loading</span>
          </span>
          <template v-else>{{ card.value.toLocaleString() }}</template>
        </dd>
      </div>
    </dl>
  </section>
</template>
