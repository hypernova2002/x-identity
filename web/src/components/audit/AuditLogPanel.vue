<script setup lang="ts">
import { useI18n } from 'vue-i18n'

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

const { t } = useI18n()

const columns: DataTableColumn[] = [
  { key: 'occurred_at', label: t('audit.columns.when'), sortKey: 'occurred_at' },
  { key: 'action', label: t('audit.columns.action') },
  { key: 'actor', label: t('audit.columns.actor') },
  { key: 'target', label: t('audit.columns.target') },
  ...(props.showAppClient ? [{ key: 'app', label: t('audit.columns.app') }] : []),
  { key: 'ip', label: t('audit.columns.ip') },
]

/** Links from users, apps and providers arrive with one of the ID filters set. */
const filters: DataTableFilter[] = [
  { type: 'date', key: 'occurred_at_gteq', label: t('audit.filters.from') },
  { type: 'date', key: 'occurred_at_lteq', label: t('audit.filters.to') },
  { type: 'text', key: 'actor_uid_eq', label: t('audit.filters.actor') },
  { type: 'text', key: 'target_uid_eq', label: t('audit.filters.target') },
  ...(props.showAppClient
    ? [
        { type: 'text' as const, key: 'app_client_uid_eq', label: t('audit.filters.appClient') },
        { type: 'text' as const, key: 'saml_app_uid_eq', label: t('audit.filters.samlApp') },
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
    :caption="t('audit.caption')"
    :search-placeholder="t('audit.searchPlaceholder')"
    :search-label="t('audit.searchLabel')"
    :columns="columns"
    :filters="filters"
    :rows="list.rows.value"
    :row-key="(event) => event.uid"
    :total="list.total.value"
    :per-page="list.perPage.value"
    :capped="list.capped.value"
    :loading="list.loading.value"
    :error="list.error.value"
    :empty-message="t('audit.empty')"
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
