<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRouter } from 'vue-router'

import BaseActionMenu, { type ActionMenuItem } from '@/components/base/BaseActionMenu.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseDataTable from '@/components/base/BaseDataTable.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import type { DataTableColumn, DataTableFilter } from '@/components/base/types'
import StatCards from '@/components/console/StatCards.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import CustomAttributeFields from '@/components/project/CustomAttributeFields.vue'
import EndUserActionDialog from '@/components/project/EndUserActionDialog.vue'
import RoutePageHeader from '@/components/console/RoutePageHeader.vue'
import { useAsync } from '@/composables/useAsync'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useEndUserActions } from '@/composables/useEndUserActions'
import { useListView } from '@/composables/useListView'
import { useProjectContext } from '@/composables/useProjectContext'
import { useProjectLookups } from '@/composables/useProjectLookups'
import { projectAdminService } from '@/services/project'
import type { AttributeDefinition, EndUser } from '@/types/api'
import { type AttributeDraft, toCustomAttributes } from '@/utils/customAttributes'
import { formatDateTime } from '@/utils/format'
import { userStatusOptions } from '@/utils/options'

const { t } = useI18n()

const router = useRouter()
const { accountUid, project, access } = useProjectContext()

const definitions = ref<AttributeDefinition[]>([])
const lookups = useProjectLookups()
const notice = ref<string | null>(null)

const filters = computed<DataTableFilter[]>(() => [
  { type: 'select', key: 'status_eq', label: t('project.projectEndUsers.status'), options: userStatusOptions },
  { type: 'lookup', key: 'in_group', label: t('project.projectEndUsers.group'), search: lookups.searchGroups, resolveLabel: lookups.groupName, seeAll: lookups.allGroups.value },
  {
    type: 'select',
    key: 'with_verified_email',
    label: t('project.projectEndUsers.email'),
    options: [
      { label: t('project.projectEndUsers.verified'), value: 'true' },
      { label: t('project.projectEndUsers.notVerified'), value: 'false' },
    ],
  },
  {
    type: 'select',
    key: 'with_mfa',
    label: t('project.projectEndUsers.mfa'),
    options: [
      { label: t('project.projectEndUsers.on'), value: 'true' },
      { label: t('project.projectEndUsers.off'), value: 'false' },
    ],
  },
  { type: 'select', key: 'invitation_pending', label: t('project.projectEndUsers.invitation'), options: [{ label: t('project.projectEndUsers.pending'), value: 'true' }] },
])

const columns: DataTableColumn[] = [
  { key: 'email', label: t('project.projectEndUsers.endUser'), sortKey: 'email' },
  { key: 'status', label: t('project.projectEndUsers.status'), sortKey: 'status' },
  { key: 'mfa_enabled', label: t('project.projectEndUsers.mfa') },
  { key: 'groups', label: t('project.projectEndUsers.groups') },
  { key: 'last_sign_in_at', label: t('project.projectEndUsers.lastSignIn'), sortKey: 'last_sign_in_at' },
  { key: 'actions', label: t('project.projectEndUsers.actions'), srOnly: true },
]

const list = useListView((params) => projectAdminService.listEndUsers(accountUid.value, project.value!.uid, params), {
  defaultSort: 'created_at',
  storageKey: 'end-users',
  filterKeys: ['status_eq', 'with_verified_email', 'with_mfa', 'invitation_pending', 'in_group'],
  syncRoute: true,
})
const listState = list.state

const stats = useAsync(() => projectAdminService.endUserStats(accountUid.value, project.value!.uid))
const statCards = computed(() => [
  { label: t('project.projectEndUsers.endUsers'), value: stats.data.value?.total },
  { label: t('project.projectEndUsers.active'), value: stats.data.value?.active },
  { label: t('project.projectEndUsers.disabled'), value: stats.data.value?.disabled },
  { label: t('project.projectEndUsers.invitationPending'), value: stats.data.value?.invitation_pending },
  { label: t('project.projectEndUsers.signedInLastDays'), value: stats.data.value?.signed_in_recently },
])

function reloadAll() {
  list.reload()
  stats.reload()
}

const loadLookups = useAsyncAction(async () => {
  if (!project.value) return
  definitions.value = (await projectAdminService.listAttributes(accountUid.value, project.value.uid)).items
})

const userLink = (endUser: EndUser) => ({ name: 'project-end-user', params: { projectUid: project.value?.uid, endUserUid: endUser.uid } })

const actions = useEndUserActions(
  () => (project.value ? { accountUid: accountUid.value, projectUid: project.value.uid } : null),
  ({ notice: message }) => {
    notice.value = message
    reloadAll()
  },
)

function menuItems(endUser: EndUser): ActionMenuItem[] {
  return [
    ...(endUser.invitation_pending ? [{ label: t('project.projectEndUsers.resendInvitation'), action: () => actions.request('resend_invitation', endUser) }] : []),
    { label: t('project.projectEndUsers.signOutEverywhere'), action: () => actions.request('sign_out', endUser) },
    ...(endUser.mfa_enabled ? [{ label: t('project.projectEndUsers.resetMfa'), danger: true, action: () => actions.request('reset_mfa', endUser) }] : []),
    endUser.status === 'active'
      ? { label: t('project.projectEndUsers.disable'), danger: true, action: () => actions.request('disable', endUser) }
      : { label: t('project.projectEndUsers.enable'), action: () => actions.request('enable', endUser) },
    { label: t('project.projectEndUsers.delete'), danger: true, action: () => actions.request('delete', endUser) },
  ]
}

// Creating an end user, optionally with an invitation to set a password.
const createOpen = ref(false)
const newEmail = ref('')
const newName = ref('')
const sendInvitation = ref(true)
const newAttributes = ref<AttributeDraft>({})

const create = useAsyncAction(async () => {
  if (!project.value) return
  const created = await projectAdminService.createEndUser(accountUid.value, project.value.uid, {
    email: newEmail.value,
    name: newName.value.trim() || null,
    custom_attributes: toCustomAttributes(definitions.value, newAttributes.value),
    send_invitation: sendInvitation.value,
  })
  createOpen.value = false
  newEmail.value = ''
  newName.value = ''
  newAttributes.value = {}
  await router.push(userLink(created))
})

onMounted(() => {
  loadLookups.run()
  stats.reload()
})
</script>

<template>
  <RoutePageHeader>
    <template v-if="access.developer" #actions>
      <BaseButton :label="$t('project.projectEndUsers.createEndUser')" @click="createOpen = true" />
    </template>
  </RoutePageHeader>

  <StatCards :label="$t('project.projectEndUsers.endUserCounts')" :cards="statCards" :loading="stats.loading.value" :error="stats.error.value" @retry="stats.reload" />

  <BaseCard>
    <BaseAlert v-if="notice" variant="success">{{ notice }}</BaseAlert>
    <BaseAlert v-if="actions.perform.error.value && !actions.pending.value" variant="danger">{{ actions.perform.error.value.message }}</BaseAlert>

    <BaseDataTable
      storage-key="end-users"
      v-model:state="listState"
      :caption="$t('project.projectEndUsers.endUsers')"
      :search-placeholder="$t('project.projectEndUsers.searchEndUsers')"
      :search-label="$t('project.projectEndUsers.searchByEmailNameOr')"
      :columns="columns"
      :filters="filters"
      :rows="list.rows.value"
      :row-key="(endUser) => endUser.uid"
      :total="list.total.value"
      :per-page="list.perPage.value"
      :capped="list.capped.value"
      :loading="list.loading.value"
      :error="list.error.value"
      :empty-message="$t('project.projectEndUsers.noEndUsersYetThey')"
      @reload="reloadAll"
      @count-exactly="list.countExactly"
    >
      <template #cell-email="{ row }">
        <RouterLink :to="userLink(row)" class="font-medium text-primary underline-offset-2 hover:underline">{{ row.email }}</RouterLink>
        <span v-if="row.name" class="block text-text-muted">{{ row.name }}</span>
        <code class="block font-mono text-xs text-text-muted">{{ row.uid }}</code>
      </template>
      <template #cell-status="{ row }">
        <span class="flex flex-wrap gap-1">
          <StatusBadge :tone="row.status === 'active' ? 'success' : 'danger'" :label="row.status === 'active' ? $t('project.projectEndUsers.active') : $t('project.projectEndUsers.disabled')" />
          <StatusBadge v-if="row.invitation_pending" tone="info" :label="$t('project.projectEndUsers.invitationPending')" />
          <StatusBadge v-else-if="!row.email_verified" tone="warning" :label="$t('project.projectEndUsers.emailNotVerified')" />
        </span>
      </template>
      <template #cell-mfa_enabled="{ row }">
        <StatusBadge :tone="row.mfa_enabled ? 'success' : 'neutral'" :label="row.mfa_enabled ? $t('project.projectEndUsers.on') : $t('project.projectEndUsers.off')" />
      </template>
      <template #cell-groups="{ row }">
        <span v-if="row.groups.length === 0" class="text-text-muted">{{ $t('project.projectEndUsers.none') }}</span>
        <span v-else class="text-xs">
          {{ row.groups.slice(0, 2).map((group) => group.name).join(', ') }}<template v-if="row.groups.length > 2"> +{{ row.groups.length - 2 }}</template>
        </span>
      </template>
      <template #cell-last_sign_in_at="{ row }">
        <span class="text-xs">{{ row.last_sign_in_at ? formatDateTime(row.last_sign_in_at) : $t('project.projectEndUsers.never') }}</span>
      </template>
      <template #cell-actions="{ row }">
        <div class="flex items-center justify-end gap-2">
          <RouterLink :to="userLink(row)" class="text-sm font-medium text-primary underline">{{ $t('project.projectEndUsers.view') }}</RouterLink>
          <BaseActionMenu v-if="access.developer" :items="menuItems(row)" :label="$t('project.projectEndUsers.moreActionsFor', { email: row.email })" />
        </div>
      </template>
    </BaseDataTable>
  </BaseCard>

  <EndUserActionDialog
    :pending="actions.pending.value"
    :loading="actions.perform.loading.value"
    :error="actions.perform.error.value"
    @confirm="actions.confirm()"
    @cancel="actions.pending.value = null"
  />

  <BaseDialog v-model:visible="createOpen" :title="$t('project.projectEndUsers.createEndUser')">
    <form id="create-end-user" class="flex flex-col gap-4" novalidate @submit.prevent="create.run()">
      <BaseAlert v-if="create.error.value && create.error.value.details.length === 0" variant="danger">{{ create.error.value.message }}</BaseAlert>
      <BaseInput v-model="newEmail" :label="$t('project.projectEndUsers.email')" type="email" required :error="create.error.value?.fieldError('email')" />
      <BaseInput v-model="newName" :label="$t('project.projectEndUsers.name')" :error="create.error.value?.fieldError('name')" />
      <CustomAttributeFields v-model="newAttributes" :definitions="definitions" :error="create.error.value" />
      <BaseCheckbox
        v-model="sendInvitation"
        :label="$t('project.projectEndUsers.emailAnInvitationToSet')"
        :hint="$t('project.projectEndUsers.theInvitationContainsACode')"
      />
    </form>
    <template #footer>
      <BaseButton :label="$t('project.projectEndUsers.cancel')" variant="secondary" @click="createOpen = false" />
      <BaseButton :label="$t('project.projectEndUsers.create')" type="submit" form="create-end-user" :loading="create.loading.value" />
    </template>
  </BaseDialog>
</template>
