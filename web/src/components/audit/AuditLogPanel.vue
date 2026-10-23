<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BasePagination from '@/components/base/BasePagination.vue'
import BaseTable from '@/components/base/BaseTable.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import type { AuditEventFilters } from '@/services/account'
import type { Page } from '@/services/http'
import type { AuditEvent } from '@/types/api'
import { formatDateTime } from '@/utils/format'

const props = defineProps<{
  fetchPage: (page: number, filters: AuditEventFilters) => Promise<Page<AuditEvent>>
  showAppClient?: boolean
}>()

const route = useRoute()
const router = useRouter()

/** Links from other pages narrow the log to one target, actor or app client. */
const LINKED_FILTERS = { target_uid_eq: 'Target', actor_uid_eq: 'Actor', app_client_uid_eq: 'App client' } as const
type LinkedFilter = keyof typeof LINKED_FILTERS

const linkedFilters = computed(() =>
  (Object.keys(LINKED_FILTERS) as LinkedFilter[])
    .filter((key) => typeof route.query[key] === 'string')
    .map((key) => ({ key, label: LINKED_FILTERS[key], value: route.query[key] as string })),
)

const page = ref(1)
const actionFilter = ref(typeof route.query.action_start === 'string' ? route.query.action_start : '')
const appliedFilter = ref(actionFilter.value)
const events = ref<Page<AuditEvent>>({ items: [], total: 0, perPage: 25 })

const columns = [
  { key: 'occurred_at', label: 'When' },
  { key: 'action', label: 'Action' },
  { key: 'actor', label: 'Actor' },
  { key: 'target', label: 'Target' },
  ...(props.showAppClient ? [{ key: 'app_client_uid', label: 'App client' }] : []),
  { key: 'ip', label: 'IP address' },
]

const { loading, error, run: load } = useAsyncAction(async () => {
  const linked = Object.fromEntries(linkedFilters.value.map((filter) => [filter.key, filter.value]))
  events.value = await props.fetchPage(page.value, { ...linked, action_start: appliedFilter.value || undefined })
})

async function clearLinkedFilters() {
  await router.replace({ query: {} })
  if (page.value === 1) load()
  else page.value = 1
}

function applyFilter() {
  appliedFilter.value = actionFilter.value.trim()
  if (page.value === 1) load()
  else page.value = 1
}

watch(page, () => load())
onMounted(() => load())
</script>

<template>
  <form class="flex flex-wrap items-end gap-4" novalidate @submit.prevent="applyFilter">
    <div class="w-full max-w-xs">
      <BaseInput v-model="actionFilter" label="Action starts with" type="search" hint="For example user. or project." />
    </div>
    <BaseButton type="submit" label="Filter" variant="secondary" />
  </form>

  <div v-if="linkedFilters.length > 0" class="flex flex-wrap items-center gap-2 text-sm" role="status">
    <span v-for="filter in linkedFilters" :key="filter.key" class="rounded-full border border-border bg-bg-subtle px-3 py-1">
      {{ filter.label }}: <code class="font-mono text-xs">{{ filter.value }}</code>
    </span>
    <BaseButton label="Show all events" variant="ghost" size="sm" @click="clearLinkedFilters" />
  </div>

  <BaseAlert v-if="error" variant="danger">We couldn't load the audit log. {{ error.message }}</BaseAlert>

  <BaseTable
    caption="Audit events"
    :columns="columns"
    :rows="events.items"
    :row-key="(event) => event.uid"
    :loading="loading"
    :empty-message="appliedFilter || linkedFilters.length > 0 ? 'No events match these filters.' : 'No events recorded yet.'"
  >
    <template #cell-occurred_at="{ row }">{{ formatDateTime(row.occurred_at) }}</template>
    <template #cell-action="{ row }"><code class="font-mono text-xs">{{ row.action }}</code></template>
    <template #cell-actor="{ row }">{{ row.actor.label ?? row.actor.type }}</template>
    <template #cell-target="{ row }">{{ row.target?.label ?? row.target?.uid ?? '—' }}</template>
    <template #cell-app_client_uid="{ row }"><span class="font-mono text-xs">{{ row.app_client_uid ?? '—' }}</span></template>
    <template #cell-ip="{ row }"><span class="font-mono text-xs">{{ row.ip ?? '—' }}</span></template>
  </BaseTable>

  <BasePagination v-model:page="page" :total="events.total" :per-page="events.perPage" :disabled="loading" />
</template>
