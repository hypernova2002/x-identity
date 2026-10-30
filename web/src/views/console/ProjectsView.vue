<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRoute } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDataTable from '@/components/base/BaseDataTable.vue'
import type { DataTableColumn, DataTableFilter } from '@/components/base/types'
import CreateProjectDialog from '@/components/console/CreateProjectDialog.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import { useAsync } from '@/composables/useAsync'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useListView } from '@/composables/useListView'
import { projectService } from '@/services/account'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'
import type { DeletedProject } from '@/types/api'
import { formatDateTime, formatDuration } from '@/utils/format'

const { t } = useI18n()
const route = useRoute()
const { account, isAccountAdmin } = storeToRefs(useSessionStore())
const projectStore = useProjectStore()

const createOpen = ref(route.query.create === '1')

const columns: DataTableColumn[] = [
  { key: 'name', label: t('console.projects.columns.name'), sortKey: 'name' },
  { key: 'created_at', label: t('console.projects.columns.created'), sortKey: 'created_at' },
]
const filters: DataTableFilter[] = [
  { type: 'date', key: 'created_at_gteq', label: t('console.projects.filters.createdFrom') },
  { type: 'date', key: 'created_at_lteq', label: t('console.projects.filters.createdTo') },
]

const { state, rows, total, perPage, loading, error, reload } = useListView((params) => projectService.list(account.value!.uid, params), {
  defaultSort: 'created_at',
  storageKey: 'projects',
  filterKeys: filters.map((filter) => filter.key),
  syncRoute: true,
})

const deleted = useAsync(() => projectService.listDeleted(account.value!.uid))
const restoringUid = ref<string | null>(null)
const restored = ref<string | null>(null)

const restore = useAsyncAction(async (deletedProject: DeletedProject) => {
  restoringUid.value = deletedProject.uid
  try {
    projectStore.upsert(await projectService.restore(account.value!.uid, deletedProject.uid))
    restored.value = deletedProject.name
    await Promise.all([deleted.reload(), reload()])
  } finally {
    restoringUid.value = null
  }
})

function timeLeft(deletedProject: DeletedProject): string {
  return formatDuration((new Date(deletedProject.purge_at).getTime() - Date.now()) / 1000)
}

onMounted(() => {
  if (isAccountAdmin.value) deleted.reload()
})
</script>

<template>
  <PageHeader :title="t('console.projects.title')" :description="t('console.projects.description')">
    <template v-if="isAccountAdmin" #actions>
      <BaseButton :label="t('console.projects.create')" @click="createOpen = true" />
    </template>
  </PageHeader>

  <BaseDataTable
    storage-key="projects"
    v-model:state="state"
    :caption="t('console.projects.caption')"
    :search-placeholder="t('console.projects.searchPlaceholder')"
    :search-label="t('console.projects.searchLabel')"
    :columns="columns"
    :filters="filters"
    :rows="rows"
    :row-key="(project) => project.uid"
    :total="total"
    :per-page="perPage"
    :loading="loading"
    :error="error"
    :empty-message="t('console.projects.empty')"
    @reload="reload"
  >
    <template #cell-name="{ row }">
      <RouterLink :to="{ name: 'project', params: { projectUid: row.uid } }" class="font-medium text-primary underline hover:text-primary-hover">
        {{ row.name }}
      </RouterLink>
    </template>
    <template #cell-created_at="{ row }">{{ formatDateTime(row.created_at) }}</template>
    <template #empty>
      <span v-if="isAccountAdmin">{{ t('console.projects.emptyAdmin') }}</span>
      <span v-else>{{ t('console.projects.emptyMember') }}</span>
    </template>
  </BaseDataTable>

  <BaseCard
    v-if="isAccountAdmin && (deleted.data.value?.length || deleted.error.value || restored)"
    :title="t('console.projects.deletedTitle')"
    :description="t('console.projects.deletedDescription')"
  >
    <BaseAlert v-if="restored" variant="success">{{ t('console.projects.restored', { name: restored }) }}</BaseAlert>
    <BaseAlert v-if="deleted.error.value" variant="danger">
      {{ t('console.projects.deletedLoadFailed', { message: deleted.error.value.message }) }}
      <BaseButton :label="t('console.projects.retry')" variant="secondary" size="sm" @click="deleted.reload()" />
    </BaseAlert>
    <BaseAlert v-if="restore.error.value" variant="danger">{{ restore.error.value.message }}</BaseAlert>
    <ul v-if="deleted.data.value?.length" class="flex flex-col divide-y divide-border">
      <li v-for="deletedProject in deleted.data.value" :key="deletedProject.uid" class="flex flex-wrap items-center justify-between gap-4 py-3">
        <div class="flex flex-col gap-1">
          <span class="font-medium">{{ deletedProject.name }}</span>
          <span class="text-sm text-text-muted">
            {{ t('console.projects.deletedAt', { date: formatDateTime(deletedProject.deleted_at), time: timeLeft(deletedProject) }) }}
          </span>
        </div>
        <BaseButton
          :label="t('console.projects.restore')"
          variant="secondary"
          :loading="restoringUid === deletedProject.uid"
          :disabled="restoringUid !== null"
          @click="restore.run(deletedProject)"
        />
      </li>
    </ul>
  </BaseCard>

  <CreateProjectDialog v-model:visible="createOpen" />
</template>
