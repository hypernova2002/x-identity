<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'

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

const page = ref(1)
const actionFilter = ref('')
const appliedFilter = ref('')
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
  events.value = await props.fetchPage(page.value, { action_start: appliedFilter.value || undefined })
})

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

  <BaseAlert v-if="error" variant="danger">We couldn't load the audit log. {{ error.message }}</BaseAlert>

  <BaseTable
    caption="Audit events"
    :columns="columns"
    :rows="events.items"
    :row-key="(event) => event.uid"
    :loading="loading"
    :empty-message="appliedFilter ? 'No events match this filter.' : 'No events recorded yet.'"
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
