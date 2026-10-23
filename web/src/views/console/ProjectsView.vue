<script setup lang="ts">
import { ref } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseButton from '@/components/base/BaseButton.vue'
import BaseDataTable from '@/components/base/BaseDataTable.vue'
import type { DataTableColumn, DataTableFilter } from '@/components/base/types'
import CreateProjectDialog from '@/components/console/CreateProjectDialog.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import { useListView } from '@/composables/useListView'
import { projectService } from '@/services/account'
import { useSessionStore } from '@/stores/session'
import { formatDateTime } from '@/utils/format'

const route = useRoute()
const { account, isAccountAdmin } = storeToRefs(useSessionStore())

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
  filterKeys: filters.map((filter) => filter.key),
  syncRoute: true,
})
</script>

<template>
  <PageHeader title="Projects" description="Each project is a separate directory of end users, with its own applications, settings and members." />

  <BaseDataTable
    v-model:state="state"
    caption="Projects"
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
    @retry="reload"
  >
    <template v-if="isAccountAdmin" #actions>
      <BaseButton label="Create project" @click="createOpen = true" />
    </template>
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

  <CreateProjectDialog v-model:visible="createOpen" />
</template>
