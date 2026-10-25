<script setup lang="ts">
import BaseDataTable from '@/components/base/BaseDataTable.vue'
import type { DataTableColumn, DataTableFilter } from '@/components/base/types'
import { useListView } from '@/composables/useListView'
import type { Page } from '@/services/http'
import type { ListParams } from '@/services/list'
import type { AuditEvent } from '@/types/api'
import { formatDateTime } from '@/utils/format'

const props = defineProps<{
  fetchPage: (params: ListParams) => Promise<Page<AuditEvent>>
  showAppClient?: boolean
}>()

const columns: DataTableColumn[] = [
  { key: 'occurred_at', label: 'When', sortKey: 'occurred_at' },
  { key: 'action', label: 'Action' },
  { key: 'actor', label: 'Actor' },
  { key: 'target', label: 'Target' },
  ...(props.showAppClient ? [{ key: 'app', label: 'App' }] : []),
  { key: 'ip', label: 'IP address' },
]

/** Links from users, apps and providers arrive with one of the ID filters set. */
const filters: DataTableFilter[] = [
  { type: 'date', key: 'occurred_at_gteq', label: 'From' },
  { type: 'date', key: 'occurred_at_lteq', label: 'To' },
  { type: 'text', key: 'actor_uid_eq', label: 'Actor ID' },
  { type: 'text', key: 'target_uid_eq', label: 'Target ID' },
  ...(props.showAppClient
    ? [
        { type: 'text' as const, key: 'app_client_uid_eq', label: 'App client ID' },
        { type: 'text' as const, key: 'saml_app_uid_eq', label: 'SAML app ID' },
      ]
    : []),
]

const list = useListView((params) => props.fetchPage(params), {
  defaultSort: '-occurred_at',
  storageKey: 'audit-log',
  filterKeys: [...filters.map((filter) => filter.key), 'action_start', 'action_eq'],
  syncRoute: true,
})
const listState = list.state
</script>

<template>
  <BaseDataTable
    storage-key="audit-log"
    v-model:state="listState"
    caption="Audit events"
    search-placeholder="Search events…"
    search-label="Action starts with"
    :columns="columns"
    :filters="filters"
    :rows="list.rows.value"
    :row-key="(event) => event.uid"
    :total="list.total.value"
    :per-page="list.perPage.value"
    :capped="list.capped.value"
    :loading="list.loading.value"
    :error="list.error.value"
    empty-message="No events recorded yet."
    @reload="list.reload"
    @count-exactly="list.countExactly"
  >
    <template #cell-occurred_at="{ row }">{{ formatDateTime(row.occurred_at) }}</template>
    <template #cell-action="{ row }"><code class="font-mono text-xs">{{ row.action }}</code></template>
    <template #cell-actor="{ row }">{{ row.actor.label ?? row.actor.type }}</template>
    <template #cell-target="{ row }">{{ row.target?.label ?? row.target?.uid ?? '—' }}</template>
    <template #cell-app="{ row }"><span class="font-mono text-xs">{{ row.app_client_uid ?? row.saml_app_uid ?? '—' }}</span></template>
    <template #cell-ip="{ row }"><span class="font-mono text-xs">{{ row.ip ?? '—' }}</span></template>
  </BaseDataTable>
</template>
