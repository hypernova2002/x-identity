<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'

import BaseActionMenu, { type ActionMenuItem } from '@/components/base/BaseActionMenu.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BasePagination from '@/components/base/BasePagination.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import BaseTable from '@/components/base/BaseTable.vue'
import type { SelectOption } from '@/components/base/types'
import StatusBadge from '@/components/console/StatusBadge.vue'
import CustomAttributeFields from '@/components/project/CustomAttributeFields.vue'
import EndUserActionDialog from '@/components/project/EndUserActionDialog.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useEndUserActions } from '@/composables/useEndUserActions'
import { useProjectContext } from '@/composables/useProjectContext'
import type { Page } from '@/services/http'
import { projectAdminService, type EndUserFilters } from '@/services/project'
import type { AttributeDefinition, EndUser, Group } from '@/types/api'
import { type AttributeDraft, toCustomAttributes } from '@/utils/customAttributes'
import { formatDateTime } from '@/utils/format'

const route = useRoute()
const router = useRouter()
const { accountUid, project, access } = useProjectContext()

const endUsers = ref<Page<EndUser>>({ items: [], total: 0, perPage: 25 })
const definitions = ref<AttributeDefinition[]>([])
const groups = ref<Group[]>([])
const notice = ref<string | null>(null)

// Filters live in the URL, so they survive reloads and the back button.
const text = (key: string) => (typeof route.query[key] === 'string' ? (route.query[key] as string) : '')
const search = ref(text('search'))
const status = ref(text('status'))
const emailVerified = ref(text('email'))
const mfa = ref(text('mfa'))
const invitation = ref(text('invitation'))
const groupUid = ref(text('group'))
const page = computed(() => Math.max(1, Number(text('page')) || 1))

const anyOption = (label: string): SelectOption => ({ label, value: '' })
const statusOptions: SelectOption[] = [anyOption('Any status'), { label: 'Active', value: 'active' }, { label: 'Disabled', value: 'disabled' }]
const emailOptions: SelectOption[] = [anyOption('Any email'), { label: 'Verified', value: 'true' }, { label: 'Not verified', value: 'false' }]
const mfaOptions: SelectOption[] = [anyOption('Any MFA'), { label: 'MFA on', value: 'true' }, { label: 'MFA off', value: 'false' }]
const invitationOptions: SelectOption[] = [anyOption('Any'), { label: 'Invitation pending', value: 'true' }]
const groupOptions = computed<SelectOption[]>(() => [anyOption('Any group'), ...groups.value.map((group) => ({ label: group.name, value: group.uid }))])

const filtered = computed(() => ['search', 'status', 'email', 'mfa', 'invitation', 'group'].some((key) => text(key) !== ''))

const columns = [
  { key: 'email', label: 'End user' },
  { key: 'status', label: 'Status' },
  { key: 'mfa_enabled', label: 'MFA' },
  { key: 'groups', label: 'Groups' },
  { key: 'last_sign_in_at', label: 'Last sign-in' },
  { key: 'actions', label: 'Actions', srOnly: true },
]

function filtersFromQuery(): EndUserFilters {
  const term = text('search').trim()
  const bool = (value: string) => (value === '' ? undefined : value === 'true')
  const statusValue = text('status')
  return {
    uid_eq: term.startsWith('eu_') ? term : undefined,
    email_cont: term && !term.startsWith('eu_') ? term : undefined,
    status_eq: statusValue === 'active' || statusValue === 'disabled' ? statusValue : undefined,
    email_verified: bool(text('email')),
    mfa: bool(text('mfa')),
    invitation_pending: text('invitation') === 'true' || undefined,
    group_uid: text('group') || undefined,
  }
}

const load = useAsyncAction(async () => {
  if (!project.value) return
  const [loaded, loadedDefinitions, loadedGroups] = await Promise.all([
    projectAdminService.listEndUsers(accountUid.value, project.value.uid, page.value, filtersFromQuery()),
    definitions.value.length > 0 ? null : projectAdminService.listAttributes(accountUid.value, project.value.uid),
    groups.value.length > 0 ? null : projectAdminService.listGroups(accountUid.value, project.value.uid),
  ])
  endUsers.value = loaded
  if (loadedDefinitions) definitions.value = loadedDefinitions.items
  if (loadedGroups) groups.value = loadedGroups.items
})

function applyFilters() {
  const query = { search: search.value.trim(), status: status.value, email: emailVerified.value, mfa: mfa.value, invitation: invitation.value, group: groupUid.value }
  router.push({ query: Object.fromEntries(Object.entries(query).filter(([, value]) => value !== '')) })
}

function clearFilters() {
  search.value = ''
  status.value = ''
  emailVerified.value = ''
  mfa.value = ''
  invitation.value = ''
  groupUid.value = ''
  router.push({ query: {} })
}

function setPage(value: number) {
  router.push({ query: { ...route.query, page: value > 1 ? String(value) : undefined } })
}

const userLink = (endUser: EndUser) => ({ name: 'project-end-user', params: { projectUid: project.value?.uid, endUserUid: endUser.uid } })

const actions = useEndUserActions(
  () => (project.value ? { accountUid: accountUid.value, projectUid: project.value.uid } : null),
  ({ endUser, updated, notice: message }) => {
    notice.value = message
    endUsers.value = updated
      ? { ...endUsers.value, items: endUsers.value.items.map((existing) => (existing.uid === endUser.uid ? updated : existing)) }
      : { ...endUsers.value, items: endUsers.value.items.filter((existing) => existing.uid !== endUser.uid), total: endUsers.value.total - 1 }
  },
)

function menuItems(endUser: EndUser): ActionMenuItem[] {
  return [
    ...(endUser.invitation_pending ? [{ label: 'Resend invitation', action: () => actions.request('resend_invitation', endUser) }] : []),
    { label: 'Sign out everywhere', action: () => actions.request('sign_out', endUser) },
    ...(endUser.mfa_enabled ? [{ label: 'Reset MFA', danger: true, action: () => actions.request('reset_mfa', endUser) }] : []),
    endUser.status === 'active'
      ? { label: 'Disable', danger: true, action: () => actions.request('disable', endUser) }
      : { label: 'Enable', action: () => actions.request('enable', endUser) },
    { label: 'Delete', danger: true, action: () => actions.request('delete', endUser) },
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

watch(() => route.query, () => load.run())
onMounted(() => load.run())
</script>

<template>
  <BaseCard>
    <div class="flex flex-wrap items-start justify-between gap-4">
      <form class="flex flex-1 flex-col gap-4" role="search" novalidate @submit.prevent="applyFilters">
        <div class="flex flex-wrap items-end gap-4">
          <div class="w-full max-w-sm">
            <BaseInput v-model="search" label="Search by email or user ID" type="search" hint="A user ID starts with eu_." />
          </div>
          <BaseButton type="submit" label="Search" variant="secondary" />
        </div>
        <div class="grid gap-4 sm:grid-cols-3 lg:grid-cols-5">
          <BaseSelect v-model="status" label="Status" :options="statusOptions" @update:model-value="applyFilters" />
          <BaseSelect v-model="emailVerified" label="Email" :options="emailOptions" @update:model-value="applyFilters" />
          <BaseSelect v-model="mfa" label="MFA" :options="mfaOptions" @update:model-value="applyFilters" />
          <BaseSelect v-model="invitation" label="Invitation" :options="invitationOptions" @update:model-value="applyFilters" />
          <BaseSelect v-model="groupUid" label="Group" :options="groupOptions" @update:model-value="applyFilters" />
        </div>
      </form>
      <BaseButton v-if="access.developer" label="Create end user" @click="createOpen = true" />
    </div>

    <BaseAlert v-if="notice" variant="success">{{ notice }}</BaseAlert>
    <BaseAlert v-if="load.error.value" variant="danger">We couldn't load end users. {{ load.error.value.message }}</BaseAlert>
    <BaseAlert v-if="actions.perform.error.value && !actions.pending.value" variant="danger">{{ actions.perform.error.value.message }}</BaseAlert>

    <div class="flex flex-wrap items-center justify-between gap-2 text-sm text-text-muted">
      <span role="status">{{ endUsers.total }} {{ endUsers.total === 1 ? 'end user' : 'end users' }}{{ filtered ? ' match' : '' }}</span>
      <BaseButton v-if="filtered" label="Clear filters" variant="ghost" size="sm" @click="clearFilters" />
    </div>

    <BaseTable
      caption="End users"
      :columns="columns"
      :rows="endUsers.items"
      :row-key="(endUser) => endUser.uid"
      :loading="load.loading.value"
      :empty-message="filtered ? 'No end users match these filters.' : 'No end users yet. They appear here once they sign up, sign in with an identity provider, or you create them.'"
    >
      <template #cell-email="{ row }">
        <RouterLink :to="userLink(row)" class="font-medium text-primary underline-offset-2 hover:underline">{{ row.email }}</RouterLink>
        <span v-if="row.name" class="block text-text-muted">{{ row.name }}</span>
        <code class="block font-mono text-xs text-text-muted">{{ row.uid }}</code>
      </template>
      <template #cell-status="{ row }">
        <span class="flex flex-wrap gap-1">
          <StatusBadge :tone="row.status === 'active' ? 'success' : 'danger'" :label="row.status === 'active' ? 'Active' : 'Disabled'" />
          <StatusBadge v-if="row.invitation_pending" tone="info" label="Invitation pending" />
          <StatusBadge v-else-if="!row.email_verified" tone="warning" label="Email not verified" />
        </span>
      </template>
      <template #cell-mfa_enabled="{ row }">
        <StatusBadge :tone="row.mfa_enabled ? 'success' : 'neutral'" :label="row.mfa_enabled ? 'On' : 'Off'" />
      </template>
      <template #cell-groups="{ row }">
        <span v-if="row.groups.length === 0" class="text-text-muted">None</span>
        <span v-else class="text-xs">
          {{ row.groups.slice(0, 2).map((group) => group.name).join(', ') }}<template v-if="row.groups.length > 2"> +{{ row.groups.length - 2 }}</template>
        </span>
      </template>
      <template #cell-last_sign_in_at="{ row }">
        <span class="text-xs">{{ row.last_sign_in_at ? formatDateTime(row.last_sign_in_at) : 'Never' }}</span>
      </template>
      <template #cell-actions="{ row }">
        <div class="flex items-center justify-end gap-2">
          <RouterLink :to="userLink(row)" class="text-sm font-medium text-primary underline">View</RouterLink>
          <BaseActionMenu v-if="access.developer" :items="menuItems(row)" :label="`More actions for ${row.email}`" />
        </div>
      </template>
    </BaseTable>

    <BasePagination :page="page" :total="endUsers.total" :per-page="endUsers.perPage" :disabled="load.loading.value" @update:page="setPage" />
  </BaseCard>

  <EndUserActionDialog
    :pending="actions.pending.value"
    :loading="actions.perform.loading.value"
    :error="actions.perform.error.value"
    @confirm="actions.confirm()"
    @cancel="actions.pending.value = null"
  />

  <BaseDialog v-model:visible="createOpen" title="Create end user">
    <form id="create-end-user" class="flex flex-col gap-4" novalidate @submit.prevent="create.run()">
      <BaseAlert v-if="create.error.value && create.error.value.details.length === 0" variant="danger">{{ create.error.value.message }}</BaseAlert>
      <BaseInput v-model="newEmail" label="Email" type="email" required :error="create.error.value?.fieldError('email')" />
      <BaseInput v-model="newName" label="Name" :error="create.error.value?.fieldError('name')" />
      <CustomAttributeFields v-model="newAttributes" :definitions="definitions" :error="create.error.value" />
      <BaseCheckbox
        v-model="sendInvitation"
        label="Email an invitation to set a password"
        hint="The invitation contains a code and, if configured, a link to your app. New users join groups set to take them automatically."
      />
    </form>
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="createOpen = false" />
      <BaseButton label="Create" type="submit" form="create-end-user" :loading="create.loading.value" />
    </template>
  </BaseDialog>
</template>
