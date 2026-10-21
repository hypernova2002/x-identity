<script setup lang="ts">
import AuthConfigurationForm from '@/components/settings/AuthConfigurationForm.vue'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { AuthConfiguration } from '@/types/api'

const { accountUid, project, access } = useProjectContext()

function load() {
  return projectAdminService.getAuthConfiguration(accountUid.value, project.value!.uid)
}

function save(changes: Partial<AuthConfiguration>) {
  return projectAdminService.updateAuthConfiguration(accountUid.value, project.value!.uid, changes)
}
</script>

<template>
  <p class="text-sm text-text-muted">
    How this project's end users sign in. Changes apply from each end user's next sign-in or token refresh.
  </p>
  <AuthConfigurationForm
    v-if="project"
    :load="load"
    :save="save"
    :readonly="!access.admin"
    show-email-code-limits
    email-verification-hint="On by default for projects. When off, end users can sign in before confirming their email."
  />
</template>
