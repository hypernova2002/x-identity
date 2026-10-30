<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { storeToRefs } from 'pinia'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDataTable from '@/components/base/BaseDataTable.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import type { DataTableColumn, DataTableFilter } from '@/components/base/types'
import PageHeader from '@/components/console/PageHeader.vue'
import StatCards from '@/components/console/StatCards.vue'
import { useAsync } from '@/composables/useAsync'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useListView } from '@/composables/useListView'
import { userService } from '@/services/account'
import { useSessionStore } from '@/stores/session'
import type { AccountRole, Invitation, User } from '@/types/api'
import { formatDateTime } from '@/utils/format'
import { accountRoleOptions, userStatusOptions } from '@/utils/options'

const { t } = useI18n()
const { account, me } = storeToRefs(useSessionStore())

const inviteEmail = ref('')
const inviteRole = ref<AccountRole>('member')
const invited = ref<string | null>(null)
const pendingDelete = ref<User | null>(null)

const grantableRoles = computed(() =>
  me.value?.role === 'owner' ? accountRoleOptions : accountRoleOptions.filter((option) => option.value !== 'owner'),
)

const userColumns: DataTableColumn[] = [
  { key: 'name', label: t('console.users.columns.name'), sortKey: 'name' },
  { key: 'role', label: t('console.users.columns.role'), sortKey: 'role' },
  { key: 'status', label: t('console.users.columns.status') },
  { key: 'last_sign_in_at', label: t('console.users.columns.lastSignIn'), sortKey: 'last_sign_in_at' },
  { key: 'actions', label: t('console.users.columns.actions'), srOnly: true },
]
const userFilters: DataTableFilter[] = [
  { type: 'select', key: 'role_eq', label: t('console.users.filters.role'), options: accountRoleOptions },
  { type: 'select', key: 'status_eq', label: t('console.users.filters.status'), options: userStatusOptions },
]

const invitationColumns: DataTableColumn[] = [
  { key: 'email', label: t('console.users.columns.email'), sortKey: 'email' },
  { key: 'role', label: t('console.users.columns.role'), sortKey: 'role' },
  { key: 'expires_at', label: t('console.users.columns.expires'), sortKey: 'expires_at' },
  { key: 'actions', label: t('console.users.columns.actions'), srOnly: true },
]
const invitationFilters: DataTableFilter[] = [{ type: 'select', key: 'role_eq', label: t('console.users.filters.role'), options: accountRoleOptions }]

const users = useListView((params) => userService.list(account.value!.uid, params), {
  defaultSort: 'created_at',
  storageKey: 'console-users',
  filterKeys: userFilters.map((filter) => filter.key),
  syncRoute: true,
})
const usersState = users.state

const invitations = useListView((params) => userService.listInvitations(account.value!.uid, params), {
  defaultSort: 'created_at',
  storageKey: 'invitations',
  filterKeys: invitationFilters.map((filter) => filter.key),
})
const invitationsState = invitations.state

const stats = useAsync(() => userService.stats(account.value!.uid))
const statCards = computed(() => [
  { label: t('console.users.stats.users'), value: stats.data.value?.total },
  { label: t('console.users.stats.admins'), value: stats.data.value?.admins },
  // Only account admins can see invitations; the API sends null to everyone else.
  ...(stats.data.value?.pending_invitations === null ? [] : [{ label: t('console.users.stats.invitations'), value: stats.data.value?.pending_invitations }]),
])

function reloadUsers() {
  return Promise.all([users.reload(), stats.reload()])
}

function reloadInvitations() {
  return Promise.all([invitations.reload(), stats.reload()])
}

onMounted(() => stats.reload())

function canManage(user: User) {
  if (!me.value || user.uid === me.value.uid) return false
  return me.value.role === 'owner' || user.role !== 'owner'
}

const userAction = useAsyncAction(async (user: User, changes: Partial<Pick<User, 'role' | 'status'>> | null) => {
  if (!account.value) return
  if (changes === null) await userService.remove(account.value.uid, user.uid)
  else await userService.update(account.value.uid, user.uid, changes)
  await reloadUsers()
})

const invite = useAsyncAction(async () => {
  if (!account.value) return
  invited.value = null
  const invitation = await userService.invite(account.value.uid, inviteEmail.value, inviteRole.value)
  invited.value = invitation.email
  inviteEmail.value = ''
  await reloadInvitations()
})

const revoke = useAsyncAction(async (invitation: Invitation) => {
  if (!account.value) return
  await userService.revokeInvitation(account.value.uid, invitation.uid)
  await reloadInvitations()
})

async function confirmDelete() {
  if (!pendingDelete.value) return
  await userAction.run(pendingDelete.value, null)
  pendingDelete.value = null
}
</script>

<template>
  <PageHeader :title="t('console.users.title')" :description="t('console.users.description')" />

  <StatCards :label="t('console.users.stats.label')" :cards="statCards" :loading="stats.loading.value" :error="stats.error.value" @retry="stats.reload" />

  <BaseAlert v-if="userAction.error.value" variant="danger">{{ userAction.error.value.message }}</BaseAlert>

  <BaseDataTable
    storage-key="console-users"
    v-model:state="usersState"
    :caption="t('console.users.caption')"
    :search-placeholder="t('console.users.searchPlaceholder')"
    :search-label="t('console.users.searchLabel')"
    :columns="userColumns"
    :filters="userFilters"
    :rows="users.rows.value"
    :row-key="(user) => user.uid"
    :total="users.total.value"
    :per-page="users.perPage.value"
    :loading="users.loading.value"
    :error="users.error.value"
    :empty-message="t('console.users.empty')"
    @reload="reloadUsers"
  >
    <template #cell-name="{ row }">
      <span class="font-medium">{{ row.name }}</span>
      <span class="block text-text-muted">{{ row.email }}</span>
      <span v-if="row.mfa_enabled" class="text-xs text-success">{{ t('console.users.mfaOn') }}</span>
    </template>
    <template #cell-role="{ row }">
      <BaseSelect
        v-if="canManage(row)"
        :model-value="row.role"
        :label="t('console.users.roleFor', { name: row.name })"
        hide-label
        :options="grantableRoles"
        :disabled="userAction.loading.value"
        @update:model-value="(role: AccountRole) => userAction.run(row, { role })"
      />
      <span v-else>{{ t(`options.accountRole.${row.role}`) }}</span>
    </template>
    <template #cell-status="{ row }">
      <span :class="row.status === 'active' ? 'text-success' : 'text-text-muted'" class="font-medium capitalize">
        {{ row.status === 'active' ? `● ${t('console.users.active')}` : `○ ${t('console.users.disabled')}` }}
      </span>
    </template>
    <template #cell-last_sign_in_at="{ row }">{{ formatDateTime(row.last_sign_in_at) }}</template>
    <template #cell-actions="{ row }">
      <div v-if="canManage(row)" class="flex justify-end gap-2">
        <BaseButton
          :label="row.status === 'active' ? t('common.actions.disable') : t('common.actions.enable')"
          variant="secondary"
          size="sm"
          :disabled="userAction.loading.value"
          @click="userAction.run(row, { status: row.status === 'active' ? 'disabled' : 'active' })"
        />
        <BaseButton
          :label="t('common.actions.delete')"
          variant="ghost"
          size="sm"
          :disabled="userAction.loading.value"
          @click="pendingDelete = row"
        />
      </div>
    </template>
  </BaseDataTable>

  <BaseDialog :visible="pendingDelete !== null" :title="t('console.users.deleteTitle')" @update:visible="(open: boolean) => !open && (pendingDelete = null)">
    <i18n-t keypath="console.users.deleteDescription" tag="p" class="text-sm">
      <template #email><strong>{{ pendingDelete?.email }}</strong></template>
    </i18n-t>
    <template #footer>
      <BaseButton :label="t('common.actions.cancel')" variant="secondary" @click="pendingDelete = null" />
      <BaseButton :label="t('console.users.deleteConfirm')" variant="danger" :loading="userAction.loading.value" @click="confirmDelete" />
    </template>
  </BaseDialog>

  <BaseCard :title="t('console.users.invitationsTitle')" :description="t('console.users.invitationsDescription')">
    <form class="flex flex-col gap-4" novalidate @submit.prevent="invite.run()">
      <BaseAlert v-if="invited" variant="success">{{ t('console.users.invited', { email: invited }) }}</BaseAlert>
      <BaseAlert v-if="invite.error.value && invite.error.value.details.length === 0" variant="danger">
        {{ invite.error.value.message }}
      </BaseAlert>
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseInput v-model="inviteEmail" :label="t('console.users.email')" type="email" required :error="invite.error.value?.fieldError('email')" />
        <BaseSelect v-model="inviteRole" :label="t('console.users.role')" :options="grantableRoles" />
      </div>
      <BaseButton type="submit" :label="t('console.users.sendInvitation')" :loading="invite.loading.value" class="self-start" />
    </form>

    <BaseAlert v-if="revoke.error.value" variant="danger">{{ revoke.error.value.message }}</BaseAlert>
    <BaseDataTable
      storage-key="invitations"
      v-model:state="invitationsState"
      :caption="t('console.users.invitationsCaption')"
      :search-placeholder="t('console.users.invitationsSearchPlaceholder')"
      :search-label="t('console.users.invitationsSearchLabel')"
      :columns="invitationColumns"
      :filters="invitationFilters"
      :rows="invitations.rows.value"
      :row-key="(invitation) => invitation.uid"
      :total="invitations.total.value"
      :per-page="invitations.perPage.value"
      :loading="invitations.loading.value"
      :error="invitations.error.value"
      :empty-message="t('console.users.invitationsEmpty')"
      @reload="reloadInvitations"
    >
      <template #cell-role="{ row }">{{ t(`options.accountRole.${row.role}`) }}</template>
      <template #cell-expires_at="{ row }">{{ formatDateTime(row.expires_at) }}</template>
      <template #cell-actions="{ row }">
        <BaseButton :label="t('console.users.revoke')" variant="ghost" size="sm" :disabled="revoke.loading.value" @click="revoke.run(row)" />
      </template>
    </BaseDataTable>
  </BaseCard>
</template>
