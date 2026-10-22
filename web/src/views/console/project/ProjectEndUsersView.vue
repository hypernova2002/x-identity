<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BasePagination from '@/components/base/BasePagination.vue'
import BaseTable from '@/components/base/BaseTable.vue'
import CustomAttributeFields from '@/components/project/CustomAttributeFields.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import type { Page } from '@/services/http'
import { projectAdminService } from '@/services/project'
import type { AttributeDefinition, EndUser, EndUserIdentity } from '@/types/api'
import { type AttributeDraft, toCustomAttributes } from '@/utils/customAttributes'
import { formatDateTime } from '@/utils/format'

type EndUserAction = 'toggle' | 'reset_mfa' | 'sign_out' | 'resend_invitation' | 'delete'

const { accountUid, project, access } = useProjectContext()

const page = ref(1)
const search = ref('')
const appliedSearch = ref('')
const endUsers = ref<Page<EndUser>>({ items: [], total: 0, perPage: 25 })
const definitions = ref<AttributeDefinition[]>([])
const notice = ref<string | null>(null)

const createOpen = ref(false)
const newEmail = ref('')
const newName = ref('')
const sendInvitation = ref(true)
const newAttributes = ref<AttributeDraft>({})
const pendingDelete = ref<EndUser | null>(null)
const identitiesFor = ref<EndUser | null>(null)
const identities = ref<EndUserIdentity[]>([])

const columns = [
  { key: 'email', label: 'End user' },
  { key: 'status', label: 'Status' },
  { key: 'groups', label: 'Groups' },
  { key: 'mfa_enabled', label: 'MFA' },
  { key: 'last_sign_in_at', label: 'Last sign-in' },
  { key: 'actions', label: 'Actions', srOnly: true },
]

const load = useAsyncAction(async () => {
  if (!project.value) return
  const [loaded, loadedDefinitions] = await Promise.all([
    projectAdminService.listEndUsers(accountUid.value, project.value.uid, page.value, { email_cont: appliedSearch.value || undefined }),
    definitions.value.length > 0 ? null : projectAdminService.listAttributes(accountUid.value, project.value.uid),
  ])
  endUsers.value = loaded
  if (loadedDefinitions) definitions.value = loadedDefinitions.items
})

const create = useAsyncAction(async () => {
  if (!project.value) return
  const created = await projectAdminService.createEndUser(accountUid.value, project.value.uid, {
    email: newEmail.value,
    name: newName.value.trim() || null,
    custom_attributes: toCustomAttributes(definitions.value, newAttributes.value),
    send_invitation: sendInvitation.value,
  })
  endUsers.value = { ...endUsers.value, items: [created, ...endUsers.value.items], total: endUsers.value.total + 1 }
  notice.value = sendInvitation.value ? `${created.email} was created and invited to set a password.` : `${created.email} was created.`
  createOpen.value = false
  newEmail.value = ''
  newName.value = ''
  newAttributes.value = {}
})

const endUserAction = useAsyncAction(async (endUser: EndUser, action: EndUserAction) => {
  if (!project.value) return
  const ids = [accountUid.value, project.value.uid, endUser.uid] as const
  notice.value = null

  switch (action) {
    case 'toggle': {
      const updated = await projectAdminService.updateEndUser(...ids, { status: endUser.status === 'active' ? 'disabled' : 'active' })
      endUsers.value = { ...endUsers.value, items: endUsers.value.items.map((existing) => (existing.uid === updated.uid ? updated : existing)) }
      return
    }
    case 'reset_mfa':
      await projectAdminService.resetEndUserMfa(...ids)
      endUsers.value = {
        ...endUsers.value,
        items: endUsers.value.items.map((existing) => (existing.uid === endUser.uid ? { ...existing, mfa_enabled: false } : existing)),
      }
      notice.value = `MFA was turned off for ${endUser.email}.`
      return
    case 'sign_out':
      await projectAdminService.signOutEndUser(...ids)
      notice.value = `${endUser.email} was signed out everywhere.`
      return
    case 'resend_invitation':
      await projectAdminService.resendInvitation(...ids)
      notice.value = `A new invitation was sent to ${endUser.email}.`
      return
    case 'delete':
      await projectAdminService.deleteEndUser(...ids)
      endUsers.value = {
        ...endUsers.value,
        items: endUsers.value.items.filter((existing) => existing.uid !== endUser.uid),
        total: endUsers.value.total - 1,
      }
      pendingDelete.value = null
  }
})

const loadIdentities = useAsyncAction(async (endUser: EndUser) => {
  if (!project.value) return
  identitiesFor.value = endUser
  identities.value = []
  unlink.error.value = null
  identities.value = await projectAdminService.listEndUserIdentities(accountUid.value, project.value.uid, endUser.uid)
})

const unlink = useAsyncAction(async (identity: EndUserIdentity) => {
  if (!project.value || !identitiesFor.value) return
  await projectAdminService.unlinkEndUserIdentity(accountUid.value, project.value.uid, identitiesFor.value.uid, identity.uid)
  identities.value = identities.value.filter((existing) => existing.uid !== identity.uid)
})

function applySearch() {
  appliedSearch.value = search.value.trim()
  if (page.value === 1) load.run()
  else page.value = 1
}

watch(page, () => load.run())
onMounted(() => load.run())
</script>

<template>
  <BaseCard title="End users" description="The people who sign in to this project's apps.">
    <template v-if="access.developer" #footer>
      <BaseButton label="Create end user" @click="createOpen = true" />
    </template>

    <form class="flex flex-wrap items-end gap-4" novalidate @submit.prevent="applySearch">
      <div class="w-full max-w-xs">
        <BaseInput v-model="search" label="Search by email" type="search" />
      </div>
      <BaseButton type="submit" label="Search" variant="secondary" />
    </form>

    <BaseAlert v-if="notice" variant="success">{{ notice }}</BaseAlert>
    <BaseAlert v-if="load.error.value" variant="danger">We couldn't load end users. {{ load.error.value.message }}</BaseAlert>
    <BaseAlert v-if="endUserAction.error.value" variant="danger">{{ endUserAction.error.value.message }}</BaseAlert>

    <BaseTable
      caption="End users"
      :columns="columns"
      :rows="endUsers.items"
      :row-key="(endUser) => endUser.uid"
      :loading="load.loading.value"
      :empty-message="appliedSearch ? 'No end users match this search.' : 'No end users yet. They appear here once they sign up or you create them.'"
    >
      <template #cell-email="{ row }">
        <span class="font-medium">{{ row.email }}</span>
        <span v-if="row.name" class="block text-text-muted">{{ row.name }}</span>
        <code class="block font-mono text-xs text-text-muted">{{ row.uid }}</code>
      </template>
      <template #cell-status="{ row }">
        <span :class="row.status === 'active' ? 'text-success' : 'text-text-muted'" class="font-medium">
          {{ row.status === 'active' ? '● Active' : '○ Disabled' }}
        </span>
        <span class="block text-xs text-text-muted">
          {{ row.invitation_pending ? 'Invitation pending' : row.email_verified ? 'Email confirmed' : 'Email not confirmed' }}
        </span>
      </template>
      <template #cell-groups="{ row }">
        <span v-if="row.groups.length === 0" class="text-text-muted">None</span>
        <span v-else class="text-xs">{{ row.groups.map((group) => group.name).join(', ') }}</span>
      </template>
      <template #cell-mfa_enabled="{ row }">{{ row.mfa_enabled ? 'On' : 'Off' }}</template>
      <template #cell-last_sign_in_at="{ row }">{{ formatDateTime(row.last_sign_in_at) }}</template>
      <template #cell-actions="{ row }">
        <div class="flex flex-wrap justify-end gap-2">
          <BaseButton label="Sign-in providers" variant="secondary" size="sm" @click="loadIdentities.run(row)" />
          <template v-if="access.developer">
          <BaseButton
            :label="row.status === 'active' ? 'Disable' : 'Enable'"
            variant="secondary"
            size="sm"
            :disabled="endUserAction.loading.value"
            @click="endUserAction.run(row, 'toggle')"
          />
          <BaseButton
            v-if="row.invitation_pending"
            label="Resend invitation"
            variant="secondary"
            size="sm"
            :disabled="endUserAction.loading.value"
            @click="endUserAction.run(row, 'resend_invitation')"
          />
          <BaseButton
            v-if="row.mfa_enabled"
            label="Reset MFA"
            variant="secondary"
            size="sm"
            :disabled="endUserAction.loading.value"
            @click="endUserAction.run(row, 'reset_mfa')"
          />
          <BaseButton
            label="Sign out everywhere"
            variant="ghost"
            size="sm"
            :disabled="endUserAction.loading.value"
            @click="endUserAction.run(row, 'sign_out')"
          />
          <BaseButton label="Delete" variant="ghost" size="sm" :disabled="endUserAction.loading.value" @click="pendingDelete = row" />
          </template>
        </div>
      </template>
    </BaseTable>

    <BasePagination v-model:page="page" :total="endUsers.total" :per-page="endUsers.perPage" :disabled="load.loading.value" />
  </BaseCard>

  <BaseDialog v-model:visible="createOpen" title="Create end user">
    <form id="create-end-user" class="flex flex-col gap-4" novalidate @submit.prevent="create.run()">
      <BaseAlert v-if="create.error.value && create.error.value.details.length === 0" variant="danger">{{ create.error.value.message }}</BaseAlert>
      <BaseInput v-model="newEmail" label="Email" type="email" required :error="create.error.value?.fieldError('email')" />
      <BaseInput v-model="newName" label="Name" :error="create.error.value?.fieldError('name')" />
      <CustomAttributeFields v-model="newAttributes" :definitions="definitions" :error="create.error.value" />
      <BaseCheckbox
        v-model="sendInvitation"
        label="Email an invitation to set a password"
        hint="The invitation contains a code and, if configured, a link to your app."
      />
    </form>
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="createOpen = false" />
      <BaseButton label="Create" type="submit" form="create-end-user" :loading="create.loading.value" />
    </template>
  </BaseDialog>

  <BaseDialog
    :visible="identitiesFor !== null"
    :title="`Sign-in providers for ${identitiesFor?.email ?? ''}`"
    @update:visible="(open: boolean) => !open && (identitiesFor = null)"
  >
    <BaseAlert v-if="loadIdentities.error.value" variant="danger">{{ loadIdentities.error.value.message }}</BaseAlert>
    <BaseAlert v-if="unlink.error.value" variant="danger">{{ unlink.error.value.message }}</BaseAlert>
    <p v-if="loadIdentities.loading.value" class="text-sm text-text-muted" role="status">Loading…</p>
    <p v-else-if="identities.length === 0" class="text-sm text-text-muted">
      Not linked to any sign-in provider. This user signs in with email and password.
    </p>
    <ul v-else class="flex flex-col divide-y divide-border">
      <li v-for="identity in identities" :key="identity.uid" class="flex flex-wrap items-center justify-between gap-2 py-3 text-sm">
        <div class="flex flex-col">
          <span class="font-medium">{{ identity.identity_provider_name }}</span>
          <span class="text-text-muted">{{ identity.email ?? 'No email shared' }}</span>
          <span class="text-xs text-text-muted">
            ID <code class="font-mono">{{ identity.subject }}</code> · last sign-in {{ formatDateTime(identity.last_sign_in_at) }}
          </span>
        </div>
        <BaseButton
          v-if="access.developer"
          label="Unlink"
          variant="ghost"
          size="sm"
          :loading="unlink.loading.value"
          @click="unlink.run(identity)"
        />
      </li>
    </ul>
    <template #footer>
      <BaseButton label="Done" @click="identitiesFor = null" />
    </template>
  </BaseDialog>

  <BaseDialog :visible="pendingDelete !== null" title="Delete end user?" @update:visible="(open: boolean) => !open && (pendingDelete = null)">
    <p class="text-sm">
      This permanently deletes <strong>{{ pendingDelete?.email }}</strong> and signs them out everywhere. To keep the user but
      stop them signing in, disable them instead.
    </p>
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="pendingDelete = null" />
      <BaseButton
        label="Delete end user"
        variant="danger"
        :loading="endUserAction.loading.value"
        @click="pendingDelete && endUserAction.run(pendingDelete, 'delete')"
      />
    </template>
  </BaseDialog>
</template>
