<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { storeToRefs } from 'pinia'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BasePagination from '@/components/base/BasePagination.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import BaseTable from '@/components/base/BaseTable.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { userService } from '@/services/account'
import type { Page } from '@/services/http'
import { useSessionStore } from '@/stores/session'
import type { AccountRole, Invitation, User } from '@/types/api'
import { formatDateTime } from '@/utils/format'
import { accountRoleOptions } from '@/utils/options'

const { account, me } = storeToRefs(useSessionStore())

const page = ref(1)
const users = ref<Page<User>>({ items: [], total: 0, perPage: 25 })
const invitations = ref<Invitation[]>([])
const inviteEmail = ref('')
const inviteRole = ref<AccountRole>('member')
const invited = ref<string | null>(null)
const pendingDelete = ref<User | null>(null)

const grantableRoles = computed(() =>
  me.value?.role === 'owner' ? accountRoleOptions : accountRoleOptions.filter((option) => option.value !== 'owner'),
)

const userColumns = [
  { key: 'name', label: 'Name' },
  { key: 'role', label: 'Role' },
  { key: 'status', label: 'Status' },
  { key: 'last_sign_in_at', label: 'Last sign-in' },
  { key: 'actions', label: 'Actions', srOnly: true },
]

const invitationColumns = [
  { key: 'email', label: 'Email' },
  { key: 'role', label: 'Role' },
  { key: 'expires_at', label: 'Expires' },
  { key: 'actions', label: 'Actions', srOnly: true },
]

function canManage(user: User) {
  if (!me.value || user.uid === me.value.uid) return false
  return me.value.role === 'owner' || user.role !== 'owner'
}

const load = useAsyncAction(async () => {
  if (!account.value) return
  const [loadedUsers, loadedInvitations] = await Promise.all([
    userService.list(account.value.uid, page.value),
    userService.listInvitations(account.value.uid),
  ])
  users.value = loadedUsers
  invitations.value = loadedInvitations.items
})

const userAction = useAsyncAction(async (user: User, changes: Partial<Pick<User, 'role' | 'status'>> | null) => {
  if (!account.value) return
  if (changes === null) {
    await userService.remove(account.value.uid, user.uid)
    users.value = { ...users.value, items: users.value.items.filter((existing) => existing.uid !== user.uid), total: users.value.total - 1 }
    return
  }
  const updated = await userService.update(account.value.uid, user.uid, changes)
  users.value = { ...users.value, items: users.value.items.map((existing) => (existing.uid === updated.uid ? updated : existing)) }
})

const invite = useAsyncAction(async () => {
  if (!account.value) return
  invited.value = null
  const invitation = await userService.invite(account.value.uid, inviteEmail.value, inviteRole.value)
  invitations.value = [...invitations.value.filter((existing) => existing.email !== invitation.email), invitation]
  invited.value = invitation.email
  inviteEmail.value = ''
})

const revoke = useAsyncAction(async (invitation: Invitation) => {
  if (!account.value) return
  await userService.revokeInvitation(account.value.uid, invitation.uid)
  invitations.value = invitations.value.filter((existing) => existing.uid !== invitation.uid)
})

async function confirmDelete() {
  if (!pendingDelete.value) return
  await userAction.run(pendingDelete.value, null)
  pendingDelete.value = null
}

watch(page, () => load.run())
onMounted(() => load.run())
</script>

<template>
  <PageHeader title="Console users" description="People who manage this account in the console, and their account roles. Project end users are managed in each project's Directory." />

  <BaseAlert v-if="load.error.value" variant="danger">We couldn't load users. {{ load.error.value.message }}</BaseAlert>
  <BaseAlert v-if="userAction.error.value" variant="danger">{{ userAction.error.value.message }}</BaseAlert>

  <BaseTable
    caption="Users"
    :columns="userColumns"
    :rows="users.items"
    :row-key="(user) => user.uid"
    :loading="load.loading.value"
    empty-message="No users found."
  >
    <template #cell-name="{ row }">
      <span class="font-medium">{{ row.name }}</span>
      <span class="block text-text-muted">{{ row.email }}</span>
      <span v-if="row.mfa_enabled" class="text-xs text-success">MFA on</span>
    </template>
    <template #cell-role="{ row }">
      <BaseSelect
        v-if="canManage(row)"
        :model-value="row.role"
        :label="`Role for ${row.name}`"
        hide-label
        :options="grantableRoles"
        :disabled="userAction.loading.value"
        @update:model-value="(role: AccountRole) => userAction.run(row, { role })"
      />
      <span v-else class="capitalize">{{ row.role }}</span>
    </template>
    <template #cell-status="{ row }">
      <span :class="row.status === 'active' ? 'text-success' : 'text-text-muted'" class="font-medium capitalize">
        {{ row.status === 'active' ? '● Active' : '○ Disabled' }}
      </span>
    </template>
    <template #cell-last_sign_in_at="{ row }">{{ formatDateTime(row.last_sign_in_at) }}</template>
    <template #cell-actions="{ row }">
      <div v-if="canManage(row)" class="flex justify-end gap-2">
        <BaseButton
          :label="row.status === 'active' ? 'Disable' : 'Enable'"
          variant="secondary"
          size="sm"
          :disabled="userAction.loading.value"
          @click="userAction.run(row, { status: row.status === 'active' ? 'disabled' : 'active' })"
        />
        <BaseButton
          label="Delete"
          variant="ghost"
          size="sm"
          :disabled="userAction.loading.value"
          @click="pendingDelete = row"
        />
      </div>
    </template>
  </BaseTable>

  <BasePagination v-model:page="page" :total="users.total" :per-page="users.perPage" :disabled="load.loading.value" />

  <BaseDialog :visible="pendingDelete !== null" title="Delete user?" @update:visible="(open: boolean) => !open && (pendingDelete = null)">
    <p class="text-sm">
      This permanently deletes <strong>{{ pendingDelete?.email }}</strong> and signs them out everywhere. To keep their history
      but stop them signing in, disable them instead.
    </p>
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="pendingDelete = null" />
      <BaseButton label="Delete user" variant="danger" :loading="userAction.loading.value" @click="confirmDelete" />
    </template>
  </BaseDialog>

  <BaseCard title="Invitations" description="Invited people get an email with a link to create their user. Links expire after 7 days.">
    <form class="flex flex-col gap-4" novalidate @submit.prevent="invite.run()">
      <BaseAlert v-if="invited" variant="success">Invitation sent to {{ invited }}.</BaseAlert>
      <BaseAlert v-if="invite.error.value && invite.error.value.details.length === 0" variant="danger">
        {{ invite.error.value.message }}
      </BaseAlert>
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseInput v-model="inviteEmail" label="Email" type="email" required :error="invite.error.value?.fieldError('email')" />
        <BaseSelect v-model="inviteRole" label="Role" :options="grantableRoles" />
      </div>
      <BaseButton type="submit" label="Send invitation" :loading="invite.loading.value" class="self-start" />
    </form>

    <BaseAlert v-if="revoke.error.value" variant="danger">{{ revoke.error.value.message }}</BaseAlert>
    <BaseTable
      caption="Pending invitations"
      :columns="invitationColumns"
      :rows="invitations"
      :row-key="(invitation) => invitation.uid"
      empty-message="No pending invitations."
    >
      <template #cell-role="{ row }"><span class="capitalize">{{ row.role }}</span></template>
      <template #cell-expires_at="{ row }">{{ formatDateTime(row.expires_at) }}</template>
      <template #cell-actions="{ row }">
        <BaseButton label="Revoke" variant="ghost" size="sm" :disabled="revoke.loading.value" @click="revoke.run(row)" />
      </template>
    </BaseTable>
  </BaseCard>
</template>
