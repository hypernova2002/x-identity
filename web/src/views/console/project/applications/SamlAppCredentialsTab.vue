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

  <BaseCard title="Identity provider details for the app" description="What to enter in the app's SAML settings, or give it the metadata URL to import.">
    <BaseAlert v-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
    <p v-else-if="load.loading.value" class="text-sm text-text-muted" role="status">Loading…</p>
    <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
      <dt class="font-medium">Metadata URL and entity ID</dt>
      <dd class="font-mono text-xs break-all">{{ app.idp.metadata_url }}</dd>
      <dt class="font-medium">Sign-on URL</dt>
      <dd class="font-mono text-xs break-all">{{ app.idp.sso_url }}</dd>
      <dt class="font-medium">Logout URL</dt>
      <dd class="font-mono text-xs break-all">{{ app.idp.slo_url }}</dd>
      <template v-if="active">
        <dt class="font-medium">Signing certificate</dt>
        <dd class="font-mono text-xs break-all">SHA-256 {{ active.fingerprint_sha256 }}</dd>
      </template>
    </dl>
    <p class="text-sm">
      The project's certificates are shared by all its SAML applications. Download or rotate them in
      <RouterLink :to="{ name: 'project-auth-keys', params: { projectUid: project?.uid } }" class="font-medium text-primary underline">
        Authentication › Signing keys</RouterLink>.
    </p>
  </BaseCard>

  <BaseCard title="The app's certificate" description="Used to check the app's signed sign-in and logout requests.">
    <span class="flex flex-wrap items-center gap-2 text-sm">
      <StatusBadge :tone="app.sp_certificate ? 'success' : 'neutral'" :label="app.sp_certificate ? 'Certificate saved' : 'No certificate'" />
      <StatusBadge :tone="app.require_signed_requests ? 'success' : 'neutral'" :label="app.require_signed_requests ? 'Signed requests required' : 'Signed requests not required'" />
    </span>
    <RouterLink :to="{ name: 'project-saml-app-configuration', params: { projectUid: project?.uid, samlAppUid: app.uid } }" class="self-start text-sm font-medium text-primary underline">
      Change in Configuration
    </RouterLink>
  </BaseCard>
</template>
