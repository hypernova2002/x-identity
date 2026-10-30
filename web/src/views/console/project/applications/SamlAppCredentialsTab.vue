<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import CustomDomainSwitch from '@/components/project/CustomDomainSwitch.vue'
import { useSamlApp } from '@/composables/useApplicationContext'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { useSamlIdentityProvider } from '@/composables/useSamlIdentityProvider'
import { useVerifiedDomain } from '@/composables/useVerifiedDomain'
import { projectAdminService } from '@/services/project'

const { accountUid, project, access } = useProjectContext()
const { record: app, replace } = useSamlApp()
const { info, load } = useSamlIdentityProvider()
const active = computed(() => info.value?.certificates.find((certificate) => certificate.status === 'active'))
const { hostname: domain } = useVerifiedDomain(() => (project.value ? { accountUid: accountUid.value, projectUid: project.value.uid } : null))
const domainSwitch = ref<InstanceType<typeof CustomDomainSwitch> | null>(null)

const switchDomain = useAsyncAction(async (onCustomDomain: boolean) => {
  replace(await projectAdminService.updateSamlApp(accountUid.value, project.value!.uid, app.value.uid, { on_custom_domain: onCustomDomain }))
  domainSwitch.value?.close()
})

onMounted(() => project.value && load.run(accountUid.value, project.value.uid))
</script>

<template>
  <CustomDomainSwitch
    ref="domainSwitch"
    kind="app"
    :name="app.name"
    :on-custom-domain="app.on_custom_domain"
    :domain="domain"
    :project-uid="project?.uid ?? ''"
    :can-change="access.developer"
    :saving="switchDomain.loading.value"
    :error="switchDomain.error.value"
    @change="switchDomain.run"
  />

  <BaseCard :title="$t('project.samlAppCredentials.identityProviderDetailsForThe')" :description="$t('project.samlAppCredentials.whatToEnterInThe')">
    <BaseAlert v-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
    <p v-else-if="load.loading.value" class="text-sm text-text-muted" role="status">{{ $t('project.samlAppCredentials.loading') }}</p>
    <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
      <dt class="font-medium">{{ $t('project.samlAppCredentials.metadataUrlAndEntityId') }}</dt>
      <dd class="font-mono text-xs break-all">{{ app.idp.metadata_url }}</dd>
      <dt class="font-medium">{{ $t('project.samlAppCredentials.signOnUrl') }}</dt>
      <dd class="font-mono text-xs break-all">{{ app.idp.sso_url }}</dd>
      <dt class="font-medium">{{ $t('project.samlAppCredentials.logoutUrl') }}</dt>
      <dd class="font-mono text-xs break-all">{{ app.idp.slo_url }}</dd>
      <template v-if="active">
        <dt class="font-medium">{{ $t('project.samlAppCredentials.signingCertificate') }}</dt>
        <dd class="font-mono text-xs break-all">{{ $t('project.samlAppCredentials.fingerprint', { fingerprint: active.fingerprint_sha256 }) }}</dd>
      </template>
    </dl>
    <i18n-t keypath="project.samlAppCredentials.certificatesNote" tag="p" class="text-sm">
      <template #link><RouterLink :to="{ name: 'project-auth-keys', params: { projectUid: project?.uid } }" class="font-medium text-primary underline">
        {{ $t('project.samlAppCredentials.authenticationSigningKeys') }}</RouterLink></template>
    </i18n-t>
  </BaseCard>

  <BaseCard :title="$t('project.samlAppCredentials.theAppSCertificate')" :description="$t('project.samlAppCredentials.usedToCheckTheApp')">
    <span class="flex flex-wrap items-center gap-2 text-sm">
      <StatusBadge :tone="app.sp_certificate ? 'success' : 'neutral'" :label="app.sp_certificate ? $t('project.samlAppCredentials.certificateSaved') : $t('project.samlAppCredentials.noCertificate')" />
      <StatusBadge :tone="app.require_signed_requests ? 'success' : 'neutral'" :label="app.require_signed_requests ? $t('project.samlAppCredentials.signedRequestsRequired') : $t('project.samlAppCredentials.signedRequestsNotRequired')" />
    </span>
    <RouterLink :to="{ name: 'project-saml-app-configuration', params: { projectUid: project?.uid, samlAppUid: app.uid } }" class="self-start text-sm font-medium text-primary underline">
      {{ $t('project.samlAppCredentials.changeInConfiguration') }}
    </RouterLink>
  </BaseCard>
</template>
