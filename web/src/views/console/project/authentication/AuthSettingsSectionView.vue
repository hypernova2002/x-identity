<script setup lang="ts">
import { computed, ref } from 'vue'
import { RouterLink, useRoute } from 'vue-router'

import BaseCard from '@/components/base/BaseCard.vue'
import SamlCertificatesPanel from '@/components/project/SamlCertificatesPanel.vue'
import AuthConfigurationForm from '@/components/settings/AuthConfigurationForm.vue'
import { useProjectContext } from '@/composables/useProjectContext'
import { useUnsavedChanges } from '@/composables/useUnsavedChanges'
import { projectAdminService } from '@/services/project'
import type { AuthConfiguration } from '@/types/api'
import { authSettingsSections, type AuthSettingsSection } from '@/utils/authSettings'

const route = useRoute()
const { accountUid, project, access } = useProjectContext()

const section = computed<AuthSettingsSection>(() => route.meta.authSection ?? 'sign-in')
const description = computed(() => authSettingsSections.find((entry) => entry.section === section.value)?.description)
const dirty = ref(false)

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

  <BaseCard v-if="section === 'sign-in' && project" title="How end users sign in">
    <ul class="flex list-disc flex-col gap-1 pl-5 text-sm">
      <li>Email and password, always available.</li>
      <li>
        Social, OpenID Connect and company SAML sign-in, configured under
        <RouterLink :to="{ name: 'project-identity-providers', params: { projectUid: project.uid } }" class="font-medium text-primary underline">
          Identity providers
        </RouterLink>.
      </li>
      <li>
        Self sign-up is <strong>{{ project.allow_self_sign_up ? 'on' : 'off' }}</strong>; change it, and the email link pages, in
        <RouterLink :to="{ name: 'project-settings', params: { projectUid: project.uid } }" class="font-medium text-primary underline">
          project settings</RouterLink>.
      </li>
    </ul>
  </BaseCard>

  <BaseCard v-if="section === 'mfa' && project" title="Individual users">
    <p class="text-sm">
      Whether a user has set up MFA, and resetting it, is on each user's page under
      <RouterLink :to="{ name: 'project-end-users', params: { projectUid: project.uid } }" class="font-medium text-primary underline">End users</RouterLink>.
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
    show-sso-session
    email-verification-hint="On by default for projects. When off, end users can sign in before confirming their email."
  />

  <template v-if="section === 'signing' && project">
    <BaseCard title="Token signing keys" description="The project's current public keys, for apps verifying tokens.">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <dt class="font-medium">JWKS</dt>
        <dd class="font-mono text-xs break-all">{{ project.token_issuer }}/.well-known/jwks.json</dd>
      </dl>
      <p class="text-xs text-text-muted">
        Keys rotate automatically on the schedule above; retired keys stay published until every token they signed has expired.
        Private keys are never shown.
      </p>
    </BaseCard>
    <SamlCertificatesPanel :account-uid="accountUid" :project-uid="project.uid" :project-name="project.name" :can-manage="access.admin" />
  </template>
</template>
