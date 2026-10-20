<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BasePagination from '@/components/base/BasePagination.vue'
import BaseTable from '@/components/base/BaseTable.vue'
import CreateProjectForm from '@/components/console/CreateProjectForm.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { projectService } from '@/services/account'
import type { Page } from '@/services/http'
import { useSessionStore } from '@/stores/session'
import type { Project } from '@/types/api'
import { formatDateTime } from '@/utils/format'

const router = useRouter()
const { account, isAccountAdmin } = storeToRefs(useSessionStore())

const page = ref(1)
const projects = ref<Page<Project>>({ items: [], total: 0, perPage: 25 })
const createOpen = ref(false)

const columns = [
  { key: 'name', label: 'Name' },
  { key: 'created_at', label: 'Created' },
]

const { loading, error, run: load } = useAsyncAction(async () => {
  if (!account.value) return
  projects.value = await projectService.list(account.value.uid, page.value)
})

watch(page, () => load())
onMounted(() => load())

function openProject(project: Project) {
  createOpen.value = false
  router.push({ name: 'project', params: { projectUid: project.uid } })
}
</script>

<template>
  <PageHeader title="Projects" description="Each project has its own users, settings and members.">
    <template v-if="isAccountAdmin" #actions>
      <BaseButton label="Create project" @click="createOpen = true" />
    </template>
  </PageHeader>

  <BaseAlert v-if="error" variant="danger">
    We couldn't load your projects. {{ error.message }}
    <BaseButton label="Try again" variant="ghost" size="sm" @click="load()" />
  </BaseAlert>

  <BaseTable
    caption="Projects"
    :columns="columns"
    :rows="projects.items"
    :row-key="(project) => project.uid"
    :loading="loading"
    empty-message="No projects yet."
  >
    <template #cell-name="{ row }">
      <RouterLink
        :to="{ name: 'project', params: { projectUid: row.uid } }"
        class="font-medium text-primary underline hover:text-primary-hover"
      >
        {{ row.name }}
      </RouterLink>
    </template>
    <template #cell-created_at="{ row }">{{ formatDateTime(row.created_at) }}</template>
    <template #empty>
      <span v-if="isAccountAdmin">No projects yet. Create one for each environment, such as Production and Staging.</span>
      <span v-else>You haven't been added to any projects yet. Ask an account admin to add you.</span>
    </template>
  </BaseTable>

  <BasePagination v-model:page="page" :total="projects.total" :per-page="projects.perPage" :disabled="loading" />

  <BaseDialog v-if="account" v-model:visible="createOpen" title="Create project">
    <CreateProjectForm :account-uid="account.uid" @created="openProject" />
  </BaseDialog>
</template>
