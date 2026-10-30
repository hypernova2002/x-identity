<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink, type RouteLocationRaw } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import type { Page } from '@/services/http'
import type { ListParams } from '@/services/list'
import type { AuditEvent } from '@/types/api'
import { formatDateTime } from '@/utils/format'

/** A short list of the latest matching events, linking to the full audit log. */
const props = withDefaults(
  defineProps<{
    fetchPage: (params: ListParams) => Promise<Page<AuditEvent>>
    /** `q` predicates of the audit log, e.g. `target_uid_eq`. */
    filters: Record<string, string>
    emptyMessage: string
    fullLog?: RouteLocationRaw
    limit?: number
  }>(),
  { fullLog: undefined, limit: 10 },
)

const events = ref<Page<AuditEvent>>({ items: [], total: 0, perPage: 0 })

const load = useAsyncAction(async () => {
  events.value = await props.fetchPage({ perPage: props.limit, filters: props.filters })
})

onMounted(() => load.run())
</script>

<template>
  <BaseAlert v-if="load.error.value" variant="danger">{{ $t('audit.activity.loadFailed', { message: load.error.value.message }) }}</BaseAlert>
  <p v-else-if="load.loading.value" class="text-sm text-text-muted" role="status">{{ $t('audit.activity.loading') }}</p>
  <p v-else-if="events.items.length === 0" class="text-sm text-text-muted">{{ emptyMessage }}</p>
  <ul v-else class="flex flex-col divide-y divide-border">
    <li v-for="event in events.items" :key="event.uid" class="flex flex-wrap items-baseline justify-between gap-2 py-2 text-sm">
      <span class="flex flex-col">
        <code class="font-mono text-xs">{{ event.action }}</code>
        <span class="text-xs text-text-muted">
          {{ event.actor.label ?? event.actor.type }}<template v-if="event.target">{{ ` → ${event.target.label ?? event.target.uid}` }}</template>
        </span>
      </span>
      <span class="text-xs text-text-muted">{{ formatDateTime(event.occurred_at) }}</span>
    </li>
  </ul>
  <RouterLink v-if="fullLog && events.total > events.items.length" :to="fullLog" class="text-sm font-medium text-primary underline">
    {{ $t('audit.activity.seeAll', { count: events.total }) }}
  </RouterLink>
</template>
