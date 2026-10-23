<script setup lang="ts">
import { ref } from 'vue'
import { storeToRefs } from 'pinia'

import PageHeader from '@/components/console/PageHeader.vue'
import AuthConfigurationForm from '@/components/settings/AuthConfigurationForm.vue'
import { useUnsavedChanges } from '@/composables/useUnsavedChanges'
import { accountService } from '@/services/account'
import { useSessionStore } from '@/stores/session'
import type { AuthConfiguration } from '@/types/api'

const { account } = storeToRefs(useSessionStore())
const dirty = ref(false)

useUnsavedChanges(dirty)

function load() {
  return accountService.getAuthConfiguration(account.value!.uid)
}

function save(changes: Partial<AuthConfiguration>) {
  return accountService.updateAuthConfiguration(account.value!.uid, changes)
}
</script>

<template>
  <PageHeader
    title="Console sign-in settings"
    description="How console users sign in to this account. Each project's end users have their own settings, under the project's Authentication. Changes apply from each user's next sign-in or token refresh."
  />
  <AuthConfigurationForm
    v-if="account"
    v-model:dirty="dirty"
    :load="load"
    :save="save"
    email-verification-hint="Off by default while the console is being tested."
  />
</template>
