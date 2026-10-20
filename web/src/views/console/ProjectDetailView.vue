<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import BaseTable from '@/components/base/BaseTable.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { projectService, userService } from '@/services/account'
import { useSessionStore } from '@/stores/session'
import type { Project, ProjectMember, ProjectRole, User } from '@/types/api'
import { projectRoleOptions } from '@/utils/options'

const route = useRoute()
const router = useRouter()
const { account, me, isAccountAdmin } = storeToRefs(useSessionStore())

const projectUid = computed(() => String(route.params.projectUid))
const project = ref<Project | null>(null)
const members = ref<ProjectMember[]>([])
const accountUsers = ref<User[]>([])
const name = ref('')
const newMemberUid = ref('')
const newMemberRole = ref<ProjectRole>('viewer')
const deleteOpen = ref(false)
const saved = ref(false)

const canManage = computed(
  () => isAccountAdmin.value || members.value.some((member) => member.user_uid === me.value?.uid && member.role === 'admin'),
)

const candidateOptions = computed(() =>
  accountUsers.value
    .filter((user) => !members.value.some((member) => member.user_uid === user.uid))
    .map((user) => ({ label: `${user.name} (${user.email})`, value: user.uid })),
)

const memberColumns = [
  { key: 'name', label: 'Name' },
  { key: 'email', label: 'Email' },
  { key: 'role', label: 'Project role' },
  { key: 'actions', label: 'Actions', srOnly: true },
]

const load = useAsyncAction(async () => {
  if (!account.value) return
  const [loadedProject, loadedMembers, loadedUsers] = await Promise.all([
    projectService.get(account.value.uid, projectUid.value),
    projectService.listMembers(account.value.uid, projectUid.value),
    userService.list(account.value.uid, 1),
  ])
  project.value = loadedProject
  name.value = loadedProject.name
  members.value = loadedMembers.items
  accountUsers.value = loadedUsers.items
})

const rename = useAsyncAction(async () => {
  if (!account.value) return
  saved.value = false
  project.value = await projectService.update(account.value.uid, projectUid.value, name.value)
  saved.value = true
})

const addMember = useAsyncAction(async () => {
  if (!account.value || !newMemberUid.value) return
  const member = await projectService.addMember(account.value.uid, projectUid.value, newMemberUid.value, newMemberRole.value)
  members.value = [...members.value, member]
  newMemberUid.value = ''
})

const memberAction = useAsyncAction(async (member: ProjectMember, role: ProjectRole | null) => {
  if (!account.value) return
  if (role === null) {
    await projectService.removeMember(account.value.uid, projectUid.value, member.user_uid)
    members.value = members.value.filter((existing) => existing.user_uid !== member.user_uid)
  } else {
    const updated = await projectService.updateMember(account.value.uid, projectUid.value, member.user_uid, role)
    members.value = members.value.map((existing) => (existing.user_uid === updated.user_uid ? updated : existing))
  }
})

const destroy = useAsyncAction(async () => {
  if (!account.value) return
  await projectService.remove(account.value.uid, projectUid.value)
  await router.push({ name: 'projects' })
})

onMounted(() => load.run())
</script>

<template>
  <p v-if="load.loading.value && !project" class="text-sm text-text-muted" role="status">Loading project…</p>

  <BaseAlert v-else-if="load.error.value?.code === 'not_found'" variant="danger" title="Project not found">
    It may have been deleted, or you don't have access to it.
    <RouterLink :to="{ name: 'projects' }" class="font-medium text-primary underline">Back to projects</RouterLink>
  </BaseAlert>
  <BaseAlert v-else-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>

  <template v-if="project">
    <PageHeader :title="project.name" :description="`Project ${project.uid}`">
      <template v-if="isAccountAdmin" #actions>
        <BaseButton label="Delete project" variant="danger" @click="deleteOpen = true" />
      </template>
    </PageHeader>

    <BaseCard v-if="canManage" title="Settings">
      <form class="flex flex-col gap-4" novalidate @submit.prevent="rename.run()">
        <BaseAlert v-if="saved" variant="success">Project renamed.</BaseAlert>
        <BaseInput v-model="name" label="Project name" required :error="rename.error.value?.fieldError('name')" />
        <BaseButton type="submit" label="Save" :loading="rename.loading.value" class="self-start" />
      </form>
    </BaseCard>

    <BaseCard title="Members" description="Account owners and admins can always access every project.">
      <BaseAlert v-if="memberAction.error.value" variant="danger">{{ memberAction.error.value.message }}</BaseAlert>
      <BaseTable
        caption="Project members"
        :columns="memberColumns"
        :rows="members"
        :row-key="(member) => member.user_uid"
        :loading="load.loading.value"
        empty-message="No one has been added to this project yet."
      >
        <template #cell-role="{ row }">
          <BaseSelect
            v-if="canManage"
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
            v-if="canManage"
            :label="`Remove ${row.name}`"
            variant="ghost"
            size="sm"
            :disabled="memberAction.loading.value"
            @click="memberAction.run(row, null)"
          />
        </template>
      </BaseTable>

      <form v-if="canManage" class="flex flex-col gap-4 border-t border-border pt-4" novalidate @submit.prevent="addMember.run()">
        <h3 class="font-semibold">Add a member</h3>
        <BaseAlert v-if="addMember.error.value" variant="danger">{{ addMember.error.value.message }}</BaseAlert>
        <p v-if="candidateOptions.length === 0" class="text-sm text-text-muted">
          Everyone in the account is already a member. Invite more people from the Users page.
        </p>
        <div v-else class="grid gap-4 sm:grid-cols-2">
          <BaseSelect v-model="newMemberUid" label="User" :options="candidateOptions" />
          <BaseSelect v-model="newMemberRole" label="Project role" :options="projectRoleOptions" />
        </div>
        <BaseButton
          type="submit"
          label="Add member"
          :loading="addMember.loading.value"
          :disabled="!newMemberUid"
          class="self-start"
        />
      </form>
    </BaseCard>

    <BaseDialog v-model:visible="deleteOpen" title="Delete project?">
      <p class="text-sm">
        This permanently deletes <strong>{{ project.name }}</strong> and removes all of its members. This can't be undone.
      </p>
      <BaseAlert v-if="destroy.error.value" variant="danger">{{ destroy.error.value.message }}</BaseAlert>
      <template #footer>
        <BaseButton label="Cancel" variant="secondary" @click="deleteOpen = false" />
        <BaseButton label="Delete project" variant="danger" :loading="destroy.loading.value" @click="destroy.run()" />
      </template>
    </BaseDialog>
  </template>
</template>
