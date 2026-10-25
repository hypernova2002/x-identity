<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'

import AuditEventList from '@/components/audit/AuditEventList.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import PageBreadcrumbs from '@/components/console/PageBreadcrumbs.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import CustomDomainSwitch from '@/components/project/CustomDomainSwitch.vue'
import IdentityProviderForm from '@/components/project/IdentityProviderForm.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { useProviderEditor } from '@/composables/useProviderEditor'
import { useVerifiedDomain } from '@/composables/useVerifiedDomain'
import type { ListParams } from '@/services/list'
import { projectAdminService } from '@/services/project'
import type { IdentityProvider } from '@/types/api'
import { identityProviderKindOptions } from '@/utils/options'
import { nameIdFormatOptions } from '@/utils/samlApps'

const route = useRoute()
const router = useRouter()
const { accountUid, project, access } = useProjectContext()

const provider = ref<IdentityProvider | null>(null)
const disableOpen = ref(false)
const deleteOpen = ref(false)
const providerUid = computed(() => String(route.params.providerUid))
const editor = useProviderEditor(() => (project.value ? { accountUid: accountUid.value, projectUid: project.value.uid } : null))

const kindLabel = computed(() => identityProviderKindOptions.find((option) => option.value === provider.value?.kind)?.label ?? '')
const isSaml = computed(() => provider.value?.kind === 'saml')
const createsUsers = computed(() => Boolean(provider.value?.create_users || project.value?.allow_self_sign_up))

const load = useAsyncAction(async () => {
  if (!project.value) return
  provider.value = await projectAdminService.getIdentityProvider(accountUid.value, project.value.uid, providerUid.value)
})

async function saveEdit() {
  const saved = await editor.save.run()
  if (saved) provider.value = saved
}

const toggle = useAsyncAction(async () => {
  if (!project.value || !provider.value) return
  provider.value = await projectAdminService.updateIdentityProvider(accountUid.value, project.value.uid, provider.value.uid, { enabled: !provider.value.enabled })
  disableOpen.value = false
})

const { hostname: domain } = useVerifiedDomain(() => (project.value ? { accountUid: accountUid.value, projectUid: project.value.uid } : null))
const domainSwitch = ref<InstanceType<typeof CustomDomainSwitch> | null>(null)

const switchDomain = useAsyncAction(async (onCustomDomain: boolean) => {
  if (!project.value || !provider.value) return
  provider.value = await projectAdminService.updateIdentityProvider(accountUid.value, project.value.uid, provider.value.uid, { on_custom_domain: onCustomDomain })
  domainSwitch.value?.close()
})

const destroy = useAsyncAction(async () => {
  if (!project.value || !provider.value) return
  await projectAdminService.deleteIdentityProvider(accountUid.value, project.value.uid, provider.value.uid)
  await router.push({ name: 'project-identity-providers', params: { projectUid: project.value.uid } })
})

function fetchAudit(params: ListParams) {
  return projectAdminService.listAuditEvents(accountUid.value, project.value!.uid, params)
}

watch(providerUid, () => load.run())
onMounted(() => load.run())
</script>

<template>
  <PageBreadcrumbs
    :items="[
      { label: 'Identity providers', to: { name: 'project-identity-providers', params: { projectUid: project?.uid } } },
      { label: provider?.name ?? 'Identity provider' },
    ]"
  />

  <BaseAlert v-if="load.error.value?.code === 'not_found'" variant="danger" title="Identity provider not found">It may have been removed.</BaseAlert>
  <BaseAlert v-else-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
  <p v-else-if="!provider" class="text-sm text-text-muted" role="status">Loading identity provider…</p>

  <template v-if="provider && project">
    <PageHeader :title="provider.name" :description="kindLabel">
      <template #actions>
        <StatusBadge :tone="provider.enabled ? 'success' : 'neutral'" :label="provider.enabled ? 'Enabled' : 'Disabled'" />
        <BaseButton v-if="access.admin" label="Edit" @click="editor.start(provider)" />
      </template>
    </PageHeader>

    <BaseCard title="Configuration">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <template v-if="isSaml">
          <dt class="font-medium">Identity provider entity ID</dt>
          <dd class="font-mono text-xs break-all">{{ provider.saml_idp_entity_id }}</dd>
          <dt class="font-medium">Sign-on URL</dt>
          <dd class="font-mono text-xs break-all">{{ provider.saml_sso_url }}</dd>
          <dt class="font-medium">Signing certificates</dt>
          <dd>{{ provider.saml_idp_certificates.length }}</dd>
          <dt class="font-medium">NameID requested</dt>
          <dd>{{ nameIdFormatOptions.find((option) => option.value === provider!.saml_name_id_format)?.label }}</dd>
          <dt class="font-medium">Attributes</dt>
          <dd>
            Email: <code class="font-mono text-xs">{{ provider.saml_email_attribute ?? 'the NameID' }}</code>, name:
            <code class="font-mono text-xs">{{ provider.saml_name_attribute ?? 'not set' }}</code>, groups:
            <code class="font-mono text-xs">{{ provider.saml_groups_attribute ?? 'not set' }}</code>
          </dd>
        </template>
        <template v-else>
          <dt class="font-medium">{{ provider.kind === 'apple' ? 'Services ID' : 'Client ID' }}</dt>
          <dd class="font-mono text-xs break-all">{{ provider.client_id }}</dd>
          <template v-if="provider.kind === 'oidc'">
            <dt class="font-medium">Issuer</dt>
            <dd class="font-mono text-xs break-all">{{ provider.issuer }}</dd>
          </template>
          <dt class="font-medium">Secret</dt>
          <dd>
            <StatusBadge
              :tone="provider.client_secret_set || provider.apple_private_key_set ? 'success' : 'warning'"
              :label="provider.client_secret_set || provider.apple_private_key_set ? 'Saved (write-only)' : 'Not set'"
            />
          </dd>
          <dt class="font-medium">Native app client IDs</dt>
          <dd>{{ provider.additional_audiences.join(', ') || 'None' }}</dd>
          <dt class="font-medium">Callback URL to register</dt>
          <dd class="font-mono text-xs break-all">{{ provider.callback_url }}</dd>
        </template>
      </dl>
    </BaseCard>

    <CustomDomainSwitch
      v-if="isSaml"
      ref="domainSwitch"
      kind="provider"
      :name="provider.name"
      :on-custom-domain="provider.on_custom_domain ?? false"
      :domain="domain"
      :project-uid="project.uid"
      :can-change="access.admin"
      :saving="switchDomain.loading.value"
      :error="switchDomain.error.value"
      @change="switchDomain.run"
    />

    <BaseCard v-if="isSaml" title="Service provider details" description="Give these to the company's identity provider admin, or have them import the metadata URL.">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <dt class="font-medium">Metadata URL and entity ID</dt>
        <dd class="font-mono text-xs break-all">{{ provider.sp_entity_id }}</dd>
        <dt class="font-medium">Assertion consumer service URL</dt>
        <dd class="font-mono text-xs break-all">{{ provider.acs_url }}</dd>
        <dt class="font-medium">Single logout URL</dt>
        <dd class="font-mono text-xs break-all">{{ provider.sp_slo_url }}</dd>
      </dl>
    </BaseCard>

    <BaseCard v-if="isSaml" title="Domains and routing">
      <p v-if="provider.domains.length === 0" class="text-sm">
        No domains, so <strong>no email is trusted</strong> and sign-ins are refused. Add the company's email domains.
      </p>
      <template v-else>
        <p class="text-sm">
          Only addresses at <strong>{{ provider.domains.join(', ') }}</strong> can sign in with this provider. People who enter one of
          these addresses on the hosted login page are sent here instead of being asked for a password.
        </p>
      </template>
    </BaseCard>

    <BaseCard title="Account linking and provisioning">
      <ul class="flex list-disc flex-col gap-1 pl-5 text-sm">
        <li>A user who signed in with this provider before is signed in to the same end user.</li>
        <li v-if="isSaml">An email counts as verified only at the provider's domains; anything else is refused.</li>
        <li v-else>The provider must say the email is verified, or the sign-in is refused.</li>
        <li>
          An existing end user with that email is linked only if their own email is verified (or they were invited and haven't set a
          password). Otherwise they must sign in with their password first.
        </li>
        <li>
          New users:
          <strong>{{ createsUsers ? 'created on first sign-in' : 'not created' }}</strong>
          ({{ provider.create_users ? 'this provider creates users' : project.allow_self_sign_up ? 'self sign-up is on' : 'self sign-up is off and this provider doesn\'t create users' }}).
          New users join the groups set to take them automatically.
        </li>
      </ul>
    </BaseCard>

    <BaseCard v-if="isSaml" title="Group mapping">
      <p v-if="provider.group_mappings.length === 0" class="text-sm text-text-muted">No group mappings. Group memberships are managed in the console only.</p>
      <template v-else>
        <p class="text-sm">At each sign-in, membership of these groups follows the provider's <code class="font-mono text-xs">{{ provider.saml_groups_attribute }}</code> attribute:</p>
        <ul class="flex flex-col divide-y divide-border">
          <li v-for="mapping in provider.group_mappings" :key="`${mapping.value}-${mapping.group_uid}`" class="flex flex-wrap gap-2 py-2 text-sm">
            <code class="font-mono text-xs">{{ mapping.value }}</code>
            <span aria-hidden="true">→</span>
            <RouterLink :to="{ name: 'project-groups', params: { projectUid: project.uid }, query: { group: mapping.group_uid } }" class="font-medium text-primary underline">
              {{ mapping.group_name }}
            </RouterLink>
          </li>
        </ul>
      </template>
    </BaseCard>

    <BaseCard v-if="isSaml" title="Single logout and IdP-initiated sign-in">
      <ul class="flex list-disc flex-col gap-1 pl-5 text-sm">
        <li v-if="provider.saml_slo_url">Logging out also logs out at the provider ({{ provider.saml_slo_url }}).</li>
        <li v-else>No logout URL: logging out ends the session here only.</li>
        <li>Sign-in started from the provider's dashboard is <strong>{{ provider.allow_idp_initiated ? 'allowed' : 'not allowed' }}</strong>.</li>
      </ul>
    </BaseCard>

    <BaseCard title="Diagnostics">
      <p class="text-sm">
        Try a real sign-in: open
        <RouterLink :to="{ name: 'project-test-sign-in', params: { projectUid: project.uid } }" class="font-medium text-primary underline">Test sign-in</RouterLink>
        and use hosted login. {{ isSaml && provider.domains.length > 0 ? `Enter an address at ${provider.domains[0]} to be routed here.` : 'This provider\'s button is on the hosted login page.' }}
      </p>
      <template v-if="access.developer">
        <h3 class="text-sm font-semibold">Configuration changes</h3>
        <AuditEventList
          :fetch-page="fetchAudit"
          :filters="{ target_uid_eq: provider.uid }"
          empty-message="No changes recorded yet."
          :full-log="{ name: 'project-audit-log', params: { projectUid: project.uid }, query: { target_uid_eq: provider.uid } }"
          :limit="5"
        />
      </template>
    </BaseCard>

    <BaseCard v-if="access.admin" title="Manage">
      <BaseAlert v-if="toggle.error.value" variant="danger">{{ toggle.error.value.message }}</BaseAlert>
      <div class="flex flex-wrap gap-2">
        <BaseButton v-if="provider.enabled" label="Disable" variant="secondary" @click="disableOpen = true" />
        <BaseButton v-else label="Enable" variant="secondary" :loading="toggle.loading.value" @click="toggle.run()" />
        <BaseButton label="Remove provider" variant="danger" @click="deleteOpen = true" />
      </div>
    </BaseCard>

    <BaseDialog v-model:visible="editor.open.value" :title="`Edit ${provider.name}`">
      <IdentityProviderForm
        v-model="editor.draft.value"
        form-id="identity-provider-form"
        :existing="provider"
        :error="editor.save.error.value"
          :import-error="editor.importMetadata.error.value"
        :importing="editor.importMetadata.loading.value"
        @submit="saveEdit"
        @import-metadata="(source) => editor.importMetadata.run(source)"
      />
      <template #footer>
        <BaseButton label="Cancel" variant="secondary" @click="editor.open.value = false" />
        <BaseButton label="Save" type="submit" form="identity-provider-form" :loading="editor.save.loading.value" />
      </template>
    </BaseDialog>

    <ConfirmDialog v-model:visible="disableOpen" title="Disable this provider?" confirm-label="Disable" danger :loading="toggle.loading.value" :error="toggle.error.value" @confirm="toggle.run()">
      <p>End users can't sign in with <strong>{{ provider.name }}</strong> while it's disabled. Their links to it are kept, and they can still use a password if they have one.</p>
    </ConfirmDialog>
    <ConfirmDialog v-model:visible="deleteOpen" title="Remove this provider?" confirm-label="Remove provider" danger :loading="destroy.loading.value" :error="destroy.error.value" @confirm="destroy.run()">
      <p>
        End users can no longer sign in with <strong>{{ provider.name }}</strong>, and their links to it are removed. Users without a
        password need to reset theirs to sign in again. To keep the links, disable it instead.
      </p>
    </ConfirmDialog>
  </template>
</template>
