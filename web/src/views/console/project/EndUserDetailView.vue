<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRoute, useRouter } from 'vue-router'

import AuditEventList from '@/components/audit/AuditEventList.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSearchSelect from '@/components/base/BaseSearchSelect.vue'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import PageBreadcrumbs from '@/components/console/PageBreadcrumbs.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import CustomAttributeFields from '@/components/project/CustomAttributeFields.vue'
import EndUserActionDialog from '@/components/project/EndUserActionDialog.vue'
import DeviceSessionTable from '@/components/sessions/DeviceSessionTable.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useEndUserActions } from '@/composables/useEndUserActions'
import { useProjectContext } from '@/composables/useProjectContext'
import { useProjectLookups } from '@/composables/useProjectLookups'
import type { ListParams } from '@/services/list'
import { projectAdminService } from '@/services/project'
import type { AttributeDefinition, DeviceSession, EndUser, EndUserAppAccess, EndUserIdentity, Passkey } from '@/types/api'
import { type AttributeDraft, toCustomAttributes } from '@/utils/customAttributes'
import { formatDateTime } from '@/utils/format'

const { t } = useI18n()

const route = useRoute()
const router = useRouter()
const { accountUid, project, access } = useProjectContext()

const endUser = ref<EndUser | null>(null)
const identities = ref<EndUserIdentity[]>([])
const passkeys = ref<Passkey[]>([])
const removingPasskey = ref<Passkey | null>(null)
const appAccess = ref<EndUserAppAccess[]>([])
const definitions = ref<AttributeDefinition[]>([])
const notice = ref<string | null>(null)
const endUserUid = computed(() => String(route.params.endUserUid))
const ids = () => (project.value ? { accountUid: accountUid.value, projectUid: project.value.uid } : null)

const lookups = useProjectLookups()
const groupToAdd = ref('')

/** Groups the user can join: the search's matches, minus the groups they're already in. */
async function searchGroupsToJoin(term: string) {
  const page = await lookups.searchGroups(term)
  const items = page.items.filter((option) => !endUser.value?.groups.some((group) => group.uid === option.value))
  return { items, total: page.total - (page.items.length - items.length) }
}

const attributeValue = (key: string) => {
  const value = endUser.value?.custom_attributes[key]
  return value === undefined ? '—' : String(value)
}

const load = useAsyncAction(async () => {
  const target = ids()
  if (!target) return
  const [loaded, loadedIdentities, loadedAccess, loadedDefinitions, loadedPasskeys] = await Promise.all([
    projectAdminService.getEndUser(target.accountUid, target.projectUid, endUserUid.value),
    projectAdminService.listEndUserIdentities(target.accountUid, target.projectUid, endUserUid.value),
    projectAdminService.getEndUserAccess(target.accountUid, target.projectUid, endUserUid.value),
    projectAdminService.listAttributes(target.accountUid, target.projectUid),
    projectAdminService.listEndUserPasskeys(target.accountUid, target.projectUid, endUserUid.value),
  ])
  endUser.value = loaded
  identities.value = loadedIdentities
  passkeys.value = loadedPasskeys
  appAccess.value = loadedAccess
  definitions.value = loadedDefinitions.items
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
  sessions.value?.reload()
})

const sessions = ref<InstanceType<typeof DeviceSessionTable> | null>(null)

function fetchSessions(params: ListParams) {
  return projectAdminService.listEndUserSessions(accountUid.value, project.value!.uid, endUser.value!.uid, params)
}

function signOutSession(session: DeviceSession) {
  return projectAdminService.signOutEndUserSession(accountUid.value, project.value!.uid, endUser.value!.uid, session.uid)
}

const membership = useAsyncAction(async (change: 'add' | 'remove', groupUid: string) => {
  const target = ids()
  if (!target || !endUser.value) return
  if (change === 'add') await projectAdminService.addGroupMember(target.accountUid, target.projectUid, groupUid, endUser.value.uid)
  else await projectAdminService.removeGroupMember(target.accountUid, target.projectUid, groupUid, endUser.value.uid)
  if (change === 'add') groupToAdd.value = ''
  await reloadMembership()
})

const unlink = useAsyncAction(async (identity: EndUserIdentity) => {
  const target = ids()
  if (!target || !endUser.value) return
  await projectAdminService.unlinkEndUserIdentity(target.accountUid, target.projectUid, endUser.value.uid, identity.uid)
  identities.value = identities.value.filter((existing) => existing.uid !== identity.uid)
})

const removePasskey = useAsyncAction(async () => {
  const target = ids()
  if (!target || !endUser.value || !removingPasskey.value) return
  const passkey = removingPasskey.value
  await projectAdminService.removeEndUserPasskey(target.accountUid, target.projectUid, endUser.value.uid, passkey.uid)
  passkeys.value = passkeys.value.filter((existing) => existing.uid !== passkey.uid)
  removingPasskey.value = null
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
  notice.value = t('project.endUserDetail.profileSaved')
})

function fetchAudit(params: ListParams) {
  return projectAdminService.listAuditEvents(accountUid.value, project.value!.uid, params)
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
      { label: $t('project.endUserDetail.endUsers'), to: { name: 'project-end-users', params: { projectUid: project?.uid } } },
      { label: endUser?.email ?? $t('project.endUserDetail.endUser') },
    ]"
  />

  <BaseAlert v-if="load.error.value?.code === 'not_found'" variant="danger" :title="$t('project.endUserDetail.endUserNotFound')">{{ $t('project.endUserDetail.theyMayHaveBeenDeleted') }}</BaseAlert>
  <BaseAlert v-else-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
  <p v-else-if="!endUser" class="text-sm text-text-muted" role="status">{{ $t('project.endUserDetail.loadingEndUser') }}</p>

  <template v-if="endUser && project">
    <PageHeader :title="endUser.email" :description="endUser.name ?? undefined">
      <template #actions>
        <StatusBadge :tone="endUser.status === 'active' ? 'success' : 'danger'" :label="endUser.status === 'active' ? $t('project.endUserDetail.active') : $t('project.endUserDetail.disabled')" />
        <StatusBadge v-if="endUser.invitation_pending" tone="info" :label="$t('project.endUserDetail.invitationPending')" />
        <StatusBadge :tone="endUser.mfa_enabled ? 'success' : 'neutral'" :label="endUser.mfa_enabled ? $t('project.endUserDetail.mfaOn') : $t('project.endUserDetail.mfaOff')" />
      </template>
    </PageHeader>

    <BaseAlert v-if="notice" variant="success">{{ notice }}</BaseAlert>
    <BaseAlert v-if="actions.perform.error.value && !actions.pending.value" variant="danger">{{ actions.perform.error.value.message }}</BaseAlert>

    <BaseCard :title="$t('project.endUserDetail.identity')">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <dt class="font-medium">{{ $t('project.endUserDetail.email') }}</dt>
        <dd class="flex flex-wrap items-center gap-2">
          {{ endUser.email }}
          <StatusBadge :tone="endUser.email_verified ? 'success' : 'warning'" :label="endUser.email_verified ? $t('project.endUserDetail.verified') : $t('project.endUserDetail.notVerified')" />
        </dd>
        <dt class="font-medium">{{ $t('project.endUserDetail.name') }}</dt>
        <dd>{{ endUser.name ?? '—' }}</dd>
        <dt class="font-medium">{{ $t('project.endUserDetail.userIdSub') }}</dt>
        <dd class="font-mono text-xs break-all">{{ endUser.uid }}</dd>
        <dt class="font-medium">{{ $t('project.endUserDetail.created') }}</dt>
        <dd>{{ formatDateTime(endUser.created_at) }}</dd>
        <dt class="font-medium">{{ $t('project.endUserDetail.lastSignIn') }}</dt>
        <dd>{{ endUser.last_sign_in_at ? formatDateTime(endUser.last_sign_in_at) : $t('project.endUserDetail.never') }}</dd>
        <template v-for="definition in definitions" :key="definition.uid">
          <dt class="font-medium">{{ definition.label }}</dt>
          <dd>{{ attributeValue(definition.key) }}</dd>
        </template>
      </dl>
      <BaseButton v-if="access.developer" :label="$t('project.endUserDetail.editProfile')" variant="secondary" class="self-start" @click="startEditing" />

      <section class="flex flex-col gap-2 border-t border-border pt-4" aria-labelledby="identities-heading">
        <h3 id="identities-heading" class="text-sm font-semibold">{{ $t('project.endUserDetail.linkedIdentityProviders') }}</h3>
        <BaseAlert v-if="unlink.error.value" variant="danger">{{ unlink.error.value.message }}</BaseAlert>
        <p v-if="identities.length === 0" class="text-sm text-text-muted">{{ $t('project.endUserDetail.noneThisUserSignsIn') }}</p>
        <ul v-else class="flex flex-col divide-y divide-border">
          <li v-for="identity in identities" :key="identity.uid" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
            <span class="flex flex-col">
              <RouterLink
                :to="{ name: 'project-identity-provider', params: { projectUid: project.uid, providerUid: identity.identity_provider_uid } }"
                class="font-medium text-primary underline-offset-2 hover:underline"
              >
                {{ identity.identity_provider_name }}
              </RouterLink>
              <span class="text-xs text-text-muted">
              {{
                $t('project.endUserDetail.identityDetails', {
                  email: identity.email ?? $t('project.endUserDetail.noEmailShared'),
                  subject: identity.subject,
                  date: formatDateTime(identity.last_sign_in_at),
                })
              }}
            </span>
            </span>
            <BaseButton v-if="access.developer" :label="$t('project.endUserDetail.unlink')" variant="ghost" size="sm" :loading="unlink.loading.value" @click="unlink.run(identity)" />
          </li>
        </ul>
      </section>
    </BaseCard>

    <BaseCard :title="$t('project.endUserDetail.access')" :description="$t('project.endUserDetail.applicationsAreAssignmentOnlyThis')">
      <BaseAlert v-if="membership.error.value" variant="danger">{{ membership.error.value.message }}</BaseAlert>
      <section class="flex flex-col gap-2" aria-labelledby="groups-heading">
        <h3 id="groups-heading" class="text-sm font-semibold">{{ $t('project.endUserDetail.groups') }}</h3>
        <p v-if="endUser.groups.length === 0" class="text-sm text-text-muted">{{ $t('project.endUserDetail.notInAnyGroup') }}</p>
        <ul v-else class="flex flex-col divide-y divide-border">
          <li v-for="group in endUser.groups" :key="group.uid" class="flex items-center justify-between gap-2 py-2 text-sm">
            <RouterLink :to="{ name: 'project-groups', params: { projectUid: project.uid }, query: { group: group.uid } }" class="font-medium text-primary underline-offset-2 hover:underline">
              {{ group.name }}
            </RouterLink>
            <BaseButton v-if="access.developer" :label="$t('project.endUserDetail.remove')" variant="ghost" size="sm" :loading="membership.loading.value" @click="membership.run('remove', group.uid)" />
          </li>
        </ul>
        <div v-if="access.developer" class="flex flex-wrap items-end gap-2">
          <div class="min-w-48 flex-1">
            <BaseSearchSelect v-model="groupToAdd" :label="$t('project.endUserDetail.addToGroup')" :search="searchGroupsToJoin" :see-all="lookups.allGroups.value" />
          </div>
          <BaseButton :label="$t('project.endUserDetail.add')" variant="secondary" :disabled="!groupToAdd" :loading="membership.loading.value" @click="membership.run('add', groupToAdd)" />
        </div>
      </section>

      <section class="flex flex-col gap-2 border-t border-border pt-4" aria-labelledby="apps-heading">
        <h3 id="apps-heading" class="text-sm font-semibold">{{ $t('project.endUserDetail.applications') }}</h3>
        <p v-if="appAccess.length === 0" class="text-sm text-text-muted">{{ $t('project.endUserDetail.noApplicationsThisUserCan') }}</p>
        <ul v-else class="flex flex-col divide-y divide-border">
          <li v-for="app in appAccess" :key="app.uid" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
            <span class="flex items-center gap-2">
              <RouterLink :to="appLink(app)" class="font-medium text-primary underline-offset-2 hover:underline">{{ app.name }}</RouterLink>
              <StatusBadge tone="info" :label="app.app_type === 'saml_app' ? $t('project.endUserDetail.saml') : $t('project.endUserDetail.openidConnectApi')" />
              <StatusBadge v-if="!app.enabled" tone="neutral" :label="$t('project.endUserDetail.appDisabled')" />
            </span>
            <span class="text-xs text-text-muted">
              {{ app.via.map((via) => (via.type === 'direct' ? $t('project.endUserDetail.assignedDirectly') : $t('project.endUserDetail.through', { groupName: via.group_name }))).join(' · ') }}
            </span>
          </li>
        </ul>
      </section>
    </BaseCard>

    <BaseCard :title="$t('project.endUserDetail.authentication')">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <dt class="font-medium">{{ $t('project.endUserDetail.accountStatus') }}</dt>
        <dd>{{ endUser.status === 'active' ? $t('project.endUserDetail.activeCanSignIn') : $t('project.endUserDetail.disabledCanTSignIn') }}</dd>
        <dt class="font-medium">{{ $t('project.endUserDetail.password') }}</dt>
        <dd>{{ endUser.invitation_pending ? $t('project.endUserDetail.notSetYetInvitationPending') : $t('project.endUserDetail.setOrSignsInWith') }}</dd>
        <dt class="font-medium">{{ $t('project.endUserDetail.multiFactorAuthentication') }}</dt>
        <dd>{{ endUser.mfa_enabled ? $t('project.endUserDetail.authenticatorAppSetUp') : $t('project.endUserDetail.noAuthenticatorApp') }}{{ passkeys.length > 0 ? $t('project.endUserDetail.passkeyCount', passkeys.length) : '' }}</dd>
      </dl>
      <section v-if="passkeys.length > 0" class="flex flex-col gap-2" aria-labelledby="passkeys-heading">
        <h3 id="passkeys-heading" class="text-sm font-semibold">{{ $t('project.endUserDetail.passkeys') }}</h3>
        <ul class="flex flex-col divide-y divide-border">
          <li v-for="passkey in passkeys" :key="passkey.uid" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
            <span class="flex flex-col">
              <span class="font-medium break-all">{{ passkey.name }}</span>
              <span class="text-xs text-text-muted">
                {{ passkey.domain }} · {{ passkey.synced ? $t('project.endUserDetail.synced') : $t('project.endUserDetail.oneDeviceOrKey') }} ·
                {{ passkey.last_used_at ? $t('project.endUserDetail.lastUsed', { lastUsedAt: formatDateTime(passkey.last_used_at) }) : $t('project.endUserDetail.notUsedYet') }}
              </span>
            </span>
            <BaseButton v-if="access.developer" :label="$t('project.endUserDetail.remove')" variant="ghost" size="sm" :aria-label="$t('project.endUserDetail.removePasskey2', { name: passkey.name })" @click="removingPasskey = passkey" />
          </li>
        </ul>
      </section>
      <i18n-t keypath="project.endUserDetail.mfaPolicyNote" tag="p" class="text-xs text-text-muted">
        <template #link><RouterLink :to="{ name: 'project-auth-mfa', params: { projectUid: project.uid } }" class="text-primary underline">{{ $t('project.endUserDetail.authenticationMultiFactorAuthentication') }}</RouterLink></template>
      </i18n-t>
      <div v-if="access.developer" class="flex flex-wrap gap-2">
        <BaseButton v-if="endUser.invitation_pending" :label="$t('project.endUserDetail.resendInvitation')" variant="secondary" :loading="actions.perform.loading.value" @click="actions.request('resend_invitation', endUser)" />
        <BaseButton v-if="endUser.mfa_enabled || passkeys.length > 0" :label="$t('project.endUserDetail.resetMfa')" variant="secondary" @click="actions.request('reset_mfa', endUser)" />
        <BaseButton v-if="endUser.status === 'active'" :label="$t('project.endUserDetail.disable')" variant="secondary" @click="actions.request('disable', endUser)" />
        <BaseButton v-else :label="$t('project.endUserDetail.enable')" variant="secondary" :loading="actions.perform.loading.value" @click="actions.request('enable', endUser)" />
      </div>
    </BaseCard>

    <BaseCard :title="$t('project.endUserDetail.sessions')" :description="$t('project.endUserDetail.theDevicesThisUserIs')">
      <template v-if="access.developer">
        <DeviceSessionTable ref="sessions" :fetch-page="fetchSessions" :sign-out="signOutSession" :owner="endUser.email" />
        <p class="text-sm text-text-muted">
          {{ $t('project.endUserDetail.signingOutEverywhereAlsoStops') }}
        </p>
        <BaseButton :label="$t('project.endUserDetail.signOutEverywhere')" variant="secondary" class="self-start" @click="actions.request('sign_out', endUser)" />
      </template>
      <p v-else class="text-sm text-text-muted">{{ $t('project.endUserDetail.onlyProjectAdminsAndDevelopers') }}</p>
    </BaseCard>

    <BaseCard v-if="access.developer" :title="$t('project.endUserDetail.activity')">
      <AuditEventList
        :fetch-page="fetchAudit"
        :filters="{ target_uid_eq: endUser.uid }"
        :empty-message="$t('project.endUserDetail.noActivityRecordedYet')"
        :full-log="{ name: 'project-audit-log', params: { projectUid: project.uid }, query: { target_uid_eq: endUser.uid } }"
      />
    </BaseCard>

    <BaseCard v-if="access.developer" :title="$t('project.endUserDetail.deleteEndUser')" :description="$t('project.endUserDetail.permanentlyDeletesTheUserAnd')">
      <BaseButton :label="$t('project.endUserDetail.deleteEndUser')" variant="danger" class="self-start" @click="actions.request('delete', endUser)" />
    </BaseCard>

    <EndUserActionDialog
      :pending="actions.pending.value"
      :loading="actions.perform.loading.value"
      :error="actions.perform.error.value"
      @confirm="actions.confirm()"
      @cancel="actions.pending.value = null"
    />

    <BaseDialog v-model:visible="editOpen" :title="$t('project.endUserDetail.editProfile')">
      <form id="edit-end-user" class="flex flex-col gap-4" novalidate @submit.prevent="saveProfile.run()">
        <BaseAlert v-if="saveProfile.error.value && saveProfile.error.value.details.length === 0" variant="danger">{{ saveProfile.error.value.message }}</BaseAlert>
        <BaseInput v-model="editName" :label="$t('project.endUserDetail.name')" :error="saveProfile.error.value?.fieldError('name')" />
        <CustomAttributeFields v-model="editAttributes" :definitions="definitions" :error="saveProfile.error.value" />
      </form>
      <template #footer>
        <BaseButton :label="$t('project.endUserDetail.cancel')" variant="secondary" @click="editOpen = false" />
        <BaseButton :label="$t('project.endUserDetail.save')" type="submit" form="edit-end-user" :loading="saveProfile.loading.value" />
      </template>
    </BaseDialog>
  </template>
  <ConfirmDialog
    :visible="removingPasskey !== null"
    :title="$t('project.endUserDetail.remove2', { passkey: removingPasskey?.name ?? $t('project.endUserDetail.thePasskey') })"
    :confirm-label="$t('project.endUserDetail.removePasskey')"
    danger
    :loading="removePasskey.loading.value"
    :error="removePasskey.error.value"
    @update:visible="(open: boolean) => !open && (removingPasskey = null)"
    @confirm="removePasskey.run()"
  >
    <p>{{ $t('project.endUserDetail.theUserCanNoLonger') }}</p>
  </ConfirmDialog>
</template>
