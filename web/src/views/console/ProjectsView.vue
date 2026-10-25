<script setup lang="ts">
import { onMounted, ref } from 'vue'
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

const route = useRoute()
const { account, isAccountAdmin } = storeToRefs(useSessionStore())
const projectStore = useProjectStore()

const createOpen = ref(route.query.create === '1')

const columns: DataTableColumn[] = [
  { key: 'name', label: 'Name', sortKey: 'name' },
  { key: 'created_at', label: 'Created', sortKey: 'created_at' },
]
const filters: DataTableFilter[] = [
  { type: 'date', key: 'created_at_gteq', label: 'Created from' },
  { type: 'date', key: 'created_at_lteq', label: 'Created to' },
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
  <PageHeader title="Projects" description="Each project is a separate directory of end users, with its own applications, settings and members.">
    <template v-if="isAccountAdmin" #actions>
      <BaseButton label="Create project" @click="createOpen = true" />
    </template>
  </PageHeader>

  <BaseDataTable
    storage-key="projects"
    v-model:state="state"
    caption="Projects"
    search-placeholder="Search projects…"
    search-label="Search by name"
    :columns="columns"
    :filters="filters"
    :rows="rows"
    :row-key="(project) => project.uid"
    :total="total"
    :per-page="perPage"
    :loading="loading"
    :error="error"
    empty-message="No projects yet."
    @reload="reload"
  >
    <template #cell-name="{ row }">
      <RouterLink :to="{ name: 'project', params: { projectUid: row.uid } }" class="font-medium text-primary underline hover:text-primary-hover">
        {{ row.name }}
      </RouterLink>
    </template>
    <template #cell-created_at="{ row }">{{ formatDateTime(row.created_at) }}</template>
    <template #empty>
      <span v-if="isAccountAdmin">No projects yet. Create one for each environment, such as Production and Staging.</span>
      <span v-else>You haven't been added to any projects yet. Ask an account admin to add you.</span>
    </template>
  </BaseDataTable>

  <BaseCard
    v-if="isAccountAdmin && (deleted.data.value?.length || deleted.error.value || restored)"
    title="Scheduled for deletion"
    description="Deleted projects can be restored until their data is permanently deleted, 24 hours after they were deleted."
  >
    <BaseAlert v-if="restored" variant="success">{{ restored }} restored.</BaseAlert>
    <BaseAlert v-if="deleted.error.value" variant="danger">
      We couldn't load deleted projects. {{ deleted.error.value.message }}
      <BaseButton label="Retry" variant="secondary" size="sm" @click="deleted.reload()" />
    </BaseAlert>
    <BaseAlert v-if="restore.error.value" variant="danger">{{ restore.error.value.message }}</BaseAlert>
    <ul v-if="deleted.data.value?.length" class="flex flex-col divide-y divide-border">
      <li v-for="deletedProject in deleted.data.value" :key="deletedProject.uid" class="flex flex-wrap items-center justify-between gap-4 py-3">
        <div class="flex flex-col gap-1">
          <span class="font-medium">{{ deletedProject.name }}</span>
          <span class="text-sm text-text-muted">
            Deleted {{ formatDateTime(deletedProject.deleted_at) }} · permanently deleted in {{ timeLeft(deletedProject) }}
          </span>
        </div>
        <BaseButton
          label="Restore"
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
