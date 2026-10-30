<script setup lang="ts">
import { computed, ref } from 'vue'
import { RouterLink, useRoute } from 'vue-router'

import BaseCard from '@/components/base/BaseCard.vue'
import SamlCertificatesPanel from '@/components/project/SamlCertificatesPanel.vue'
import AuthConfigurationForm from '@/components/settings/AuthConfigurationForm.vue'
import { useProjectContext } from '@/composables/useProjectContext'
import { useUnsavedChanges } from '@/composables/useUnsavedChanges'
import { useVerifiedDomain } from '@/composables/useVerifiedDomain'
import { projectAdminService } from '@/services/project'
import type { AuthConfiguration } from '@/types/api'
import { authSettingsSections, type AuthSettingsSection } from '@/utils/authSettings'

const route = useRoute()
const { accountUid, project, access } = useProjectContext()

const section = computed<AuthSettingsSection>(() => route.meta.authSection ?? 'sign-in')
const description = computed(() => authSettingsSections.find((entry) => entry.section === section.value)?.description)
const dirty = ref(false)
const { hostname: customDomain } = useVerifiedDomain(() => (project.value ? { accountUid: accountUid.value, projectUid: project.value.uid } : null))

useUnsavedChanges(dirty)

function load() {
  return projectAdminService.getAuthConfiguration(accountUid.value, project.value!.uid)
}

function save(changes: Partial<AuthConfiguration>) {
  return projectAdminService.updateAuthConfiguration(accountUid.value, project.value!.uid, changes)
}
</script>

<template>
  <p class="text-sm text-text-muted">{{ description }}</p>

  <BaseCard v-if="section === 'sign-in' && project" :title="$t('project.authSettingsSection.howEndUsersSignIn')">
    <ul class="flex list-disc flex-col gap-1 pl-5 text-sm">
      <li>{{ $t('project.authSettingsSection.emailAndPasswordAlwaysAvailable') }}</li>
      <li>
        {{ $t('project.authSettingsSection.socialOpenidConnectAndCompany') }}
        <RouterLink :to="{ name: 'project-identity-providers', params: { projectUid: project.uid } }" class="font-medium text-primary underline">
          {{ $t('project.authSettingsSection.identityProviders') }}
        </RouterLink>.
      </li>
      <i18n-t keypath="project.authSettingsSection.selfSignUpNote" tag="li">
        <template #state><strong>{{ project.allow_self_sign_up ? $t('project.authSettingsSection.on') : $t('project.authSettingsSection.off') }}</strong></template>
        <template #link><RouterLink :to="{ name: 'project-settings', params: { projectUid: project.uid } }" class="font-medium text-primary underline">
          {{ $t('project.authSettingsSection.projectSettings') }}</RouterLink></template>
      </i18n-t>
    </ul>
  </BaseCard>

  <BaseCard v-if="section === 'mfa' && project" :title="$t('project.authSettingsSection.individualUsers')">
    <p class="text-sm">
      {{ $t('project.authSettingsSection.whetherAUserHasSet') }}
      <RouterLink :to="{ name: 'project-end-users', params: { projectUid: project.uid } }" class="font-medium text-primary underline">{{ $t('project.authSettingsSection.endUsers') }}</RouterLink>.
    </p>
  </BaseCard>

  <AuthConfigurationForm
    v-if="project"
    :key="section"
    v-model:dirty="dirty"
    :load="load"
    :save="save"
    :readonly="!access.admin"
    :sections="[section]"
    show-email-code-limits
    for-project
    :custom-domain="customDomain"
    :email-verification-hint="$t('project.authSettingsSection.onByDefaultForProjects')"
  />

  <template v-if="section === 'signing' && project">
    <BaseCard :title="$t('project.authSettingsSection.tokenSigningKeys')" :description="$t('project.authSettingsSection.theProjectSCurrentPublic')">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <dt class="font-medium">{{ $t('project.authSettingsSection.jwks') }}</dt>
        <dd class="font-mono text-xs break-all">{{ `${project.token_issuer}/.well-known/jwks.json` }}</dd>
      </dl>
      <p class="text-xs text-text-muted">
        {{ $t('project.authSettingsSection.keysRotateAutomaticallyOnThe') }}
      </p>
    </BaseCard>
    <SamlCertificatesPanel :account-uid="accountUid" :project-uid="project.uid" :project-name="project.name" :can-manage="access.admin" />
  </template>
</template>
