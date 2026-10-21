<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import BaseTable from '@/components/base/BaseTable.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectService, userService } from '@/services/account'
import type { ProjectMember, ProjectRole, User } from '@/types/api'
import { projectRoleOptions } from '@/utils/options'

const { accountUid, project, members, access } = useProjectContext()

const accountUsers = ref<User[]>([])
const newMemberUid = ref('')
const newMemberRole = ref<ProjectRole>('viewer')

const candidateOptions = computed(() =>
  accountUsers.value
    .filter((user) => !members.value.some((member) => member.user_uid === user.uid))
    .map((user) => ({ label: `${user.name} (${user.email})`, value: user.uid })),
)

const columns = [
  { key: 'name', label: 'Name' },
  { key: 'email', label: 'Email' },
  { key: 'role', label: 'Project role' },
  { key: 'actions', label: 'Actions', srOnly: true },
]

const loadUsers = useAsyncAction(async () => {
  if (access.value.admin) accountUsers.value = (await userService.list(accountUid.value, 1)).items
})

const addMember = useAsyncAction(async () => {
  if (!project.value || !newMemberUid.value) return
  const member = await projectService.addMember(accountUid.value, project.value.uid, newMemberUid.value, newMemberRole.value)
  members.value = [...members.value, member]
  newMemberUid.value = ''
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
})

onMounted(() => loadUsers.run())
</script>

<template>
  <BaseCard
    title="Members"
    description="Admins manage everything in the project; developers manage app clients and end users; viewers can only look. Account owners and admins can always access every project."
  >
    <BaseAlert v-if="memberAction.error.value" variant="danger">{{ memberAction.error.value.message }}</BaseAlert>
    <BaseTable
      caption="Project members"
      :columns="columns"
      :rows="members"
      :row-key="(member) => member.user_uid"
      empty-message="No one has been added to this project yet."
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
    </BaseTable>

    <form v-if="access.admin" class="flex flex-col gap-4 border-t border-border pt-4" novalidate @submit.prevent="addMember.run()">
      <h3 class="font-semibold">Add a member</h3>
      <BaseAlert v-if="addMember.error.value" variant="danger">{{ addMember.error.value.message }}</BaseAlert>
      <p v-if="candidateOptions.length === 0" class="text-sm text-text-muted">
        Everyone in the account is already a member. Invite more people from the Users page.
      </p>
      <div v-else class="grid gap-4 sm:grid-cols-2">
        <BaseSelect v-model="newMemberUid" label="User" :options="candidateOptions" />
        <BaseSelect v-model="newMemberRole" label="Project role" :options="projectRoleOptions" />
      </div>
      <BaseButton type="submit" label="Add member" :loading="addMember.loading.value" :disabled="!newMemberUid" class="self-start" />
    </form>
  </BaseCard>
</template>
