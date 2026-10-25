<script setup lang="ts">
import { ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDataTable from '@/components/base/BaseDataTable.vue'
import BaseSearchSelect from '@/components/base/BaseSearchSelect.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import type { DataTableColumn, DataTableFilter } from '@/components/base/types'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useListView } from '@/composables/useListView'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectService, userService } from '@/services/account'
import { lookupFrom, type LookupPage } from '@/services/list'
import type { ProjectMember, ProjectRole } from '@/types/api'
import { projectRoleOptions } from '@/utils/options'

const { accountUid, project, members, access } = useProjectContext()

const newMemberUid = ref('')
const newMemberRole = ref<ProjectRole>('viewer')

/** Console users who could join: the search's matches, minus current members. */
async function searchCandidates(term: string): Promise<LookupPage> {
  const page = await lookupFrom(
    (params) => userService.list(accountUid.value, params),
    (user) => ({ label: `${user.name} (${user.email})`, value: user.uid }),
  )(term)
  const items = page.items.filter((option) => !members.value.some((member) => member.user_uid === option.value))
  return { items, total: page.total - (page.items.length - items.length) }
}

const columns: DataTableColumn[] = [
  { key: 'name', label: 'Name', sortKey: 'name' },
  { key: 'email', label: 'Email', sortKey: 'email' },
  { key: 'role', label: 'Project role', sortKey: 'role' },
  { key: 'actions', label: 'Actions', srOnly: true },
]
const filters: DataTableFilter[] = [{ type: 'select', key: 'role_eq', label: 'Project role', options: projectRoleOptions }]

const list = useListView((params) => projectService.listMembers(accountUid.value, project.value!.uid, params), {
  defaultSort: 'created_at',
  storageKey: 'project-members',
  filterKeys: filters.map((filter) => filter.key),
  syncRoute: true,
})
const listState = list.state

const addMember = useAsyncAction(async () => {
  if (!project.value || !newMemberUid.value) return
  const member = await projectService.addMember(accountUid.value, project.value.uid, newMemberUid.value, newMemberRole.value)
  members.value = [...members.value, member]
  newMemberUid.value = ''
  await list.reload()
})

const memberAction = useAsyncAction(async (member: ProjectMember, role: ProjectRole | null) => {
  if (!project.value) return
  if (role === null) {
    await projectService.removeMember(accountUid.value, project.value.uid, member.user_uid)
    members.value = members.value.filter((existing) => existing.user_uid !== member.user_uid)
  } else {
    const updated = await projectService.updateMember(accountUid.value, project.value.uid, member.user_uid, role)
    members.value = members.value.map((existing) => (existing.user_uid === updated.user_uid ? updated : existing))
  }
  await list.reload()
})

</script>

<template>
  <BaseCard
    title="Members"
    description="Admins manage everything in the project; developers manage app clients and end users; viewers can only look. Account owners and admins can always access every project."
  >
    <BaseAlert v-if="memberAction.error.value" variant="danger">{{ memberAction.error.value.message }}</BaseAlert>
    <BaseDataTable
      storage-key="project-members"
      v-model:state="listState"
      caption="Project members"
      search-placeholder="Search members…"
      search-label="Search by name or email"
      :columns="columns"
      :filters="filters"
      :rows="list.rows.value"
      :row-key="(member) => member.user_uid"
      :total="list.total.value"
      :per-page="list.perPage.value"
      :loading="list.loading.value"
      :error="list.error.value"
      empty-message="No one has been added to this project yet."
      @reload="list.reload"
    >
      <template #cell-role="{ row }">
        <BaseSelect
          v-if="access.admin"
          :model-value="row.role"
          :label="`Project role for ${row.name}`"
          hide-label
          :options="projectRoleOptions"
          :disabled="memberAction.loading.value"
          @update:model-value="(role: ProjectRole) => memberAction.run(row, role)"
        />
        <span v-else class="capitalize">{{ row.role }}</span>
      </template>
      <template #cell-actions="{ row }">
        <BaseButton
          v-if="access.admin"
          :label="`Remove ${row.name}`"
          variant="ghost"
          size="sm"
          :disabled="memberAction.loading.value"
          @click="memberAction.run(row, null)"
        />
      </template>
    </BaseDataTable>

    <form v-if="access.admin" class="flex flex-col gap-4 border-t border-border pt-4" novalidate @submit.prevent="addMember.run()">
      <h3 class="font-semibold">Add a member</h3>
      <BaseAlert v-if="addMember.error.value" variant="danger">{{ addMember.error.value.message }}</BaseAlert>
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseSearchSelect
          v-model="newMemberUid"
          label="Console user"
          hint="People join the account by invitation, from Console users."
          :search="searchCandidates"
          :see-all="{ name: 'users' }"
        />
        <BaseSelect v-model="newMemberRole" label="Project role" :options="projectRoleOptions" />
      </div>
      <BaseButton type="submit" label="Add member" :loading="addMember.loading.value" :disabled="!newMemberUid" class="self-start" />
    </form>
  </BaseCard>
</template>
