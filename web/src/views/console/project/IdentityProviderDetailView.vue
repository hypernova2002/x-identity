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
      { label: $t('project.identityProviderDetail.identityProviders'), to: { name: 'project-identity-providers', params: { projectUid: project?.uid } } },
      { label: provider?.name ?? $t('project.identityProviderDetail.identityProvider') },
    ]"
  />

  <BaseAlert v-if="load.error.value?.code === 'not_found'" variant="danger" :title="$t('project.identityProviderDetail.identityProviderNotFound')">{{ $t('project.identityProviderDetail.itMayHaveBeenRemoved') }}</BaseAlert>
  <BaseAlert v-else-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
  <p v-else-if="!provider" class="text-sm text-text-muted" role="status">{{ $t('project.identityProviderDetail.loadingIdentityProvider') }}</p>

  <template v-if="provider && project">
    <PageHeader :title="provider.name" :description="kindLabel">
      <template #actions>
        <StatusBadge :tone="provider.enabled ? 'success' : 'neutral'" :label="provider.enabled ? $t('project.identityProviderDetail.enabled') : $t('project.identityProviderDetail.disabled')" />
        <BaseButton v-if="access.admin" :label="$t('project.identityProviderDetail.edit')" @click="editor.start(provider)" />
      </template>
    </PageHeader>

    <BaseCard :title="$t('project.identityProviderDetail.configuration')">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <template v-if="isSaml">
          <dt class="font-medium">{{ $t('project.identityProviderDetail.identityProviderEntityId') }}</dt>
          <dd class="font-mono text-xs break-all">{{ provider.saml_idp_entity_id }}</dd>
          <dt class="font-medium">{{ $t('project.identityProviderDetail.signOnUrl') }}</dt>
          <dd class="font-mono text-xs break-all">{{ provider.saml_sso_url }}</dd>
          <dt class="font-medium">{{ $t('project.identityProviderDetail.signingCertificates') }}</dt>
          <dd>{{ provider.saml_idp_certificates.length }}</dd>
          <dt class="font-medium">{{ $t('project.identityProviderDetail.nameidRequested') }}</dt>
          <dd>{{ nameIdFormatOptions.find((option) => option.value === provider!.saml_name_id_format)?.label }}</dd>
          <dt class="font-medium">{{ $t('project.identityProviderDetail.attributes') }}</dt>
          <i18n-t keypath="project.identityProviderDetail.attributeMapping" tag="dd">
            <template #email><code class="font-mono text-xs">{{ provider.saml_email_attribute ?? $t('project.identityProviderDetail.theNameId') }}</code></template>
            <template #name><code class="font-mono text-xs">{{ provider.saml_name_attribute ?? $t('project.identityProviderDetail.notSetAttribute') }}</code></template>
            <template #groups><code class="font-mono text-xs">{{ provider.saml_groups_attribute ?? $t('project.identityProviderDetail.notSetAttribute') }}</code></template>
          </i18n-t>
        </template>
        <template v-else>
          <dt class="font-medium">{{ provider.kind === 'apple' ? $t('project.identityProviderDetail.servicesId') : $t('project.identityProviderDetail.clientId') }}</dt>
          <dd class="font-mono text-xs break-all">{{ provider.client_id }}</dd>
          <template v-if="provider.kind === 'oidc'">
            <dt class="font-medium">{{ $t('project.identityProviderDetail.issuer') }}</dt>
            <dd class="font-mono text-xs break-all">{{ provider.issuer }}</dd>
          </template>
          <dt class="font-medium">{{ $t('project.identityProviderDetail.secret') }}</dt>
          <dd>
            <StatusBadge
              :tone="provider.client_secret_set || provider.apple_private_key_set ? 'success' : 'warning'"
              :label="provider.client_secret_set || provider.apple_private_key_set ? $t('project.identityProviderDetail.savedWriteOnly') : $t('project.identityProviderDetail.notSet')"
            />
          </dd>
          <dt class="font-medium">{{ $t('project.identityProviderDetail.nativeAppClientIds') }}</dt>
          <dd>{{ provider.additional_audiences.join(', ') || $t('project.identityProviderDetail.none') }}</dd>
          <dt class="font-medium">{{ $t('project.identityProviderDetail.callbackUrlToRegister') }}</dt>
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

    <BaseCard v-if="isSaml" :title="$t('project.identityProviderDetail.serviceProviderDetails')" :description="$t('project.identityProviderDetail.giveTheseToTheCompany')">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <dt class="font-medium">{{ $t('project.identityProviderDetail.metadataUrlAndEntityId') }}</dt>
        <dd class="font-mono text-xs break-all">{{ provider.sp_entity_id }}</dd>
        <dt class="font-medium">{{ $t('project.identityProviderDetail.assertionConsumerServiceUrl') }}</dt>
        <dd class="font-mono text-xs break-all">{{ provider.acs_url }}</dd>
        <dt class="font-medium">{{ $t('project.identityProviderDetail.singleLogoutUrl') }}</dt>
        <dd class="font-mono text-xs break-all">{{ provider.sp_slo_url }}</dd>
      </dl>
    </BaseCard>

    <BaseCard v-if="isSaml" :title="$t('project.identityProviderDetail.domainsAndRouting')">
      <i18n-t keypath="project.identityProviderDetail.noDomains" tag="p" v-if="provider.domains.length === 0" class="text-sm">
        <template #trusted><strong>{{ $t('project.identityProviderDetail.noEmailIsTrusted') }}</strong></template>
      </i18n-t>
      <template v-else>
        <i18n-t keypath="project.identityProviderDetail.domainsHelp" tag="p" class="text-sm">
          <template #domains><strong>{{ provider.domains.join(', ') }}</strong></template>
        </i18n-t>
      </template>
    </BaseCard>

    <BaseCard :title="$t('project.identityProviderDetail.accountLinkingAndProvisioning')">
      <ul class="flex list-disc flex-col gap-1 pl-5 text-sm">
        <li>{{ $t('project.identityProviderDetail.aUserWhoSignedIn') }}</li>
        <li v-if="isSaml">{{ $t('project.identityProviderDetail.anEmailCountsAsVerified') }}</li>
        <li v-else>{{ $t('project.identityProviderDetail.theProviderMustSayThe') }}</li>
        <li>
          {{ $t('project.identityProviderDetail.anExistingEndUserWith') }}
        </li>
        <i18n-t keypath="project.identityProviderDetail.newUsersCreated" tag="li">
          <template #created>
            <strong>{{ createsUsers ? $t('project.identityProviderDetail.createdOnFirstSignIn') : $t('project.identityProviderDetail.notCreated') }}</strong>
          </template>
          <template #reason>
            {{
              provider.create_users
                ? $t('project.identityProviderDetail.providerCreatesUsers')
                : project.allow_self_sign_up
                  ? $t('project.identityProviderDetail.selfSignUpOn')
                  : $t('project.identityProviderDetail.selfSignUpOff')
            }}
          </template>
        </i18n-t>
      </ul>
    </BaseCard>

    <BaseCard v-if="isSaml" :title="$t('project.identityProviderDetail.groupMapping')">
      <p v-if="provider.group_mappings.length === 0" class="text-sm text-text-muted">{{ $t('project.identityProviderDetail.noGroupMappingsGroupMemberships') }}</p>
      <template v-else>
        <i18n-t keypath="project.identityProviderDetail.groupMappingHelp" tag="p" class="text-sm">
          <template #attribute><code class="font-mono text-xs">{{ provider.saml_groups_attribute }}</code></template>
        </i18n-t>
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

    <BaseCard v-if="isSaml" :title="$t('project.identityProviderDetail.singleLogoutAndIdpInitiated')">
      <ul class="flex list-disc flex-col gap-1 pl-5 text-sm">
        <li v-if="provider.saml_slo_url">{{ $t('project.identityProviderDetail.logoutAtProvider', { url: provider.saml_slo_url }) }}</li>
        <li v-else>{{ $t('project.identityProviderDetail.noLogoutUrlLoggingOut') }}</li>
        <i18n-t keypath="project.identityProviderDetail.idpInitiated" tag="li">
          <template #allowed>
            <strong>{{ provider.allow_idp_initiated ? $t('project.identityProviderDetail.allowed') : $t('project.identityProviderDetail.notAllowed') }}</strong>
          </template>
        </i18n-t>
      </ul>
    </BaseCard>

    <BaseCard :title="$t('project.identityProviderDetail.diagnostics')">
      <p class="text-sm">
        <i18n-t keypath="project.identityProviderDetail.tryRealSignIn">
          <template #link>
            <RouterLink :to="{ name: 'project-test-sign-in', params: { projectUid: project.uid } }" class="font-medium text-primary underline">
              {{ $t('project.identityProviderDetail.testSignInLink') }}
            </RouterLink>
          </template>
        </i18n-t>
        {{ isSaml && provider.domains.length > 0 ? $t('project.identityProviderDetail.enterAnAddressAtTo', { domains: provider.domains[0] }) : $t('project.identityProviderDetail.thisProviderSButtonIs') }}
      </p>
      <template v-if="access.developer">
        <h3 class="text-sm font-semibold">{{ $t('project.identityProviderDetail.configurationChanges') }}</h3>
        <AuditEventList
          :fetch-page="fetchAudit"
          :filters="{ target_uid_eq: provider.uid }"
          :empty-message="$t('project.identityProviderDetail.noChangesRecordedYet')"
          :full-log="{ name: 'project-audit-log', params: { projectUid: project.uid }, query: { target_uid_eq: provider.uid } }"
          :limit="5"
        />
      </template>
    </BaseCard>

    <BaseCard v-if="access.admin" :title="$t('project.identityProviderDetail.manage')">
      <BaseAlert v-if="toggle.error.value" variant="danger">{{ toggle.error.value.message }}</BaseAlert>
      <div class="flex flex-wrap gap-2">
        <BaseButton v-if="provider.enabled" :label="$t('project.identityProviderDetail.disable')" variant="secondary" @click="disableOpen = true" />
        <BaseButton v-else :label="$t('project.identityProviderDetail.enable')" variant="secondary" :loading="toggle.loading.value" @click="toggle.run()" />
        <BaseButton :label="$t('project.identityProviderDetail.removeProvider')" variant="danger" @click="deleteOpen = true" />
      </div>
    </BaseCard>

    <BaseDialog v-model:visible="editor.open.value" :title="$t('project.identityProviderDetail.edit2', { name: provider.name })">
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
        <BaseButton :label="$t('project.identityProviderDetail.cancel')" variant="secondary" @click="editor.open.value = false" />
        <BaseButton :label="$t('project.identityProviderDetail.save')" type="submit" form="identity-provider-form" :loading="editor.save.loading.value" />
      </template>
    </BaseDialog>

    <ConfirmDialog v-model:visible="disableOpen" :title="$t('project.identityProviderDetail.disableThisProvider')" :confirm-label="$t('project.identityProviderDetail.disable')" danger :loading="toggle.loading.value" :error="toggle.error.value" @confirm="toggle.run()">
      <i18n-t keypath="project.identityProviderDetail.disableDescription" tag="p">
        <template #name><strong>{{ provider.name }}</strong></template>
      </i18n-t>
    </ConfirmDialog>
    <ConfirmDialog v-model:visible="deleteOpen" :title="$t('project.identityProviderDetail.removeThisProvider')" :confirm-label="$t('project.identityProviderDetail.removeProvider')" danger :loading="destroy.loading.value" :error="destroy.error.value" @confirm="destroy.run()">
      <i18n-t keypath="project.identityProviderDetail.removeDescription" tag="p">
        <template #name><strong>{{ provider.name }}</strong></template>
      </i18n-t>
    </ConfirmDialog>
  </template>
</template>
