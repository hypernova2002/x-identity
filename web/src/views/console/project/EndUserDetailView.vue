<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'

import AuditEventList from '@/components/audit/AuditEventList.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import type { SelectOption } from '@/components/base/types'
import PageBreadcrumbs from '@/components/console/PageBreadcrumbs.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import CustomAttributeFields from '@/components/project/CustomAttributeFields.vue'
import EndUserActionDialog from '@/components/project/EndUserActionDialog.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useEndUserActions } from '@/composables/useEndUserActions'
import { useProjectContext } from '@/composables/useProjectContext'
import type { AuditEventFilters } from '@/services/account'
import { projectAdminService } from '@/services/project'
import type { AttributeDefinition, EndUser, EndUserAppAccess, EndUserIdentity, Group } from '@/types/api'
import { type AttributeDraft, toCustomAttributes } from '@/utils/customAttributes'
import { formatDateTime } from '@/utils/format'

const route = useRoute()
const router = useRouter()
const { accountUid, project, access } = useProjectContext()

const endUser = ref<EndUser | null>(null)
const identities = ref<EndUserIdentity[]>([])
const appAccess = ref<EndUserAppAccess[]>([])
const definitions = ref<AttributeDefinition[]>([])
const groups = ref<Group[]>([])
const notice = ref<string | null>(null)
const endUserUid = computed(() => String(route.params.endUserUid))
const ids = () => (project.value ? { accountUid: accountUid.value, projectUid: project.value.uid } : null)

const otherGroups = computed<SelectOption[]>(() =>
  groups.value.filter((group) => !endUser.value?.groups.some((member) => member.uid === group.uid)).map((group) => ({ label: group.name, value: group.uid })),
)
const groupToAdd = ref('')
watch(otherGroups, (options) => {
  if (!options.some((option) => option.value === groupToAdd.value)) groupToAdd.value = options[0]?.value ?? ''
})

const attributeValue = (key: string) => {
  const value = endUser.value?.custom_attributes[key]
  return value === undefined ? '—' : String(value)
}

const load = useAsyncAction(async () => {
  const target = ids()
  if (!target) return
  const [loaded, loadedIdentities, loadedAccess, loadedDefinitions, loadedGroups] = await Promise.all([
    projectAdminService.getEndUser(target.accountUid, target.projectUid, endUserUid.value),
    projectAdminService.listEndUserIdentities(target.accountUid, target.projectUid, endUserUid.value),
    projectAdminService.getEndUserAccess(target.accountUid, target.projectUid, endUserUid.value),
    projectAdminService.listAttributes(target.accountUid, target.projectUid),
    projectAdminService.listGroups(target.accountUid, target.projectUid),
  ])
  endUser.value = loaded
  identities.value = loadedIdentities
  appAccess.value = loadedAccess
  definitions.value = loadedDefinitions.items
  groups.value = loadedGroups.items
})

async function reloadMembership() {
  const target = ids()
  if (!target) return
  const [loaded, loadedAccess] = await Promise.all([
    projectAdminService.getEndUser(target.accountUid, target.projectUid, endUserUid.value),
    projectAdminService.getEndUserAccess(target.accountUid, target.projectUid, endUserUid.value),
  ])
  endUser.value = loaded
  appAccess.value = loadedAccess
}

const actions = useEndUserActions(ids, async ({ updated, notice: message }) => {
  if (!updated) {
    await router.push({ name: 'project-end-users', params: { projectUid: project.value?.uid } })
    return
  }
  endUser.value = updated
  notice.value = message
})

const membership = useAsyncAction(async (change: 'add' | 'remove', groupUid: string) => {
  const target = ids()
  if (!target || !endUser.value) return
  if (change === 'add') await projectAdminService.addGroupMember(target.accountUid, target.projectUid, groupUid, endUser.value.uid)
  else await projectAdminService.removeGroupMember(target.accountUid, target.projectUid, groupUid, endUser.value.uid)
  await reloadMembership()
})

const unlink = useAsyncAction(async (identity: EndUserIdentity) => {
  const target = ids()
  if (!target || !endUser.value) return
  await projectAdminService.unlinkEndUserIdentity(target.accountUid, target.projectUid, endUser.value.uid, identity.uid)
  identities.value = identities.value.filter((existing) => existing.uid !== identity.uid)
})

// Editing the profile: name and custom attributes.
const editOpen = ref(false)
const editName = ref('')
const editAttributes = ref<AttributeDraft>({})

function startEditing() {
  if (!endUser.value) return
  editName.value = endUser.value.name ?? ''
  editAttributes.value = Object.fromEntries(
    definitions.value.map((definition) => {
      const value = endUser.value!.custom_attributes[definition.key]
      return [definition.key, definition.data_type === 'boolean' ? value === true : value === undefined ? '' : String(value)]
    }),
  )
  saveProfile.error.value = null
  editOpen.value = true
}

const saveProfile = useAsyncAction(async () => {
  const target = ids()
  if (!target || !endUser.value) return
  endUser.value = await projectAdminService.updateEndUser(target.accountUid, target.projectUid, endUser.value.uid, {
    name: editName.value.trim() || null,
    custom_attributes: toCustomAttributes(definitions.value, editAttributes.value, { clearEmpty: true }),
  })
  editOpen.value = false
  notice.value = 'Profile saved.'
})

function fetchAudit(page: number, filters: AuditEventFilters) {
  return projectAdminService.listAuditEvents(accountUid.value, project.value!.uid, page, filters)
}

const appLink = (app: EndUserAppAccess) =>
  app.app_type === 'saml_app'
    ? { name: 'project-saml-app', params: { projectUid: project.value?.uid, samlAppUid: app.uid } }
    : { name: 'project-app-client', params: { projectUid: project.value?.uid, clientUid: app.uid } }

watch(endUserUid, () => load.run(), { immediate: true })
</script>

<template>
  <PageBreadcrumbs
    :items="[
      { label: 'End users', to: { name: 'project-end-users', params: { projectUid: project?.uid } } },
      { label: endUser?.email ?? 'End user' },
    ]"
  />

  <BaseAlert v-if="load.error.value?.code === 'not_found'" variant="danger" title="End user not found">They may have been deleted.</BaseAlert>
  <BaseAlert v-else-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
  <p v-else-if="!endUser" class="text-sm text-text-muted" role="status">Loading end user…</p>

  <template v-if="endUser && project">
    <PageHeader :title="endUser.email" :description="endUser.name ?? undefined">
      <template #actions>
        <StatusBadge :tone="endUser.status === 'active' ? 'success' : 'danger'" :label="endUser.status === 'active' ? 'Active' : 'Disabled'" />
        <StatusBadge v-if="endUser.invitation_pending" tone="info" label="Invitation pending" />
        <StatusBadge :tone="endUser.mfa_enabled ? 'success' : 'neutral'" :label="endUser.mfa_enabled ? 'MFA on' : 'MFA off'" />
      </template>
    </PageHeader>

    <BaseAlert v-if="notice" variant="success">{{ notice }}</BaseAlert>
    <BaseAlert v-if="actions.perform.error.value && !actions.pending.value" variant="danger">{{ actions.perform.error.value.message }}</BaseAlert>

    <BaseCard title="Identity">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <dt class="font-medium">Email</dt>
        <dd class="flex flex-wrap items-center gap-2">
          {{ endUser.email }}
          <StatusBadge :tone="endUser.email_verified ? 'success' : 'warning'" :label="endUser.email_verified ? 'Verified' : 'Not verified'" />
        </dd>
        <dt class="font-medium">Name</dt>
        <dd>{{ endUser.name ?? '—' }}</dd>
        <dt class="font-medium">User ID (sub)</dt>
        <dd class="font-mono text-xs break-all">{{ endUser.uid }}</dd>
        <dt class="font-medium">Created</dt>
        <dd>{{ formatDateTime(endUser.created_at) }}</dd>
        <dt class="font-medium">Last sign-in</dt>
        <dd>{{ endUser.last_sign_in_at ? formatDateTime(endUser.last_sign_in_at) : 'Never' }}</dd>
        <template v-for="definition in definitions" :key="definition.uid">
          <dt class="font-medium">{{ definition.label }}</dt>
          <dd>{{ attributeValue(definition.key) }}</dd>
        </template>
      </dl>
      <BaseButton v-if="access.developer" label="Edit profile" variant="secondary" class="self-start" @click="startEditing" />

      <section class="flex flex-col gap-2 border-t border-border pt-4" aria-labelledby="identities-heading">
        <h3 id="identities-heading" class="text-sm font-semibold">Linked identity providers</h3>
        <BaseAlert v-if="unlink.error.value" variant="danger">{{ unlink.error.value.message }}</BaseAlert>
        <p v-if="identities.length === 0" class="text-sm text-text-muted">None. This user signs in with email and password.</p>
        <ul v-else class="flex flex-col divide-y divide-border">
          <li v-for="identity in identities" :key="identity.uid" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
            <span class="flex flex-col">
              <RouterLink
                :to="{ name: 'project-identity-provider', params: { projectUid: project.uid, providerUid: identity.identity_provider_uid } }"
                class="font-medium text-primary underline-offset-2 hover:underline"
              >
                {{ identity.identity_provider_name }}
              </RouterLink>
              <span class="text-xs text-text-muted">{{ identity.email ?? 'No email shared' }} · ID {{ identity.subject }} · last used {{ formatDateTime(identity.last_sign_in_at) }}</span>
            </span>
            <BaseButton v-if="access.developer" label="Unlink" variant="ghost" size="sm" :loading="unlink.loading.value" @click="unlink.run(identity)" />
          </li>
        </ul>
      </section>
    </BaseCard>

    <BaseCard title="Access" description="Applications are assignment-only: this user can sign in to an app assigned to them directly or to one of their groups.">
      <BaseAlert v-if="membership.error.value" variant="danger">{{ membership.error.value.message }}</BaseAlert>
      <section class="flex flex-col gap-2" aria-labelledby="groups-heading">
        <h3 id="groups-heading" class="text-sm font-semibold">Groups</h3>
        <p v-if="endUser.groups.length === 0" class="text-sm text-text-muted">Not in any group.</p>
        <ul v-else class="flex flex-col divide-y divide-border">
          <li v-for="group in endUser.groups" :key="group.uid" class="flex items-center justify-between gap-2 py-2 text-sm">
            <RouterLink :to="{ name: 'project-groups', params: { projectUid: project.uid }, query: { group: group.uid } }" class="font-medium text-primary underline-offset-2 hover:underline">
              {{ group.name }}
            </RouterLink>
            <BaseButton v-if="access.developer" label="Remove" variant="ghost" size="sm" :loading="membership.loading.value" @click="membership.run('remove', group.uid)" />
          </li>
        </ul>
        <div v-if="access.developer && otherGroups.length > 0" class="flex flex-wrap items-end gap-2">
          <div class="min-w-48 flex-1"><BaseSelect v-model="groupToAdd" label="Add to group" :options="otherGroups" /></div>
          <BaseButton label="Add" variant="secondary" :loading="membership.loading.value" @click="membership.run('add', groupToAdd)" />
        </div>
      </section>

      <section class="flex flex-col gap-2 border-t border-border pt-4" aria-labelledby="apps-heading">
        <h3 id="apps-heading" class="text-sm font-semibold">Applications</h3>
        <p v-if="appAccess.length === 0" class="text-sm text-text-muted">No applications: this user can't sign in to any app yet.</p>
        <ul v-else class="flex flex-col divide-y divide-border">
          <li v-for="app in appAccess" :key="app.uid" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
            <span class="flex items-center gap-2">
              <RouterLink :to="appLink(app)" class="font-medium text-primary underline-offset-2 hover:underline">{{ app.name }}</RouterLink>
              <StatusBadge tone="info" :label="app.app_type === 'saml_app' ? 'SAML' : 'OpenID Connect / API'" />
              <StatusBadge v-if="!app.enabled" tone="neutral" label="App disabled" />
            </span>
            <span class="text-xs text-text-muted">
              {{ app.via.map((via) => (via.type === 'direct' ? 'Assigned directly' : `Through ${via.group_name}`)).join(' · ') }}
            </span>
          </li>
        </ul>
      </section>
    </BaseCard>

    <BaseCard title="Authentication">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <dt class="font-medium">Account status</dt>
        <dd>{{ endUser.status === 'active' ? 'Active: can sign in' : 'Disabled: can\'t sign in' }}</dd>
        <dt class="font-medium">Password</dt>
        <dd>{{ endUser.invitation_pending ? 'Not set yet: invitation pending' : 'Set, or signs in with an identity provider' }}</dd>
        <dt class="font-medium">Multi-factor authentication</dt>
        <dd>{{ endUser.mfa_enabled ? 'Set up' : 'Not set up' }}</dd>
      </dl>
      <p class="text-xs text-text-muted">
        Whether MFA is required is a project-wide policy, in
        <RouterLink :to="{ name: 'project-auth-mfa', params: { projectUid: project.uid } }" class="text-primary underline">Authentication › Multi-factor authentication</RouterLink>.
      </p>
      <div v-if="access.developer" class="flex flex-wrap gap-2">
        <BaseButton v-if="endUser.invitation_pending" label="Resend invitation" variant="secondary" :loading="actions.perform.loading.value" @click="actions.request('resend_invitation', endUser)" />
        <BaseButton v-if="endUser.mfa_enabled" label="Reset MFA" variant="secondary" @click="actions.request('reset_mfa', endUser)" />
        <BaseButton v-if="endUser.status === 'active'" label="Disable" variant="secondary" @click="actions.request('disable', endUser)" />
        <BaseButton v-else label="Enable" variant="secondary" :loading="actions.perform.loading.value" @click="actions.request('enable', endUser)" />
      </div>
    </BaseCard>

    <BaseCard title="Sessions">
      <p class="text-sm">
        Individual sessions aren't listed yet. Signing out everywhere revokes every refresh token, stops current access tokens working and
        ends hosted login sessions.
      </p>
      <BaseButton v-if="access.developer" label="Sign out everywhere" variant="secondary" class="self-start" @click="actions.request('sign_out', endUser)" />
    </BaseCard>

    <BaseCard v-if="access.developer" title="Activity">
      <AuditEventList
        :fetch-page="fetchAudit"
        :filters="{ target_uid_eq: endUser.uid }"
        empty-message="No activity recorded yet."
        :full-log="{ name: 'project-audit-log', params: { projectUid: project.uid }, query: { target_uid_eq: endUser.uid } }"
      />
    </BaseCard>

    <BaseCard v-if="access.developer" title="Delete end user" description="Permanently deletes the user and everything attached to them.">
      <BaseButton label="Delete end user" variant="danger" class="self-start" @click="actions.request('delete', endUser)" />
    </BaseCard>

    <EndUserActionDialog
      :pending="actions.pending.value"
      :loading="actions.perform.loading.value"
      :error="actions.perform.error.value"
      @confirm="actions.confirm()"
      @cancel="actions.pending.value = null"
    />

    <BaseDialog v-model:visible="editOpen" title="Edit profile">
      <form id="edit-end-user" class="flex flex-col gap-4" novalidate @submit.prevent="saveProfile.run()">
        <BaseAlert v-if="saveProfile.error.value && saveProfile.error.value.details.length === 0" variant="danger">{{ saveProfile.error.value.message }}</BaseAlert>
        <BaseInput v-model="editName" label="Name" :error="saveProfile.error.value?.fieldError('name')" />
        <CustomAttributeFields v-model="editAttributes" :definitions="definitions" :error="saveProfile.error.value" />
      </form>
      <template #footer>
        <BaseButton label="Cancel" variant="secondary" @click="editOpen = false" />
        <BaseButton label="Save" type="submit" form="edit-end-user" :loading="saveProfile.loading.value" />
      </template>
    </BaseDialog>
  </template>
</template>
